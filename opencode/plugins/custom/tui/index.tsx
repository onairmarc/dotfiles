/** @jsxImportSource @opentui/solid */
import type {TuiPluginModule, TuiPromptRef} from "@opencode-ai/plugin/tui";
import {resolve} from "node:path";
import {pathToFileURL} from "node:url";
import {filePickerCommands, type FilePickerCommand, type FilePickerOption} from "../lib/file-picker-commands";

function setFilePickerPrompt(prompt: TuiPromptRef, root: string, command: FilePickerCommand, option: FilePickerOption): void {
    const {path} = option;
    const mention = `@${path}`;
    const input = `/${command.command} ${mention} `;
    const start = Bun.stringWidth(`/${command.command} `);

    prompt.set({
        input,
        mode: "normal",
        parts: [
            {
                type: "file",
                mime: "text/plain",
                filename: path,
                url: pathToFileURL(resolve(root, path)).href,
                source: {
                    type: "file",
                    path,
                    text: {
                        start,
                        end: start + Bun.stringWidth(mention),
                        value: mention,
                    },
                },
            },
        ],
    });

    prompt.focus();
}

function workspaceRoot(worktree: string, directory: string): string {
    return worktree === "/" ? directory : worktree;
}

const plugin: TuiPluginModule = {
    id: "custom",
    tui: async (api) => {
        let prompt: TuiPromptRef | undefined;
        const Prompt = api.ui.Prompt;
        const capturePrompt = (value: TuiPromptRef | undefined, ref?: (ref: TuiPromptRef | undefined) => void): void => {
            prompt = value;
            ref?.(value);
        };

        api.slots.register({
            slots: {
                home_prompt(_context, props) {
                    return <Prompt ref={(value) => capturePrompt(value, props.ref)}/>;
                },
                session_prompt(_context, props) {
                    return (
                        <Prompt
                        sessionID={props.session_id}
                        visible={props.visible}
                        disabled={props.disabled}
                        onSubmit={props.on_submit}
                        ref={(value) => capturePrompt(value, props.ref)}
                        />
                    );
                },
            },
        });

        api.keymap.registerLayer({
            commands: [
                ...filePickerCommands.map((command) => ({
                    name: `custom.${command.command}`,
                    title: command.title,
                    category: "Plugin",
                    namespace: "palette" as const,
                    slashName: command.command,
                    run() {
                        const root = workspaceRoot(api.state.path.worktree, api.state.path.directory);
                        const options = command.options(root);
                        if (options.length === 0) {
                            api.ui.toast({
                                variant: "warning",
                                message: command.emptyMessage,
                            });

                            return;
                        }

                        const DialogSelect = api.ui.DialogSelect;

                        api.ui.dialog.setSize("medium");
                        api.ui.dialog.replace(() => (
                            <DialogSelect
                            title={command.title}
                            options={options.map((option) => ({title: option.label, value: option.path}))}
                            onSelect={(option) => {
                                    api.ui.dialog.clear();

                                    if (prompt === undefined) {
                                        api.ui.toast({
                                            variant: "error",
                                            message: "The prompt is not ready.",
                                        });

                                        return;
                                    }

                                    const selected = options.find((candidate) => candidate.path === option.value);
                                    if (selected !== undefined) {
                                        setFilePickerPrompt(prompt, root, command, selected);
                                    }
                                }}

                            />
                        ));
                    },
                })),
            ],
        });
    },
};

export default plugin;
