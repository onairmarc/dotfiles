import type {PluginModule} from "@opencode-ai/plugin";
import {expandFilePickerCommand} from "../lib/file-picker-commands";
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
        "chat.message": async (_input, output) => expandFilePickerCommand(output, skillTemplate),
    }),
};

export default plugin;
