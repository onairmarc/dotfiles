const PROG = "battery";
let ioregCache = "";

function capture(argv: string[]): string {
    const r = Bun.spawnSync(argv, {stdout: "pipe", stderr: "pipe"});
    return r.stdout ? r.stdout.toString() : "";
}

function die(msg: string): never {
    process.stderr.write(`${PROG}: ${msg}\n`);
    process.exit(1);
}

function loadIoreg(): void {
    if (ioregCache !== "") {
        return;
    }

    ioregCache = capture(["ioreg", "-rn", "AppleSmartBattery"]);

    if (ioregCache === "") {
        die("ioreg returned no AppleSmartBattery data");
    }
}

function ioregSubfield(block: string, key: string): string {
    loadIoreg();

    const blockNeedle = `"${block}"`;
    const keyNeedle = `"${key}"=`;

    for (const line of ioregCache.split("\n")) {
        const trimmed = line.trimStart();
        const eq = trimmed.indexOf("=");
        if (eq < 0 || trimmed.slice(0, eq).trim() !== blockNeedle) {
            continue;
        }

        const braceStart = line.indexOf("{");
        const braceEnd = line.lastIndexOf("}");
        if (braceStart < 0 || braceEnd < 0 || braceEnd <= braceStart) {
            return "";
        }

        const inner = line.slice(braceStart + 1, braceEnd);
        for (const part of inner.split(",")) {
            if (!part.startsWith(keyNeedle)) {
                continue;
            }

            return part.slice(keyNeedle.length).replace(/^"|"$/g, "");
        }

        return "";
    }

    return "";
}

function adapterVoltage(): string {
    const millivolts = ioregSubfield("AdapterDetails", "AdapterVoltage");
    return /^\d+$/.test(millivolts) ? (Number(millivolts) / 1000).toFixed(1) : "";
}

function adapterCurrent(): string {
    const milliamps = ioregSubfield("AdapterDetails", "Current");
    return /^\d+$/.test(milliamps) ? (Number(milliamps) / 1000).toFixed(1) : "";
}

function adapterContract(): string {
    const voltage = adapterVoltage();
    const current = adapterCurrent();
    if (voltage === "" && current === "") {
        return "?";
    }

    return `${voltage || "?"}V / ${current || "?"}A`;
}

function ioregField(key: string): string {
    loadIoreg();

    const needle = `"${key}"`;

    for (const line of ioregCache.split("\n")) {
        const trimmed = line.trimStart();
        const eq = trimmed.indexOf("=");
        if (eq < 0) {
            continue;
        }

        if (trimmed.slice(0, eq).trim() !== needle) {
            continue;
        }

        return trimmed.slice(eq + 1).trim();
    }

    return "";
}

let pmsetAcCache = "";

function loadPmsetAc(): void {
    if (pmsetAcCache !== "") {
        return;
    }

    pmsetAcCache = capture(["pmset", "-g", "ac"]);
}

function pmsetAcField(key: string): string {
    loadPmsetAc();

    const re = new RegExp(`^${key}\\s*=\\s*`, "i");

    for (const raw of pmsetAcCache.split("\n")) {
        const line = raw.replace(/^\s+/, "");
        const m = line.match(re);
        if (m) {
            return line.slice(m[0].length);
        }
    }

    return "";
}

function adapterWatts(): string {
    const fromIoreg = ioregSubfield("AdapterDetails", "Watts");
    if (fromIoreg !== "") {
        return fromIoreg;
    }

    return pmsetAcField("Wattage").replace(/W$/, "");
}

function adapterDelivering(): boolean {
    const cap = ioregField("ExternalChargeCapable");
    const w = adapterWatts();
    return cap === "Yes" && w !== "" && w !== "0";
}

function telemetryWatts(key: string): string {
    const raw = ioregSubfield("PowerTelemetryData", key);
    if (!/^\d+$/.test(raw)) {
        return "";
    }

    return (Number(raw) / 1000).toFixed(1);
}

function adapterInputWatts(): string {
    return telemetryWatts("SystemPowerIn");
}

function adapterManuf(): string {
    return ioregSubfield("AdapterDetails", "Manufacturer");
}

function adapterModel(): string {
    return ioregSubfield("AdapterDetails", "Model");
}

function adapterName(): string {
    return ioregSubfield("AdapterDetails", "Name");
}

function adapterSerial(): string {
    return ioregSubfield("AdapterDetails", "SerialString");
}

function signed64(raw: string): string {
    if (!/^-?\d+$/.test(raw)) {
        return "";
    }

    let n = BigInt(raw);
    const two63 = 1n << 63n;
    const two64 = 1n << 64n;

    if (n >= two63) {
        n -= two64;
    }

    return n.toString();
}

function amperageMa(): string {
    let raw = ioregField("Amperage");
    if (!/^-?\d+$/.test(raw)) {
        raw = ioregField("InstantAmperage");
    }

    return signed64(raw);
}

function arch(): string {
    return capture(["uname", "-m"]).trim();
}

let systemProfilerPowerCache = "";

function loadSystemProfilerPower(): void {
    if (systemProfilerPowerCache === "") {
        systemProfilerPowerCache = capture(["system_profiler", "SPPowerDataType"]);
    }
}

function batteryBelowWarning(): string {
    loadSystemProfilerPower();

    const match = systemProfilerPowerCache.match(/warning level:\s*(.+)$/mi);
    return match?.[1].trim() ?? "";
}

function batteryWatts(): string {
    const ma = amperageMa();
    const mv = ioregField("Voltage");
    if (ma === "" || !/^\d+$/.test(mv)) {
        return "";
    }

    return ((Number(ma) / 1000.0) * (Number(mv) / 1000.0)).toFixed(1);
}

function chargeBar(pct: string, width = 20): string {
    if (pct === "?" || !/^\d+$/.test(pct)) {
        return "?".repeat(width);
    }

    const filled = Math.round(Math.min(100, Math.max(0, Number(pct))) / 100 * width);
    return "#".repeat(filled) + "-".repeat(width - filled);
}

function uiPercent(): string {
    const uiSoc = ioregSubfield("BatteryData", "UISoc");
    return /^\d+$/.test(uiSoc) ? uiSoc : "";
}

function roundPct(cur: string, max: string): string {
    if (cur !== "" && max !== "" && max !== "0") {
        return String(Math.floor((Number(cur) / Number(max) * 100) + 0.5));
    }

    return "";
}

function rawPercent(): string {
    const stateOfCharge = ioregSubfield("BatteryData", "StateOfCharge");
    if (/^\d+$/.test(stateOfCharge)) {
        return stateOfCharge;
    }

    const fromNamed = roundPct(ioregField("CurrentCapacity"), ioregField("MaxCapacity"));
    if (fromNamed !== "") {
        return fromNamed;
    }

    const fromRaw = roundPct(ioregField("AppleRawCurrentCapacity"), ioregField("AppleRawMaxCapacity"));
    return fromRaw !== "" ? fromRaw : "?";
}

function chargeCalibrationDelta(): string {
    const ui = uiPercent();
    const raw = rawPercent();
    if (ui === "" || raw === "?" || !/^\d+$/.test(raw)) {
        return "";
    }

    return String(Number(ui) - Number(raw));
}

function externalConnected(): boolean {
    return ioregField("ExternalConnected") === "Yes";
}

function cmdAdapter(): void {
    const connected = externalConnected() ? "yes" : "no";
    const delivering = adapterDelivering() ? "yes" : "no";
    const w = adapterWatts();
    const n = adapterName();
    const m = adapterModel();
    const s = adapterSerial();
    const mfg = adapterManuf();

    process.stdout.write(`connected:   ${connected}\n`);
    process.stdout.write(`delivering:  ${delivering}\n`);
    process.stdout.write(`wattage:     ${w === "" ? "?" : `${w}W`}\n`);
    process.stdout.write(`name:        ${n || "?"}\n`);
    process.stdout.write(`model:       ${m || "?"}\n`);
    process.stdout.write(`serial:      ${s || "?"}\n`);
    process.stdout.write(`manufacturer: ${mfg || "?"}\n`);
    process.stdout.write(`contract:    ${adapterContract()}\n`);
}

function isCharging(): boolean {
    return ioregField("IsCharging") === "Yes";
}

function cmdCharging(): void {
    if (isCharging()) {
        process.stdout.write("yes\n");
        process.exit(0);
    }

    process.stdout.write("no\n");
    process.exit(1);
}

function systemWatts(): string {
    const aw = adapterInputWatts() || adapterWatts();
    const bw = batteryWatts();
    if (!/^\d+(\.\d+)?$/.test(aw) || aw === "0" || bw === "") {
        return "";
    }

    return (Number(aw) - Number(bw)).toFixed(1);
}

let pmsetCustomCache = "";

function loadPmsetCustom(): void {
    if (pmsetCustomCache === "") {
        pmsetCustomCache = capture(["pmset", "-g", "custom"]);
    }
}

function pmsetCustomField(source: string, key: string): string {
    loadPmsetCustom();

    let inSource = false;

    for (const raw of pmsetCustomCache.split("\n")) {
        const line = raw.trim();
        if (/^[A-Za-z ]+:$/.test(line)) {
            inSource = line.toLowerCase() === `${source.toLowerCase()}:`;
            continue;
        }

        if (!inSource) {
            continue;
        }

        const match = line.match(new RegExp(`^${key}\\s+(.+)$`, "i"));
        if (match) {
            return match[1];
        }
    }

    return "";
}

let pmsetThermCache = "";

function loadPmsetTherm(): void {
    if (pmsetThermCache === "") {
        pmsetThermCache = capture(["pmset", "-g", "therm"]);
    }
}

function thermalField(key: string): string {
    loadPmsetTherm();

    const match = pmsetThermCache.match(new RegExp(`${key}\\s*=\\s*(\\d+)`, "i"));
    return match?.[1] ?? "";
}

let pmsetAssertionsCache = "";

function loadPmsetAssertions(): void {
    if (pmsetAssertionsCache === "") {
        pmsetAssertionsCache = capture(["pmset", "-g", "assertions"]);
    }
}

function usbPowerAssertionOwners(): string[] {
    loadPmsetAssertions();

    const owners = new Set<string>();

    for (const line of pmsetAssertionsCache.split("\n")) {
        const match = line.match(/owner=(.+)$/);
        if (match?.[1]) {
            owners.add(match[1]);
        }
    }

    return [...owners];
}

function hardwareModel(): string {
    return capture(["sysctl", "-n", "hw.model"]).trim();
}

function thermalWarning(): boolean | null {
    loadPmsetTherm();

    if (pmsetThermCache === "") {
        return null;
    }

    return !(/No thermal warning level has been recorded/i.test(pmsetThermCache)
        && /No performance warning level has been recorded/i.test(pmsetThermCache));
}

let cBold = "";
let cReset = "";

function cmdDiagnose(): void {
    const aw = adapterWatts();
    const input = adapterInputWatts();
    const draw = systemWatts();
    const charging = isCharging();
    const lowPowerMode = pmsetCustomField("AC Power", "lowpowermode");
    const gpuSwitch = pmsetCustomField("AC Power", "gpuswitch");
    const cpuLimit = thermalField("CPU_Speed_Limit");
    const usbOwners = usbPowerAssertionOwners();
    const uiPct = uiPercent();
    const rawPct = rawPercent();
    const calibrationDelta = chargeCalibrationDelta();

    process.stdout.write(`model:              ${hardwareModel() || "?"}\n`);
    process.stdout.write(`plugged in:         ${externalConnected() ? "yes" : "no"}\n`);
    process.stdout.write(`charging:           ${charging ? "yes" : "no"}\n`);
    process.stdout.write(`charge estimate:    ${uiPct === "" ? "?" : `${uiPct}% UI`} / ${rawPct}% raw${calibrationDelta === "" ? "" : ` (${calibrationDelta}% calibrated)`}\n`);
    process.stdout.write(`adapter rating:     ${aw === "" ? "?" : `${aw}W`}\n`);
    process.stdout.write(`adapter input:      ${input === "" ? "?" : `${input}W`}\n`);
    process.stdout.write(`system draw:        ${draw === "" ? "?" : `${draw}W (est.)`}\n`);
    process.stdout.write(`low power mode:     ${lowPowerMode === "" ? "?" : lowPowerMode === "1" ? "on" : "off"}\n`);
    process.stdout.write(`graphics mode:      ${gpuSwitch === "" ? "?" : gpuSwitch === "0" ? "integrated" : gpuSwitch === "1" ? "discrete" : "automatic"}\n`);

    const thermal = thermalWarning();
    process.stdout.write(`thermal warning:    ${thermal === null ? "?" : thermal ? "yes" : "no"}\n`);
    process.stdout.write(`CPU speed limit:    ${cpuLimit === "" ? "?" : `${cpuLimit}%`}\n`);
    process.stdout.write(`USB power owners:   ${usbOwners.length === 0 ? "none" : usbOwners.join(", ")}\n`);

    if (externalConnected() && !charging && aw !== "" && input !== "" && Number(input) >= Number(aw) - 1) {
        process.stdout.write(`\n${cBold}Recommendation:${cReset} disconnect the dock and USB devices, then use a higher-wattage adapter directly.\n`);
    } else if (externalConnected() && !charging) {
        process.stdout.write(`\n${cBold}Recommendation:${cReset} run '${PROG} why' to inspect the charging block.\n`);
    }

    if (externalConnected() && !charging && lowPowerMode === "0") {
        process.stdout.write(`\n${cBold}Recommendation:${cReset} enable AC Low Power Mode with 'sudo pmset -c lowpowermode 1'.\n`);
    }
}

function maxCap(): string {
    return ioregField("MaxCapacity");
}

function designCap(): string {
    return ioregField("DesignCapacity");
}

function healthPct(): string {
    const rounded = roundPct(maxCap(), designCap());
    return rounded !== "" ? rounded : "?";
}

function cycles(): string {
    return ioregField("CycleCount");
}

function systemProfilerPowerField(label: string): string {
    loadSystemProfilerPower();

    const match = systemProfilerPowerCache.match(new RegExp(`^\\s*${label}:\\s*(.+)$`, "mi"));
    return match?.[1].trim() ?? "";
}

function condition(): string {
    const macCondition = systemProfilerPowerField("Condition");
    if (macCondition !== "") {
        return macCondition;
    }

    const h = healthPct();
    if (h === "?") {
        return "Unknown";
    }

    const n = Number(h);
    if (n >= 80) {
        return "Normal";
    }

    if (n >= 65) {
        return "Fair";
    }

    return "Service Recommended";
}

function cmdHealth(): void {
    const h = healthPct();
    const cyc = cycles();
    const cond = condition();
    const m = maxCap() || "?";
    const d = designCap() || "?";
    process.stdout.write(`health:    ${h}% (${m} / ${d} mAh)\n`);
    process.stdout.write(`cycles:    ${cyc || "?"}\n`);
    process.stdout.write(`condition: ${cond}\n`);
}

function cmdHelp(): void {
    process.stdout.write(`Usage: ${PROG} [--basic] [--no-color] <subcommand> [args]

Subcommands:
  status         Short human summary (default)
  percent        Charge percent as a bare integer
  charging       yes/no; exits 0 if charging, 1 if not
  health         MaxCapacity / DesignCapacity, cycle count, condition
  adapter        Adapter wattage, model, serial, connected/delivering state
  time           Time-to-full or time-to-empty (calculating when unknown)
  temp           Battery temperature in °C
  power          Current flow, adapter vs. system-draw budget, CPU load
  diagnose       Charging limits, power settings, thermals, and USB devices
  why            Why isn't it charging while plugged in?
  raw            Full ioreg -rn AppleSmartBattery dump
  json           Emit all values as a single JSON object
  watch [N]      Repaint status every N seconds (default 5)
  help           This message

Env:
  NO_COLOR=1     Disable ANSI color (also: pass --no-color)

Flags:
  --basic        Use the original one-line status display
`);
}

let pmsetBattCache = "";

function loadPmsetBatt(): void {
    if (pmsetBattCache !== "") {
        return;
    }

    pmsetBattCache = capture(["pmset", "-g", "batt"]);
}

function powerTelemetryWatts(): string {
    return telemetryWatts("SystemLoad");
}

function netCharging(): boolean | null {
    const ma = amperageMa();
    if (ma === "") {
        return null;
    }

    return Number(ma) > 0;
}

function loadavg(): string {
    return capture(["sysctl", "-n", "vm.loadavg"]).trim().split(/\s+/)[1] ?? "";
}

function ncpu(): string {
    return capture(["sysctl", "-n", "hw.ncpu"]).trim();
}

function percent(): string {
    return uiPercent() || rawPercent();
}

function tempC(): string {
    const raw = ioregField("Temperature");
    if (raw === "") {
        return "?";
    }

    const r = Number(raw);
    const k = r / 10.0 - 273.15;
    if (k > -5 && k < 120) {
        return k.toFixed(1);
    }

    const c = r / 100.0;
    if (c > -5 && c < 120) {
        return c.toFixed(1);
    }

    return (r / 100.0).toFixed(1);
}

function pmsetTimeRemaining(): string {
    loadPmsetBatt();

    for (const line of pmsetBattCache.split("\n")) {
        if (!/InternalBattery/i.test(line)) {
            continue;
        }

        for (const token of line.split(/\s+/)) {
            if (/^\d+:\d+$/.test(token)) {
                return token;
            }
        }
    }

    return "";
}

function notChargingReason(): string {
    return ioregSubfield("ChargerData", "NotChargingReason");
}

function jsonNum(v: string): string {
    if (v === "" || v === "?") {
        return "null";
    }

    return v;
}

function jsonStr(s: string): string {
    return `"${s.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
}

function fullyCharged(): boolean {
    return ioregField("FullyCharged") === "Yes";
}

function stateLabel(): string {
    if (isCharging()) {
        return "charging";
    }

    if (fullyCharged()) {
        return "full";
    }

    if (externalConnected()) {
        return "plugged (not charging)";
    }

    return "on battery";
}

function powerSource(): string {
    loadPmsetBatt();

    const match = pmsetBattCache.match(/Now drawing from '([^']+)'/);
    return match?.[1] ?? "";
}

function notChargingReasonHuman(code: string): string {
    if (code === "" || code === "0") {
        return "none";
    }

    const n = Number(code);
    const parts: string[] = [];
    if (n & 1) parts.push("not-charging-requested");
    if (n & 2) parts.push("fully-charged");
    if (n & 4) parts.push("optimized-battery-charging-paused");
    if (n & 8) parts.push("charger-thermal-limit");
    if (n & 16) parts.push("battery-thermal-limit");
    if (n & 32) parts.push("voltage-limit");
    if (n & 64) parts.push("charger-fault");
    if (n & 128) parts.push("battery-fault");
    if (n & 256) parts.push("hardware-limit");
    return parts.length > 0 ? parts.join(", ") : `unknown(raw=${code})`;
}

function optimizedState(): string {
    loadPmsetBatt();

    if (/optimized/i.test(pmsetBattCache)) {
        return "engaged";
    }

    const code = notChargingReason();
    if (code !== "" && code !== "0" && (Number(code) & 4)) {
        return "engaged";
    }

    return "off-or-unknown";
}

function cmdJson(): void {
    loadIoreg();
    loadPmsetBatt();
    loadPmsetAc();

    const amp = amperageMa();
    const bw = batteryWatts();
    const sw = systemWatts();
    const telemetry = powerTelemetryWatts();
    const input = adapterInputWatts();
    const net = netCharging();
    const load = loadavg();
    const cores = ncpu();
    const pct = percent();
    const uiPct = uiPercent();
    const rawPct = rawPercent();
    const calibrationDelta = chargeCalibrationDelta();
    const cyc = cycles();
    const h = healthPct();
    const m = maxCap();
    const d = designCap();
    const temp = tempC();
    const w = adapterWatts();
    let t = pmsetTimeRemaining();
    if (t === "") {
        t = "calculating";
    }

    const code = notChargingReason() || "0";

    process.stdout.write("{");
    process.stdout.write(`"percent":${jsonNum(pct)},`);
    process.stdout.write(`"ui_percent":${jsonNum(uiPct)},`);
    process.stdout.write(`"raw_percent":${jsonNum(rawPct)},`);
    process.stdout.write(`"charge_calibration_delta":${jsonNum(calibrationDelta)},`);
    process.stdout.write(`"state":${jsonStr(stateLabel())},`);
    process.stdout.write(`"charging":${isCharging()},`);
    process.stdout.write(`"external_connected":${externalConnected()},`);
    process.stdout.write(`"fully_charged":${fullyCharged()},`);
    process.stdout.write(`"time_remaining":${jsonStr(t)},`);
    process.stdout.write(`"amperage_ma":${jsonNum(amp)},`);
    process.stdout.write(`"battery_watts":${jsonNum(bw)},`);
    process.stdout.write(`"system_watts":${jsonNum(sw)},`);
    process.stdout.write(`"power_telemetry_watts":${jsonNum(telemetry)},`);
    process.stdout.write(`"adapter_input_watts":${jsonNum(input)},`);
    process.stdout.write(`"net_charging":${net === true},`);
    process.stdout.write(`"load_average":${jsonNum(load)},`);
    process.stdout.write(`"cpu_count":${jsonNum(cores)},`);
    process.stdout.write(`"temperature_c":${jsonNum(temp)},`);
    process.stdout.write(`"cycles":${jsonNum(cyc)},`);
    process.stdout.write(`"health_percent":${jsonNum(h)},`);
    process.stdout.write(`"max_capacity_mah":${jsonNum(m)},`);
    process.stdout.write(`"design_capacity_mah":${jsonNum(d)},`);
    process.stdout.write(`"condition":${jsonStr(condition())},`);
    process.stdout.write(`"battery_below_warning":${batteryBelowWarning() === "" ? "null" : batteryBelowWarning() === "Yes"},`);
    process.stdout.write(`"power_source":${jsonStr(powerSource())},`);
    process.stdout.write(`"adapter":{`);
    process.stdout.write(`"connected":${externalConnected()},`);
    process.stdout.write(`"delivering":${adapterDelivering()},`);
    process.stdout.write(`"watts":${jsonNum(w)},`);
    process.stdout.write(`"voltage":${jsonNum(adapterVoltage())},`);
    process.stdout.write(`"current":${jsonNum(adapterCurrent())},`);
    process.stdout.write(`"name":${jsonStr(adapterName())},`);
    process.stdout.write(`"model":${jsonStr(adapterModel())},`);
    process.stdout.write(`"serial":${jsonStr(adapterSerial())},`);
    process.stdout.write(`"manufacturer":${jsonStr(adapterManuf())}`);
    process.stdout.write("},");
    process.stdout.write(`"not_charging_reason_code":${code},`);
    process.stdout.write(`"not_charging_reason":${jsonStr(notChargingReasonHuman(code))},`);
    process.stdout.write(`"optimized_charging":${jsonStr(optimizedState())},`);
    process.stdout.write(`"ac_low_power_mode":${jsonNum(pmsetCustomField("AC Power", "lowpowermode"))},`);
    process.stdout.write(`"ac_graphics_mode":${jsonNum(pmsetCustomField("AC Power", "gpuswitch"))},`);

    const thermal = thermalWarning();
    process.stdout.write(`"thermal_warning":${thermal === null ? "null" : thermal},`);
    process.stdout.write(`"cpu_speed_limit_percent":${jsonNum(thermalField("CPU_Speed_Limit"))},`);
    process.stdout.write(`"usb_power_assertion_owners":${JSON.stringify(usbPowerAssertionOwners())},`);
    process.stdout.write(`"hardware_model":${jsonStr(hardwareModel())},`);
    process.stdout.write(`"arch":${jsonStr(arch())}`);
    process.stdout.write("}\n");
}

function cmdPercent(): void {
    process.stdout.write(percent());
}

let cGreen = "";
let cYellow = "";
let cRed = "";

function cmdPower(): void {
    const ma = amperageMa();
    const bw = batteryWatts();
    const aw = adapterWatts();
    const estimatedSw = systemWatts();
    const telemetry = powerTelemetryWatts();
    const input = adapterInputWatts();
    const load = loadavg();
    const cores = ncpu();
    const conn = externalConnected() ? "yes" : "no";
    let flow = "unknown";

    if (ma !== "") {
        const n = Number(ma);
        if (n > 0) {
            flow = `${cGreen}charging (+${ma} mA)${cReset}`;
        } else if (n < 0) {
            flow = `${cYellow}discharging (${ma} mA)${cReset}`;
        } else {
            flow = "idle (0 mA)";
        }
    }

    process.stdout.write(`plugged in:     ${conn}\n`);
    process.stdout.write(`current flow:   ${flow}\n`);
    process.stdout.write(`battery power:  ${bw === "" ? "" : `${bw}W`}\n`);
    process.stdout.write(`adapter rating: ${aw === "" ? "" : `${aw}W`}\n`);
    process.stdout.write(`adapter input:  ${input === "" ? "?" : `${input}W`}\n`);
    process.stdout.write(`system draw:    ${estimatedSw === "" ? "?" : `${estimatedSw}W (est.)`}\n`);
    process.stdout.write(`power telemetry: ${telemetry === "" ? "?" : `${telemetry}W`}\n`);
    process.stdout.write(`load average:   ${load || "?"} / ${cores || "?"} cores\n`);

    if (conn === "yes" && ma !== "" && Number(ma) <= 0 && !fullyCharged()) {
        process.stdout.write(
            `\n${cBold}Verdict:${cReset} plugged in but ${cRed}not gaining charge${cReset}.\n`,
        );

        const saturated = input !== "" && /^\d+$/.test(aw) && aw !== "0" && Number(input) >= Number(aw) - 1;
        if (saturated) {
            process.stdout.write(
                `  Adapter input (~${input}W) is at its rated output (${aw}W).\n`,
            );
        }

        if (load !== "" && /^\d+$/.test(cores) && Number(load) > Number(cores) * 0.75) {
            process.stdout.write(
                `  High CPU load (${load} on ${cores} cores). Quit heavy apps or use a higher-wattage adapter.\n`,
            );
        }
    }
}

function cmdRaw(): void {
    loadIoreg();
    process.stdout.write(ioregCache.endsWith("\n") ? ioregCache : ioregCache + "\n");
}

let statusFrame = "";
let basicStatus = false;

function writeStatus(text: string): void {
    statusFrame += text;
}

function iconState(): string {
    if (isCharging()) {
        return "⚡";
    }

    if (externalConnected()) {
        return "🔌";
    }

    return "🔋";
}

let cDim = "";

function pctColor(p: string): string {
    if (p === "?") {
        return cDim;
    }

    const n = Number(p);
    if (n >= 60) {
        return cGreen;
    }

    if (n >= 25) {
        return cYellow;
    }

    return cRed;
}

let cCyan = "";
const dashboardWidth = 78;

function dashboardBorder(): void {
    writeStatus(`+${"-".repeat(dashboardWidth - 2)}+\n`);
}

function visibleLength(text: string): number {
    return text.replace(/\x1b\[[0-9;]*m/g, "").length;
}

function dashboardRows(text: string): void {
    const contentWidth = dashboardWidth - 4;
    const words = text.split(/\s+/);
    let line = "";

    for (const word of words) {
        const next = line === "" ? word : `${line} ${word}`;
        if (visibleLength(next) > contentWidth && line !== "") {
            writeStatus(`| ${line}${" ".repeat(contentWidth - visibleLength(line))} |\n`);
            line = word;
        } else {
            line = next;
        }
    }

    writeStatus(`| ${line}${" ".repeat(contentWidth - visibleLength(line))} |\n`);
}

function dashboardSection(title: string): void {
    dashboardRows(`${cBold}${cCyan}${title}${cReset}`);
    writeStatus(`| ${"-".repeat(dashboardWidth - 4)} |\n`);
}

function stateColor(state: string): string {
    if (state === "full") {
        return cGreen;
    }

    if (state === "charging" || state === "plugged (not charging)") {
        return cYellow;
    }

    return cRed;
}

function currentFlow(): string {
    const ma = amperageMa();
    if (ma === "") {
        return "unknown";
    }

    const value = Number(ma);
    if (value > 0) {
        return `charging +${ma}mA`;
    }

    if (value < 0) {
        return `discharging ${ma}mA`;
    }

    return "idle 0mA";
}

function renderStatus(): string {
    statusFrame = "";

    const pct = percent();
    const state = stateLabel();
    let t = pmsetTimeRemaining();
    if (t === "") {
        t = "—";
    }

    let w = adapterWatts();
    w = w === "" ? "—" : `${w}W`;

    const h = healthPct();
    let cyc = cycles();
    if (cyc === "") {
        cyc = "?";
    }

    const temp = tempC();

    if (basicStatus) {
        writeStatus(
            `${iconState()} ${cBold}${pctColor(pct)}${pct}%${cReset}  ${cCyan}${state}${cReset}  time: ${t}  adapter: ${w}  health: ${h}%  cycles: ${cyc}  temp: ${temp}°C\n`,
        );

        return statusFrame;
    }

    const uiPct = uiPercent();
    const rawPct = rawPercent();
    const calibrationDelta = chargeCalibrationDelta();
    const capacity = `${maxCap() || "?"}/${designCap() || "?"}mAh`;
    const warning = batteryBelowWarning().toLowerCase() || "?";
    const input = adapterInputWatts();
    const draw = systemWatts();
    const batteryPower = batteryWatts();
    const lowPowerMode = pmsetCustomField("AC Power", "lowpowermode");
    const graphicsMode = pmsetCustomField("AC Power", "gpuswitch");
    const thermal = thermalWarning();
    const cpuLimit = thermalField("CPU_Speed_Limit");
    const owners = usbPowerAssertionOwners();
    const reason = notChargingReasonHuman(notChargingReason() || "0");
    const displayedCharge = uiPct === ""
        ? `${pctColor(pct)}[${chargeBar(pct)}] ${pct}% gauge${cReset}`
        : `${pctColor(pct)}[${chargeBar(pct)}] ${pct}% UI${cReset} (${rawPct}% gauge${calibrationDelta === "" ? "" : `, ${calibrationDelta}% calibrated`})`;

    const conditionColor = condition() === "Normal" ? cGreen : cRed;
    const warningColor = warning === "no" ? cGreen : warning === "yes" ? cRed : cDim;
    const flowColor = netCharging() === true ? cGreen : netCharging() === false ? cYellow : cDim;
    const reasonColor = reason === "none" ? cGreen : cRed;
    const thermalColor = thermal === false ? cGreen : thermal === true ? cRed : cDim;
    const lowPowerColor = lowPowerMode === "1" ? cGreen : lowPowerMode === "0" ? cYellow : cDim;

    dashboardBorder();
    dashboardSection(`BATTERY ${stateColor(state)}(${state})${cReset}${cBold}${cCyan}`);
    dashboardRows(`Charge: ${displayedCharge}`);
    dashboardRows(`Time: ${t} | temperature: ${temp}C | low warning: ${warningColor}${warning}${cReset}`);
    dashboardRows(`Health: ${pctColor(h)}[${chargeBar(h)}] ${h}%${cReset} | ${conditionColor}${condition()}${cReset} | ${capacity} | ${cyc} cycles`);
    dashboardBorder();
    dashboardSection("POWER AND CHARGING");
    dashboardRows(`Source: ${cCyan}${powerSource() || "?"}${cReset} | adapter: ${cCyan}${w}${cReset} | contract: ${adapterContract()} | input: ${input === "" ? "?" : `${input}W`}`);
    dashboardRows(`Battery flow: ${flowColor}${currentFlow()}${cReset}${batteryPower === "" ? "" : ` / ${batteryPower}W`} | system draw: ${draw === "" ? "?" : `${draw}W estimated`}`);
    dashboardRows(`Optimized charging: ${optimizedState()} | charging blocker: ${reasonColor}${reason}${cReset}`);
    dashboardRows(`Low Power Mode: ${lowPowerColor}${lowPowerMode === "1" ? "on" : lowPowerMode === "0" ? "off" : "?"}${cReset} | graphics: ${graphicsMode === "0" ? "integrated" : graphicsMode === "1" ? "discrete" : graphicsMode === "" ? "?" : "automatic"}`);
    dashboardRows(`Thermal warning: ${thermalColor}${thermal === null ? "?" : thermal ? "yes" : "no"}${cReset} | CPU speed limit: ${cpuLimit === "" ? "?" : `${cpuLimit}%`}`);
    dashboardBorder();
    dashboardSection("USB POWER ASSERTION OWNERS");
    dashboardRows(owners.length === 0 ? "None" : `${owners.length} active: ${owners.join(", ")}`);
    dashboardBorder();

    return statusFrame;
}

function cmdStatus(): void {
    process.stdout.write(renderStatus());
}

function cmdTemp(): void {
    process.stdout.write(`${tempC()}°C\n`);
}

function cmdTime(): void {
    const t = pmsetTimeRemaining();
    process.stdout.write(`${t === "" ? "calculating" : t}\n`);
}

let useColor = true;

function millisecondsUntilFollowingMinute(now: Date): number {
    const elapsed = now.getSeconds() * 1000 + now.getMilliseconds();
    return 60_000 - elapsed;
}

function millisecondsUntilNextRefresh(startedAt: Date, now: Date, intervalSeconds: number): number {
    const regularRefresh = startedAt.getTime() + intervalSeconds * 1000 - now.getTime();
    return Math.max(0, Math.min(regularRefresh, millisecondsUntilFollowingMinute(now)));
}

async function cmdWatch(intervalArg: string): Promise<void> {
    if (!/^\d+$/.test(intervalArg) || Number(intervalArg) === 0) {
        die("watch interval must be a positive integer");
    }

    const interval = Number(intervalArg);

    process.on("SIGINT", () => {
        process.stdout.write("\n");
        process.exit(0);
    });

    while (true) {
        const refreshStartedAt = new Date();

        ioregCache = "";
        pmsetBattCache = "";
        pmsetAcCache = "";
        pmsetCustomCache = "";
        pmsetThermCache = "";
        pmsetAssertionsCache = "";
        systemProfilerPowerCache = "";

        const status = renderStatus();
        const now = new Date();
        const hh = String(now.getHours()).padStart(2, "0");
        const mm = String(now.getMinutes()).padStart(2, "0");
        const ss = String(now.getSeconds()).padStart(2, "0");
        const frame = `${cDim}${hh}:${mm}:${ss}${cReset} — every ${interval}s (Ctrl-C to exit)\n\n${status}`;
        process.stdout.write(`${useColor ? "\x1b[2J\x1b[H" : ""}${frame}`);
        await Bun.sleep(millisecondsUntilNextRefresh(refreshStartedAt, new Date(), interval));
    }
}

function cmdWhy(): void {
    const connected = externalConnected() ? "yes" : "no";
    const charging = isCharging() ? "yes" : "no";
    const full = fullyCharged() ? "yes" : "no";
    const code = notChargingReason() || "0";
    const reason = notChargingReasonHuman(code);
    const optimized = optimizedState();
    const ma = amperageMa();

    process.stdout.write(`plugged in:           ${connected}\n`);
    process.stdout.write(`charging:             ${charging}\n`);
    process.stdout.write(`fully charged:        ${full}\n`);
    process.stdout.write(`net current:          ${ma === "" ? "" : `${ma} mA`}\n`);
    process.stdout.write(`NotChargingReason:    ${code} (${reason})\n`);
    process.stdout.write(`Optimized Charging:   ${optimized}\n`);

    if (connected === "yes" && charging === "no" && full === "no") {
        if (reason === "none" && ma !== "" && Number(ma) <= 0) {
            const verb = Number(ma) < 0 ? "draining" : "flat";

            process.stdout.write(
                `\n${cBold}Why not charging:${cReset} nothing is blocking charge, but the battery is net ${cRed}${verb}${cReset}.\n`,
            );

            process.stdout.write(
                `  System load likely exceeds adapter output. Run ${cDim}'${PROG} power'${cReset} for the breakdown.\n`,
            );
        } else {
            process.stdout.write(`\n${cBold}Why not charging:${cReset} ${reason}\n`);
        }

        if (arch() === "arm64") {
            process.stdout.write(
                `${cDim}Tip:${cReset} On Apple Silicon, an SMC reset is done by shutting down and holding power 10s.\n`,
            );
        } else if (arch() === "x86_64") {
            process.stdout.write(
                `${cDim}Tip:${cReset} On Intel Macs, reset SMC via Shift+Ctrl+Option+Power for 10s (T2) or per-model steps.\n`,
            );
        }
    }
}

function colorInit(): void {
    if (process.env.NO_COLOR || !process.stdout.isTTY) {
        useColor = false;
    }

    if (useColor) {
        cReset = "\x1b[0m";
        cBold = "\x1b[1m";
        cDim = "\x1b[2m";
        cGreen = "\x1b[32m";
        cYellow = "\x1b[33m";
        cRed = "\x1b[31m";
        cCyan = "\x1b[36m";
    } else {
        cReset = "";
        cBold = "";
        cDim = "";
        cGreen = "";
        cYellow = "";
        cRed = "";
        cCyan = "";
    }
}

function requireMac(): void {
    if (process.platform !== "darwin") {
        die(`macOS only (uname=${process.platform})`);
    }
}

async function main(argv: string[]): Promise<void> {
    requireMac();

    const args: string[] = [];

    for (const a of argv) {
        if (a === "--no-color") {
            useColor = false;
        } else if (a === "--basic") {
            basicStatus = true;
        } else {
            args.push(a);
        }
    }

    colorInit();

    const sub = args[0] ?? "status";
    switch (sub) {
        case "status":
        cmdStatus();
        break;
        case "percent":
        cmdPercent();
        break;
        case "charging":
        cmdCharging();
        break;
        case "health":
        cmdHealth();
        break;
        case "adapter":
        cmdAdapter();
        break;
        case "time":
        cmdTime();
        break;
        case "temp":
        cmdTemp();
        break;
        case "power":
        cmdPower();
        break;
        case "diagnose":
        cmdDiagnose();
        break;
        case "why":
        cmdWhy();
        break;
        case "raw":
        cmdRaw();
        break;
        case "json":
        cmdJson();
        break;
        case "watch":
        await cmdWatch(args[1] ?? "5");
        break;
        case "help":
        case "-h":
        case "--help":
        cmdHelp();
        break;
        default:
        die(`unknown subcommand: ${sub} (try '${PROG} help')`);
    }
}

if (import.meta.main) {
    void main(process.argv.slice(2));
}