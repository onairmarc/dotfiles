// provision/configurators/opencode.ts
//
// Publishes global OpenCode configuration, agent instructions, skills, and plugins.
import {syncGlobalOpencode, syncSkills} from "../../tools/ai_setup/lib.ts";

export function run(): void {
    syncSkills();
    syncGlobalOpencode();
}
