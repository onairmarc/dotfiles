let ioregCache = "";

function capture(argv: string[]): string {
    const r = Bun.spawnSync(argv, {stdout: "pipe", stderr: "pipe"});
    return r.stdout ? r.stdout.toString() : "";
}

const PROG = "battery";

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

function batteryWatts(): string {
    const ma = amperageMa();
    const mv = ioregField("Voltage");
    if (ma === "" || !/^\d+$/.test(mv)) {
        return "";
    }

    return ((Number(ma) / 1000.0) * (Number(mv) / 1000.0)).toFixed(1);
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

function roundPct(cur: string, max: string): string {
    if (cur !== "" && max !== "" && max !== "0") {
        return String(Math.floor((Number(cur) / Number(max) * 100) + 0.5));
    }

    return "";
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

function condition(): string {
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
    process.stdout.write(`Usage: ${PROG} [--no-color] <subcommand> [args]

Subcommands:
  status         Short human summary (default)
  percent        Charge percent as a bare integer
  charging       yes/no; exits 0 if charging, 1 if not
  health         MaxCapacity / DesignCapacity, cycle count, condition
  adapter        Adapter wattage, model, serial, connected/delivering state
  time           Time-to-full or time-to-empty (calculating when unknown)
  temp           Battery temperature in °C
  power          Current flow, adapter vs. system-draw budget, CPU load
  why            Why isn't it charging while plugged in?
  raw            Full ioreg -rn AppleSmartBattery dump
  json           Emit all values as a single JSON object
  watch [N]      Repaint status every N seconds (default 5)
  help           This message

Env:
  NO_COLOR=1     Disable ANSI color (also: pass --no-color)
`);
}

let pmsetBattCache = "";

function loadPmsetBatt(): void {
    if (pmsetBattCache !== "") {
        return;
    }

    pmsetBattCache = capture(["pmset", "-g", "batt"]);
}

function systemWatts(): string {
    const aw = adapterWatts();
    const bw = batteryWatts();
    if (!/^\d+$/.test(aw) || aw === "0" || bw === "") {
        return "";
    }

    return (Number(aw) - Number(bw)).toFixed(1);
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
    const fromNamed = roundPct(ioregField("CurrentCapacity"), ioregField("MaxCapacity"));
    if (fromNamed !== "") {
        return fromNamed;
    }

    const fromRaw = roundPct(ioregField("AppleRawCurrentCapacity"), ioregField("AppleRawMaxCapacity"));
    return fromRaw !== "" ? fromRaw : "?";
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
    const net = netCharging();
    const load = loadavg();
    const cores = ncpu();
    const pct = percent();
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
    process.stdout.write(`"state":${jsonStr(stateLabel())},`);
    process.stdout.write(`"charging":${isCharging()},`);
    process.stdout.write(`"external_connected":${externalConnected()},`);
    process.stdout.write(`"fully_charged":${fullyCharged()},`);
    process.stdout.write(`"time_remaining":${jsonStr(t)},`);
    process.stdout.write(`"amperage_ma":${jsonNum(amp)},`);
    process.stdout.write(`"battery_watts":${jsonNum(bw)},`);
    process.stdout.write(`"system_watts":${jsonNum(sw)},`);
    process.stdout.write(`"net_charging":${net === true},`);
    process.stdout.write(`"load_average":${jsonNum(load)},`);
    process.stdout.write(`"cpu_count":${jsonNum(cores)},`);
    process.stdout.write(`"temperature_c":${jsonNum(temp)},`);
    process.stdout.write(`"cycles":${jsonNum(cyc)},`);
    process.stdout.write(`"health_percent":${jsonNum(h)},`);
    process.stdout.write(`"max_capacity_mah":${jsonNum(m)},`);
    process.stdout.write(`"design_capacity_mah":${jsonNum(d)},`);
    process.stdout.write(`"condition":${jsonStr(condition())},`);
    process.stdout.write(`"adapter":{`);
    process.stdout.write(`"connected":${externalConnected()},`);
    process.stdout.write(`"delivering":${adapterDelivering()},`);
    process.stdout.write(`"watts":${jsonNum(w)},`);
    process.stdout.write(`"name":${jsonStr(adapterName())},`);
    process.stdout.write(`"model":${jsonStr(adapterModel())},`);
    process.stdout.write(`"serial":${jsonStr(adapterSerial())},`);
    process.stdout.write(`"manufacturer":${jsonStr(adapterManuf())}`);
    process.stdout.write("},");
    process.stdout.write(`"not_charging_reason_code":${code},`);
    process.stdout.write(`"not_charging_reason":${jsonStr(notChargingReasonHuman(code))},`);
    process.stdout.write(`"optimized_charging":${jsonStr(optimizedState())},`);
    process.stdout.write(`"arch":${jsonStr(arch())}`);
    process.stdout.write("}\n");
}

function cmdPercent(): void {
    process.stdout.write(percent());
}

let cGreen = "";

let cReset = "";

let cYellow = "";

let cBold = "";

let cRed = "";

function cmdPower(): void {
    const ma = amperageMa();
    const bw = batteryWatts();
    const aw = adapterWatts();
    const sw = systemWatts();
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
    process.stdout.write(`system draw:    ${sw === "" ? "" : `${sw}W (est.)`}\n`);
    process.stdout.write(`load average:   ${load || "?"} / ${cores || "?"} cores\n`);

    if (conn === "yes" && ma !== "" && Number(ma) <= 0 && !fullyCharged()) {
        process.stdout.write(
            `\n${cBold}Verdict:${cReset} plugged in but ${cRed}not gaining charge${cReset}.\n`,
        );

        if (sw !== "" && /^\d+$/.test(aw) && aw !== "0" && Number(sw) > Number(aw)) {
            process.stdout.write(
                `  System draw (~${sw}W) exceeds adapter rating (${aw}W) — battery covers the gap.\n`,
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

function cmdStatus(): void {
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

    process.stdout.write(
        `${iconState()} ${cBold}${pctColor(pct)}${pct}%${cReset}  ${cCyan}${state}${cReset}  time: ${t}  adapter: ${w}  health: ${h}%  cycles: ${cyc}  temp: ${temp}°C\n`,
    );
}

function cmdTemp(): void {
    process.stdout.write(`${tempC()}°C\n`);
}

function cmdTime(): void {
    const t = pmsetTimeRemaining();
    process.stdout.write(`${t === "" ? "calculating" : t}\n`);
}

let useColor = true;

function cmdWatch(intervalArg: string): void {
    if (!/^\d+$/.test(intervalArg)) {
        die("watch interval must be a positive integer");
    }

    const interval = Number(intervalArg);

    process.on("SIGINT", () => {
        process.stdout.write("\n");
        process.exit(0);
    });

    while (true) {
        ioregCache = "";
        pmsetBattCache = "";
        pmsetAcCache = "";

        if (useColor) {
            process.stdout.write("\x1b[2J\x1b[H");
        }

        const now = new Date();
        const hh = String(now.getHours()).padStart(2, "0");
        const mm = String(now.getMinutes()).padStart(2, "0");
        const ss = String(now.getSeconds()).padStart(2, "0");
        process.stdout.write(`${cDim}${hh}:${mm}:${ss}${cReset} — every ${interval}s (Ctrl-C to exit)\n\n`);
        cmdStatus();
        Bun.sleepSync(interval * 1000);
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

function main(argv: string[]): void {
    requireMac();

    const args: string[] = [];

    for (const a of argv) {
        if (a === "--no-color") {
            useColor = false;
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
            cmdWatch(args[1] ?? "5");
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
    main(process.argv.slice(2));
}