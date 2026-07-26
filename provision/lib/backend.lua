-- provision/lib/backend.lua
--
-- Package manager backends for the Lua provisioner.
-- Supported backends: brew (formula), cask (Homebrew cask), choco (Chocolatey).
--
-- Each backend exposes:
--   is_installed(id, opts) -> boolean
--   install(id, opts)      -> nil  (raises on failure)
--
-- opts fields (all optional):
--   tap      string  Homebrew tap to add before installing (brew/cask only).
--   app      string  Absolute path to a .app bundle; if the path exists the
--                    tool is considered installed (cask only, mirrors install.sh:15).

local M = {}

--- Execute a shell command and return true if it exits 0.
local function shell_ok(cmd)
  local code = os.execute(cmd)
  -- os.execute returns true/false in Lua 5.2+, or an integer in Lua 5.1.
  if type(code) == "boolean" then
    return code
  end
  return code == 0
end

--- Execute a shell command, raising an error if it fails.
local function shell_assert(cmd, errmsg)
  if not shell_ok(cmd) then
    error(errmsg or ("command failed: " .. cmd))
  end
end

--- Extract a tap name from a tap-qualified package id.
-- "hashicorp/tap/terraform" → "hashicorp/tap"; "gh" → nil.
-- @param id string
-- @return string|nil
local function tap_from_id(id)
  if not id or id == "" then
    return nil
  end
  local user, repo = id:match("^([^/]+)/([^/]+)/")
  if user and repo then
    return user .. "/" .. repo
  end
  return nil
end

--- Trust a Homebrew tap (Homebrew 6+ tap-trust).
-- Official taps are always trusted (brew prints a no-op message). Soft-fails
-- on older Homebrew without `brew trust` so provision still works.
-- @param tap string  e.g. "hashicorp/tap"
local function trust_tap(tap)
  if not tap or tap == "" then
    return
  end
  shell_ok(string.format("brew trust --tap %q >/dev/null 2>&1", tap))
end

--- Ensure a tap is present and trusted before install.
-- @param tap string
local function ensure_tap(tap)
  if not tap or tap == "" then
    return
  end
  shell_assert(
    string.format("brew tap %q", tap),
    "brew tap failed: " .. tap
  )
  trust_tap(tap)
end

-------------------------------------------------------------------------------
-- brew (Homebrew formula)
-------------------------------------------------------------------------------

local brew = {}

--- Trust every installed third-party tap (Homebrew 6+).
-- Official homebrew/* taps are skipped. Soft-fails if `brew trust` is missing.
-- Call once at the start of the tools phase so already-tapped repos stop
-- emitting "Skipping … because it is not trusted" during brew operations.
function brew.trust_installed_taps()
  -- Iterate taps via a single shell loop; avoid pulling each name into Lua.
  shell_ok([[
    brew tap 2>/dev/null | while IFS= read -r tap; do
      [ -n "$tap" ] || continue
      case "$tap" in
        homebrew/*) continue ;;
        *) brew trust --tap "$tap" >/dev/null 2>&1 || true ;;
      esac
    done
  ]])
end

--- Check whether a Homebrew formula is installed.
-- Queries `brew list --formula` and matches the exact package name.
-- For tap-qualified IDs (e.g. "hashicorp/tap/terraform"), both the full
-- form and the bare formula name (last path component) are tried because
-- `brew list` reports the bare name only.
-- @param id   string  Formula name or tap-qualified name (e.g. "gh" or
--                     "hashicorp/tap/terraform").
-- @param opts table   (unused for formulae; present for API symmetry).
function brew.is_installed(id, opts)
  opts = opts or {}
  -- Try the full id first.
  if shell_ok(string.format("brew list --formula 2>/dev/null | grep -qx %q", id)) then
    return true
  end
  -- For tap-qualified ids, also check the bare formula name.
  local bare = id:match("[^/]+$")
  if bare and bare ~= id then
    return shell_ok(string.format("brew list --formula 2>/dev/null | grep -qx %q", bare))
  end
  return false
end

--- Install a Homebrew formula.
-- Taps and trusts `opts.tap` (or the tap embedded in a qualified id) first.
-- @param id   string
-- @param opts table  { tap?: string }
function brew.install(id, opts)
  opts = opts or {}
  local tap = opts.tap or tap_from_id(id)
  if tap then
    ensure_tap(tap)
  end
  shell_assert(
    string.format("brew install %q", id),
    "brew install failed: " .. id
  )
end

M.brew = brew

-------------------------------------------------------------------------------
-- cask (Homebrew cask)
-------------------------------------------------------------------------------

local cask = {}

--- Check whether a Homebrew cask is installed.
-- If opts.app is provided and the path exists as a directory, returns true
-- immediately (mirrors install.sh:15 `[ -d "$app_path" ]` check).
-- Otherwise queries `brew list --cask`.
-- @param id   string
-- @param opts table  { app?: string }
function cask.is_installed(id, opts)
  opts = opts or {}
  -- .app existence check (pre-install shortcut)
  if opts.app and opts.app ~= "" then
    -- Use a stat call: if the path exists, treat as installed.
    if shell_ok(string.format('test -d %q', opts.app)) then
      return true
    end
  end
  return shell_ok(
    string.format("brew list --cask 2>/dev/null | grep -qx %q", id)
  )
end

--- Install a Homebrew cask.
-- Taps and trusts `opts.tap` (or the tap embedded in a qualified id) first.
-- @param id   string
-- @param opts table  { tap?: string, app?: string }
function cask.install(id, opts)
  opts = opts or {}
  local tap = opts.tap or tap_from_id(id)
  if tap then
    ensure_tap(tap)
  end
  shell_assert(
    string.format("brew install --cask %q", id),
    "brew install --cask failed: " .. id
  )
end

M.cask = cask

-------------------------------------------------------------------------------
-- choco (Chocolatey — Windows)
-------------------------------------------------------------------------------

local choco = {}

--- Check whether a Chocolatey package is installed.
-- Uses `choco list <id> --exact --limit-output` (Chocolatey v2 syntax).
-- The command exits 0 and prints "<id>|<version>" when the package is found.
-- @param id   string
-- @param opts table  (unused)
function choco.is_installed(id, opts)
  -- choco list exits 0 regardless; we check whether output is non-empty.
  -- Redirect output to a temp variable via a subshell check.
  local cmd = string.format(
    'choco list %q --exact --limit-output 2>nul | findstr /i %q >nul 2>&1',
    id, id
  )
  return shell_ok(cmd)
end

--- Install a Chocolatey package.
-- @param id   string
-- @param opts table  (unused)
function choco.install(id, opts)
  opts = opts or {}
  shell_assert(
    string.format("choco install %q -y", id),
    "choco install failed: " .. id
  )
end

M.choco = choco

-------------------------------------------------------------------------------
-- Dispatch helper
-------------------------------------------------------------------------------

--- Resolve a backend by name string.
-- @param name string  "brew" | "cask" | "choco"
-- @return table  The backend module.
function M.get(name)
  local b = M[name]
  if not b then
    error("Unknown backend: " .. tostring(name))
  end
  return b
end

return M
