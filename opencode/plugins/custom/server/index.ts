import type {PluginModule} from "@opencode-ai/plugin";
import {filePickerCommands} from "../lib/file-picker-commands";
import {skillCommands, skillTemplate} from "../lib/skill-commands";

function selectedFilePickerCommand(text: string): {path: string; skill: string} | undefined {
    for (const command of filePickerCommands) {
        const prefix = `/${command.command} @`;
        if (!text.startsWith(prefix)) {
            continue;
        }

        const path = text.slice(prefix.length).trim();
        if (path !== "" && command.matchesPath(path)) {
            return {path, skill: command.skill};
        }
    }
}

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
        "chat.message": async (_input, output) => {
            for (const part of output.parts) {
                if (part.type !== "text" || part.synthetic) {
                    continue;
                }

                const command = selectedFilePickerCommand(part.text);
                if (command === undefined) {
                    continue;
                }

                const hasAttachedFile = output.parts.some(
                    (candidate) => candidate.type === "file" && candidate.source?.type === "file" && candidate.source.path === command.path,
                );
                if (!hasAttachedFile) {
                    continue;
                }

                part.text = skillTemplate(command.skill).replaceAll("$ARGUMENTS", `@${command.path}`).trim();

                return;
            }
        },
    }),
};

export default plugin;
