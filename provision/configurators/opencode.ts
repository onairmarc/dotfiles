// provision/configurators/opencode.ts
//
// Publishes global OpenCode configuration, agent instructions, skills, and plugins.
import {syncGlobalOpencode} from "../../tools/ai_setup.ts";

export function run(): void {
    syncGlobalOpencode();
}
