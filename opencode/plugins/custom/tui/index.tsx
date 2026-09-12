/** @jsxImportSource @opentui/solid */
import type {TuiPluginModule, TuiPromptRef} from "@opencode-ai/plugin/tui";
import {readdirSync, statSync} from "node:fs";
import {join, resolve} from "node:path";
import {pathToFileURL} from "node:url";

function planDirectories(root: string): string[] {
    const planningDirectory = join(root, "docs", "_planning");
    try {
        return readdirSync(planningDirectory, {withFileTypes: true})
            .filter((entry) => {
                if (!entry.isDirectory()) {
                    return false;
                }

                try {
                    return statSync(join(planningDirectory, entry.name, "plan.md")).isFile();
                } catch {
                    return false;
                }
            })
            .map((entry) => entry.name)
            .sort((left, right) => left.localeCompare(right));
    } catch {
        return [];
    }
}

function setPlanReviewPrompt(prompt: TuiPromptRef, root: string, directory: string): void {
    const path = `docs/_planning/${directory}/plan.md`;
    const mention = `@${path}`;
    const input = `/plan-review ${mention}`;
    const start = Bun.stringWidth("/plan-review ");

    prompt.set({
        input,
        mode: "normal",
        parts: [
            {
                type: "file",
                mime: "text/markdown",
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

const command = "custom.plan-review";
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
                {
                    name: command,
                    title: "Select a plan to review",
                    category: "Plugin",
                    namespace: "palette",
                    slashName: "plan-review",
                    run() {
                        const root = workspaceRoot(api.state.path.worktree, api.state.path.directory);
                        const plans = planDirectories(root);
                        if (plans.length === 0) {
                            api.ui.toast({
                                variant: "warning",
                                message: "No plan.md files found in docs/_planning.",
                            });

                            return;
                        }

                        const DialogSelect = api.ui.DialogSelect;

                        api.ui.dialog.setSize("medium");
                        api.ui.dialog.replace(() => (
                            <DialogSelect
                            title="Select a plan to review"
                            options={plans.map((directory) => ({title: directory, value: directory}))}
                            onSelect={(option) => {
                                    api.ui.dialog.clear();

                                    if (prompt === undefined) {
                                        api.ui.toast({
                                            variant: "error",
                                            message: "The prompt is not ready.",
                                        });

                                        return;
                                    }

                                    setPlanReviewPrompt(prompt, root, option.value);
                                }}

                            />
                        ));
                    },
                },
            ],
        });
    },
};

export default plugin;
