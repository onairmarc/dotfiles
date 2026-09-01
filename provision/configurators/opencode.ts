// provision/configurators/opencode.ts
//
// Publishes global OpenCode configuration, agent instructions, skills, and plugins.
import {syncGlobalOpencode} from "../../tools/agent_symlink.ts";

export function run(): void {
    syncGlobalOpencode();
}
