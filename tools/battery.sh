#!/usr/bin/env bash
#
# battery — friendly macOS battery CLI.
#
# Wraps pmset, ioreg -rn AppleSmartBattery, and system_profiler SPPowerDataType
# behind subcommands so you never have to remember Apple's archaic invocations.
#
# Subcommands:
#   battery [status]   Short human summary (default)
#   battery percent    Charge percent as a bare integer
#   battery charging   Prints yes/no; exits 0 if charging, 1 if not
#   battery health     MaxCapacity/DesignCapacity %, cycle count, condition
#   battery adapter    Wattage, model, serial, connected/delivering state
#   battery time       Time-to-full when charging, time-to-empty when discharging
#   battery temp       Battery temperature in °C
#   battery why        Why is it not charging while plugged in?
#   battery raw        Full ioreg -rn AppleSmartBattery dump
#   battery json       All values as one JSON object
#   battery watch [N]  Repaint summary every N seconds (default 5)
#   battery help       Show usage
#
set -euo pipefail

# ─── globals ────────────────────────────────────────────────────────────────
PROG="${0##*/}"
USE_COLOR=1
IOREG_CACHE=""
PMSET_BATT_CACHE=""
PMSET_AC_CACHE=""

# ─── color helpers ──────────────────────────────────────────────────────────
_color_init() {
  if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]] || [[ "${1:-}" == "--no-color" ]]; then
    USE_COLOR=0
  fi
  if (( USE_COLOR )); then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_CYAN=$'\033[36m'
  else
    C_RESET=""; C_BOLD=""; C_DIM=""
    C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""
  fi
}

_die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }

_require_mac() {
  [[ "$(uname -s)" == "Darwin" ]] || _die "macOS only (uname=$(uname -s))"
}

# ─── data loaders (cached per invocation) ───────────────────────────────────
_load_ioreg() {
  [[ -n "$IOREG_CACHE" ]] && return 0
  IOREG_CACHE="$(ioreg -rn AppleSmartBattery 2>/dev/null || true)"
  [[ -n "$IOREG_CACHE" ]] || _die "ioreg returned no AppleSmartBattery data"
}

_load_pmset_batt() {
  [[ -n "$PMSET_BATT_CACHE" ]] && return 0
  PMSET_BATT_CACHE="$(pmset -g batt 2>/dev/null || true)"
}

_load_pmset_ac() {
  [[ -n "$PMSET_AC_CACHE" ]] && return 0
  PMSET_AC_CACHE="$(pmset -g ac 2>/dev/null || true)"
}

# ─── ioreg parsers ──────────────────────────────────────────────────────────
# Top-level scalar field: "Key" = value
_ioreg_field() {
  local key="$1"
  _load_ioreg
  printf '%s\n' "$IOREG_CACHE" \
    | awk -v k="\"$key\"" '
        $1 == k {
          # everything after the "= "
          sub(/^[^=]*=[[:space:]]*/, "")
          print
          exit
        }'
}

# Field inside an inline dict block, e.g. AdapterDetails={"Watts"=86,...}
_ioreg_subfield() {
  local block="$1" key="$2"
  _load_ioreg
  printf '%s\n' "$IOREG_CACHE" \
    | awk -v b="\"$block\"" -v k="\"$key\"" '
        $1 == b {
          line = $0
          # capture inside outermost braces
          if (match(line, /\{.*\}/)) {
            inner = substr(line, RSTART+1, RLENGTH-2)
            n = split(inner, parts, ",")
            for (i = 1; i <= n; i++) {
              if (index(parts[i], k"=") == 1) {
                v = parts[i]
                sub(/^[^=]*=/, "", v)
                gsub(/^"|"$/, "", v)
                print v
                exit
              }
            }
          }
        }'
}

# ─── pmset parsers ──────────────────────────────────────────────────────────
# Returns the first value after "key = " or "key=" in pmset -g ac output.
_pmset_ac_field() {
  local key="$1"
  _load_pmset_ac
  printf '%s\n' "$PMSET_AC_CACHE" \
    | awk -v k="$key" '
        BEGIN { IGNORECASE = 1 }
        {
          line = $0
          # strip leading whitespace
          sub(/^[[:space:]]+/, "", line)
          # match "Key = value" or "Key=value"
          if (match(line, "^" k "[[:space:]]*=[[:space:]]*")) {
            print substr(line, RSTART + RLENGTH)
            exit
          }
        }'
}

_pmset_power_source() {
  _load_pmset_batt
  printf '%s\n' "$PMSET_BATT_CACHE" \
    | awk -F"'" '/Now drawing from/ { print $2; exit }'
}

_pmset_time_remaining() {
  _load_pmset_batt
  printf '%s\n' "$PMSET_BATT_CACHE" \
    | awk '/[Ii]nternalBattery/ {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^[0-9]+:[0-9]+$/) { print $i; exit }
        }
      }'
}

# ─── value derivers ─────────────────────────────────────────────────────────
_percent() {
  local cur max
  cur="$(_ioreg_field CurrentCapacity)"
  max="$(_ioreg_field MaxCapacity)"
  if [[ -n "$cur" && -n "$max" && "$max" != 0 ]]; then
    awk -v c="$cur" -v m="$max" 'BEGIN { printf "%d\n", (c / m * 100) + 0.5 }'
    return
  fi
  # fallback: derive from raw capacities
  local rc rm
  rc="$(_ioreg_field AppleRawCurrentCapacity)"
  rm="$(_ioreg_field AppleRawMaxCapacity)"
  if [[ -n "$rc" && -n "$rm" && "$rm" != 0 ]]; then
    awk -v c="$rc" -v m="$rm" 'BEGIN { printf "%d\n", (c / m * 100) + 0.5 }'
    return
  fi
  echo "?"
}

_is_charging() {
  local v
  v="$(_ioreg_field IsCharging)"
  [[ "$v" == "Yes" ]]
}

_external_connected() {
  local v
  v="$(_ioreg_field ExternalConnected)"
  [[ "$v" == "Yes" ]]
}

_fully_charged() {
  local v
  v="$(_ioreg_field FullyCharged)"
  [[ "$v" == "Yes" ]]
}

# Battery temperature in °C, 1 decimal.
# Apple's AppleSmartBattery `Temperature` field is reported as either
# centi-Celsius (newer Apple Silicon) or deci-Kelvin (older Intel hardware).
# Try Kelvin conversion first; if implausible, fall back to plain division.
_temp_c() {
  local raw
  raw="$(_ioreg_field Temperature)"
  [[ -z "$raw" ]] && { echo "?"; return; }
  awk -v r="$raw" 'BEGIN {
    k = (r / 10.0) - 273.15
    if (k > -5 && k < 120) { printf "%.1f\n", k; exit }
    c = r / 100.0
    if (c > -5 && c < 120) { printf "%.1f\n", c; exit }
    printf "%.1f\n", r / 100.0
  }'
}

_cycles()      { _ioreg_field CycleCount; }
_max_cap()     { _ioreg_field MaxCapacity; }
_design_cap()  { _ioreg_field DesignCapacity; }

_health_pct() {
  local m d
  m="$(_max_cap)"; d="$(_design_cap)"
  if [[ -n "$m" && -n "$d" && "$d" != 0 ]]; then
    awk -v m="$m" -v d="$d" 'BEGIN { printf "%d\n", (m / d * 100) + 0.5 }'
  else
    echo "?"
  fi
}

# pmset -g batt gives a one-line condition for some macs; ioreg doesn't carry
# a clean "Condition" string. Fall back to derived health bucket.
_condition() {
  local h
  h="$(_health_pct)"
  if [[ "$h" == "?" ]]; then echo "Unknown"; return; fi
  if   (( h >= 80 )); then echo "Normal"
  elif (( h >= 65 )); then echo "Fair"
  else                     echo "Service Recommended"
  fi
}

_adapter_watts() {
  local w
  w="$(_ioreg_subfield AdapterDetails Watts)"
  [[ -n "$w" ]] && { echo "$w"; return; }
  w="$(_pmset_ac_field Wattage)"
  echo "${w%W}"
}

_adapter_name()    { _ioreg_subfield AdapterDetails Name; }
_adapter_model()   { _ioreg_subfield AdapterDetails Model; }
_adapter_serial()  { _ioreg_subfield AdapterDetails SerialString; }
_adapter_manuf()   { _ioreg_subfield AdapterDetails Manufacturer; }

_adapter_connected() { _external_connected; }

_adapter_delivering() {
  # ExternalChargeCapable=Yes AND a non-zero adapter wattage means power is
  # actually being delivered (vs. plugged in but rejected).
  local cap w
  cap="$(_ioreg_field ExternalChargeCapable)"
  w="$(_adapter_watts)"
  [[ "$cap" == "Yes" && -n "$w" && "$w" != 0 ]]
}

_not_charging_reason() {
  _ioreg_subfield ChargerData NotChargingReason
}

# Translate the NotChargingReason bitmask. Bit values are community-derived
# from Apple Smart Battery telemetry; unknown bits are surfaced as the raw int.
_not_charging_reason_human() {
  local code="$1"
  [[ -z "$code" || "$code" == "0" ]] && { echo "none"; return; }
  local out=""
  (( code & 1 ))    && out="${out}, not-charging-requested"
  (( code & 2 ))    && out="${out}, fully-charged"
  (( code & 4 ))    && out="${out}, optimized-battery-charging-paused"
  (( code & 8 ))    && out="${out}, charger-thermal-limit"
  (( code & 16 ))   && out="${out}, battery-thermal-limit"
  (( code & 32 ))   && out="${out}, voltage-limit"
  (( code & 64 ))   && out="${out}, charger-fault"
  (( code & 128 ))  && out="${out}, battery-fault"
  (( code & 256 ))  && out="${out}, hardware-limit"
  out="${out#, }"
  [[ -z "$out" ]] && out="unknown(raw=$code)"
  echo "$out"
}

# Optimized Battery Charging state, best-effort. Modern macOS exposes this via
# the `pmset -g` output as "AC Power" assertions or via Battery defaults; the
# most reliable cross-version signal is the bit-2 flag in NotChargingReason
# above, plus pmset's text output mentioning "Optimized".
_optimized_state() {
  local p
  _load_pmset_batt
  p="$PMSET_BATT_CACHE"
  if printf '%s' "$p" | grep -qi 'optimized'; then
    echo "engaged"
    return
  fi
  local code
  code="$(_not_charging_reason)"
  if [[ -n "$code" && "$code" != 0 ]] && (( code & 4 )); then
    echo "engaged"
  else
    echo "off-or-unknown"
  fi
}

_arch() { uname -m; }

# ─── output helpers ─────────────────────────────────────────────────────────
_icon_state() {
  if _is_charging; then            printf '⚡'
  elif _external_connected; then   printf '🔌'
  else                              printf '🔋'
  fi
}

_state_label() {
  if _is_charging; then           echo "charging"
  elif _fully_charged; then       echo "full"
  elif _external_connected; then  echo "plugged (not charging)"
  else                            echo "on battery"
  fi
}

_pct_color() {
  local p="$1"
  [[ "$p" == "?" ]] && { printf '%s' "$C_DIM"; return; }
  if   (( p >= 60 )); then printf '%s' "$C_GREEN"
  elif (( p >= 25 )); then printf '%s' "$C_YELLOW"
  else                     printf '%s' "$C_RED"
  fi
}

# ─── subcommands ────────────────────────────────────────────────────────────
cmd_status() {
  local pct state t w h cyc temp
  pct="$(_percent)"
  state="$(_state_label)"
  t="$(_pmset_time_remaining)"
  [[ -z "$t" ]] && t="—"
  w="$(_adapter_watts)"
  [[ -z "$w" ]] && w="—" || w="${w}W"
  h="$(_health_pct)"
  cyc="$(_cycles)"
  [[ -z "$cyc" ]] && cyc="?"
  temp="$(_temp_c)"

  local icon col
  icon="$(_icon_state)"
  col="$(_pct_color "$pct")"

  printf '%s %s%s%%%s  %s%s%s  time: %s  adapter: %s  health: %s%%  cycles: %s  temp: %s°C\n' \
    "$icon" "${C_BOLD}${col}" "$pct" "$C_RESET" \
    "$C_CYAN" "$state" "$C_RESET" \
    "$t" "$w" "$h" "$cyc" "$temp"
}

cmd_percent() { printf '%s' "$(_percent)"; }

cmd_charging() {
  if _is_charging; then echo "yes"; exit 0
  else                  echo "no";  exit 1
  fi
}

cmd_health() {
  local h cyc cond m d
  h="$(_health_pct)"
  cyc="$(_cycles)"
  cond="$(_condition)"
  m="$(_max_cap)"
  d="$(_design_cap)"
  printf 'health:    %s%% (%s / %s mAh)\n' "$h" "${m:-?}" "${d:-?}"
  printf 'cycles:    %s\n' "${cyc:-?}"
  printf 'condition: %s\n' "$cond"
}

cmd_adapter() {
  local connected="no" delivering="no"
  _adapter_connected && connected="yes"
  _adapter_delivering && delivering="yes"
  local w n m s mfg
  w="$(_adapter_watts)"
  n="$(_adapter_name)"
  m="$(_adapter_model)"
  s="$(_adapter_serial)"
  mfg="$(_adapter_manuf)"
  printf 'connected:   %s\n' "$connected"
  printf 'delivering:  %s\n' "$delivering"
  printf 'wattage:     %s\n' "${w:-?}${w:+W}"
  printf 'name:        %s\n' "${n:-?}"
  printf 'model:       %s\n' "${m:-?}"
  printf 'serial:      %s\n' "${s:-?}"
  printf 'manufacturer:%s\n' " ${mfg:-?}"
}

cmd_time() {
  local t
  t="$(_pmset_time_remaining)"
  if [[ -z "$t" ]]; then
    echo "calculating"
  else
    echo "$t"
  fi
}

cmd_temp() {
  local t
  t="$(_temp_c)"
  printf '%s°C\n' "$t"
}

cmd_why() {
  local connected charging full code reason optimized
  connected="no"; _external_connected && connected="yes"
  charging="no";  _is_charging && charging="yes"
  full="no";      _fully_charged && full="yes"
  code="$(_not_charging_reason)"
  reason="$(_not_charging_reason_human "${code:-0}")"
  optimized="$(_optimized_state)"

  printf 'plugged in:           %s\n' "$connected"
  printf 'charging:             %s\n' "$charging"
  printf 'fully charged:        %s\n' "$full"
  printf 'NotChargingReason:    %s (%s)\n' "${code:-0}" "$reason"
  printf 'Optimized Charging:   %s\n' "$optimized"

  if [[ "$connected" == "yes" && "$charging" == "no" && "$full" == "no" ]]; then
    printf '\n%sWhy not charging:%s %s\n' "$C_BOLD" "$C_RESET" "$reason"
    case "$(_arch)" in
      arm64) printf '%sTip:%s On Apple Silicon, an SMC reset is done by shutting down and holding power 10s.\n' "$C_DIM" "$C_RESET" ;;
      x86_64) printf '%sTip:%s On Intel Macs, reset SMC via Shift+Ctrl+Option+Power for 10s (T2) or per-model steps.\n' "$C_DIM" "$C_RESET" ;;
    esac
  fi
}

cmd_raw() {
  _load_ioreg
  printf '%s\n' "$IOREG_CACHE"
}

# JSON emitter — single object. Strings are quoted; numbers/bools left bare
# when we know the type, otherwise quoted defensively. No external jq dep.
_json_str() {
  # Escape backslashes and double-quotes for safe JSON string embedding.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

cmd_json() {
  # Force everything cached up-front so subsequent helpers are O(1).
  _load_ioreg; _load_pmset_batt; _load_pmset_ac

  local pct cyc h m d temp w cap_ext is_ch ext_conn full code reason opt
  local a_name a_model a_serial a_mfg t state arch
  pct="$(_percent)"
  cyc="$(_cycles)"; cyc="${cyc:-null}"
  h="$(_health_pct)"
  m="$(_max_cap)"; m="${m:-null}"
  d="$(_design_cap)"; d="${d:-null}"
  temp="$(_temp_c)"
  w="$(_adapter_watts)"; w="${w:-null}"
  cap_ext="false"; _adapter_delivering && cap_ext="true"
  is_ch="false";  _is_charging && is_ch="true"
  ext_conn="false"; _external_connected && ext_conn="true"
  full="false"; _fully_charged && full="true"
  code="$(_not_charging_reason)"; code="${code:-0}"
  reason="$(_not_charging_reason_human "$code")"
  opt="$(_optimized_state)"
  a_name="$(_adapter_name)"
  a_model="$(_adapter_model)"
  a_serial="$(_adapter_serial)"
  a_mfg="$(_adapter_manuf)"
  t="$(_pmset_time_remaining)"; [[ -z "$t" ]] && t="calculating"
  state="$(_state_label)"
  arch="$(_arch)"

  printf '{'
  printf '"percent":%s,' "${pct:-null}"
  printf '"state":%s,' "$(_json_str "$state")"
  printf '"charging":%s,' "$is_ch"
  printf '"external_connected":%s,' "$ext_conn"
  printf '"fully_charged":%s,' "$full"
  printf '"time_remaining":%s,' "$(_json_str "$t")"
  printf '"temperature_c":%s,' "${temp:-null}"
  printf '"cycles":%s,' "$cyc"
  printf '"health_percent":%s,' "${h:-null}"
  printf '"max_capacity_mah":%s,' "$m"
  printf '"design_capacity_mah":%s,' "$d"
  printf '"condition":%s,' "$(_json_str "$(_condition)")"
  printf '"adapter":{'
  printf  '"connected":%s,' "$ext_conn"
  printf  '"delivering":%s,' "$cap_ext"
  printf  '"watts":%s,' "$w"
  printf  '"name":%s,' "$(_json_str "${a_name:-}")"
  printf  '"model":%s,' "$(_json_str "${a_model:-}")"
  printf  '"serial":%s,' "$(_json_str "${a_serial:-}")"
  printf  '"manufacturer":%s' "$(_json_str "${a_mfg:-}")"
  printf '},'
  printf '"not_charging_reason_code":%s,' "$code"
  printf '"not_charging_reason":%s,' "$(_json_str "$reason")"
  printf '"optimized_charging":%s,' "$(_json_str "$opt")"
  printf '"arch":%s' "$(_json_str "$arch")"
  printf '}\n'
}

cmd_watch() {
  local interval="${1:-5}"
  [[ "$interval" =~ ^[0-9]+$ ]] || _die "watch interval must be a positive integer"
  trap 'printf "\n"; exit 0' INT
  while :; do
    # Reset caches each tick so values refresh.
    IOREG_CACHE=""; PMSET_BATT_CACHE=""; PMSET_AC_CACHE=""
    if (( USE_COLOR )); then
      printf '\033[2J\033[H'
    fi
    printf '%s%s%s — every %ss (Ctrl-C to exit)\n\n' "$C_DIM" "$(date '+%H:%M:%S')" "$C_RESET" "$interval"
    cmd_status
    sleep "$interval"
  done
}

cmd_help() {
  cat <<EOF
Usage: $PROG [--no-color] <subcommand> [args]

Subcommands:
  status         Short human summary (default)
  percent        Charge percent as a bare integer
  charging       yes/no; exits 0 if charging, 1 if not
  health         MaxCapacity / DesignCapacity, cycle count, condition
  adapter        Adapter wattage, model, serial, connected/delivering state
  time           Time-to-full or time-to-empty (calculating when unknown)
  temp           Battery temperature in °C
  why            Why isn't it charging while plugged in?
  raw            Full ioreg -rn AppleSmartBattery dump
  json           Emit all values as a single JSON object
  watch [N]      Repaint status every N seconds (default 5)
  help           This message

Env:
  NO_COLOR=1     Disable ANSI color (also: pass --no-color)
EOF
}

# ─── dispatch ───────────────────────────────────────────────────────────────
main() {
  _require_mac
  # Strip a leading --no-color anywhere in the first two args.
  local args=()
  for a in "$@"; do
    case "$a" in
      --no-color) USE_COLOR=0 ;;
      *) args+=("$a") ;;
    esac
  done
  _color_init

  local sub="${args[0]:-status}"
  case "$sub" in
    ""|status)        cmd_status ;;
    percent)          cmd_percent ;;
    charging)         cmd_charging ;;
    health)           cmd_health ;;
    adapter)          cmd_adapter ;;
    time)             cmd_time ;;
    temp)             cmd_temp ;;
    why)              cmd_why ;;
    raw)              cmd_raw ;;
    json)             cmd_json ;;
    watch)            cmd_watch "${args[1]:-5}" ;;
    help|-h|--help)   cmd_help ;;
    *) _die "unknown subcommand: $sub (try '$PROG help')" ;;
  esac
}

main "$@"
