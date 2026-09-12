import type {PluginModule} from "@opencode-ai/plugin";
import {skillCommands, skillTemplate} from "../lib/skill-commands";

const plugin: PluginModule = {
    id: "custom",
    server: async () => ({
        config: async (config) => {
            config.command ??= {};

            for (const [command, route] of Object.entries(skillCommands)) {
                config.command[command] = {
                    description: route.description,
                    template: skillTemplate(route.skill),
                };
            }
        },
    }),
};

export default plugin;