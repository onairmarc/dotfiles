import {Argument, Command} from "commander";
import {
    type JetBrainsMcpServer,
    installSkills,
    removeSkills,
    setLocalJetBrainsMcpServer,
    syncGlobalOpencode,
} from "./lib.ts";

const NC = "\x1b[0m";
const RED = "\x1b[0;31m";

function installAndSync(debug = false): void {
    installSkills();
    syncGlobalOpencode(debug);
}

export function createAiSetupProgram(): Command {
    const program = new Command("ai_setup")
        .description("Install AI skills and synchronize OpenCode configuration")
        .helpCommand("help [command]", "Display help for command")
        .showHelpAfterError();

    program
        .option("--debug", "Show already-synchronized files")
        .action((options: {debug?: boolean}) => {
            installAndSync(options.debug);
        });

    program
        .command("install")
        .description("Install third-party skills and synchronize OpenCode")
        .option("--debug", "Show already-synchronized files")
        .action((_options: {debug?: boolean}, command: Command) => {
            installAndSync(command.optsWithGlobals().debug);
        });

    program
        .command("reinstall")
        .description("Reinstall third-party skills and synchronize OpenCode")
        .option("--debug", "Show already-synchronized files")
        .action((_options: {debug?: boolean}, command: Command) => {
            removeSkills();
            installAndSync(command.optsWithGlobals().debug);
        });

    program
        .command("sync")
        .description("Synchronize OpenCode configuration, skills, agents, and plugins")
        .option("--debug", "Show already-synchronized files")
        .action((_options: {debug?: boolean}, command: Command) => {
            syncGlobalOpencode(command.optsWithGlobals().debug);
        });

    program
        .command("mcp")
        .description("Configure project-local MCP servers")
        .command("ide")
        .description("Enable a JetBrains IDE MCP server in the current Git project")
        .addArgument(new Argument("<server>", "JetBrains IDE").choices(["phpstorm", "rider"]))
        .action((server: JetBrainsMcpServer) => {
            setLocalJetBrainsMcpServer(server, true);
        });

    return program;
}

function main(args: string[]): void {
    createAiSetupProgram().parse(args, {from: "user"});
}

if (import.meta.main) {
    try {
        main(process.argv.slice(2));
    } catch (error) {
        process.stderr.write(`${RED}[ERROR]${NC} ${error instanceof Error ? error.message : String(error)}\n`);
        process.exit(1);
    }
}
