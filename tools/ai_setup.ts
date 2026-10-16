type Options = {
    claude: boolean;
    reinstall: boolean;
};

function agentFlags(claude: boolean): string[] {
    return claude ? ["--agent", "opencode", "--agent", "claude-code"] : ["--agent", "opencode"];
}

const USAGE = "Usage: ai_setup [--claude] [--skills] [--reinstall]";

function fail(message: string): never {
    process.stderr.write(`Error: ${message}\n${USAGE}\n`);
    process.exit(1);
}

const SKILLS = [
    {repository: "mattpocock/skills", skill: "*"},
    {repository: "vercel-labs/agent-skills", skill: "vercel-react-best-practices"},
    {repository: "JuliusBrussee/caveman", skill: "*"},
];

function run(command: string[]): void {
    const result = Bun.spawnSync(command, {stdin: "inherit", stdout: "inherit", stderr: "inherit"});
    if (result.exitCode !== 0) {
        throw new Error(`command failed: ${command.join(" ")}`);
    }
}

function installSkills(agents: string[]): void {
    for (const {repository, skill} of SKILLS) {
        run(["bunx", "skills@latest", "add", repository, "--global", "--skill", skill, ...agents, "-y"]);
    }
}

function parseOptions(args: string[]): Options {
    const options: Options = {claude: false, reinstall: false};

    for (const arg of args) {
        switch (arg) {
            case "--claude":
                options.claude = true;
                break;
            case "--skills":
                break;
            case "--reinstall":
                options.reinstall = true;
                break;
            case "-h":
            case "--help":
                process.stdout.write(`${USAGE}\n`);
                process.exit(0);
            default:
                fail(`unknown option: ${arg}`);
        }
    }

    return options;
}

function removeSkills(agents: string[]): void {
    try {
        run(["bunx", "skills@latest", "remove", "--global", "--skill", "*", ...agents, "-y"]);
    } catch {
        // The remove command is best effort so a first installation still succeeds.
    }
}

function main(args: string[]): void {
    const options = parseOptions(args);
    const agents = agentFlags(options.claude);

    if (options.reinstall) {
        removeSkills(agents);
    }

    installSkills(agents);
}

if (import.meta.main) {
    try {
        main(process.argv.slice(2));
    } catch (error) {
        process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
        process.exit(1);
    }
}