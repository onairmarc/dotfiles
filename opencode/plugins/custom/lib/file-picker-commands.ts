import {createComponent} from "@opentui/solid";
import type {TuiPluginApi, TuiPromptRef} from "@opencode-ai/plugin/tui";
import {readdirSync, statSync} from "node:fs";
import {join, resolve} from "node:path";
import {pathToFileURL} from "node:url";

export type FilePickerOption = {
    argument: string;
    filePath: string;
    label: string;
};

export type FilePickerCommand = {
    command: string;
    description: string;
    emptyMessage: string;
    matchesSelection(argument: string, filePath: string): boolean;
    options(root: string): FilePickerOption[];
    skill: string;
    title: string;
};

function planOptions(root: string): FilePickerOption[] {
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
            .map((entry) => ({
                argument: `docs/_planning/${entry.name}/plan.md`,
                filePath: `docs/_planning/${entry.name}/plan.md`,
                label: entry.name,
            }))
            .sort((left, right) => left.label.localeCompare(right.label));
    } catch {
        return [];
    }
}

function subPlanOptions(root: string): FilePickerOption[] {
    const planningDirectory = join(root, "docs", "_planning");

    try {
        return readdirSync(planningDirectory, {withFileTypes: true})
            .filter((entry) => entry.isDirectory())
            .flatMap((entry) => {
                const directory = join(planningDirectory, entry.name);
                try {
                    const subPlan = readdirSync(directory, {withFileTypes: true})
                        .filter((file) => file.isFile() && file.name !== "plan.md" && file.name.endsWith(".md"))
                        .map((file) => file.name)
                        .sort((left, right) => left.localeCompare(right))[0];

                    return subPlan === undefined
                        ? []
                        : [{
                            argument: `docs/_planning/${entry.name}`,
                            filePath: `docs/_planning/${entry.name}/${subPlan}`,
                            label: entry.name,
                        }];
                } catch {
                    return [];
                }
            })
            .sort((left, right) => left.label.localeCompare(right.label));
    } catch {
        return [];
    }
}

function isPlanPath(path: string): boolean {
    return /^docs\/_planning\/[^/\s]+\/plan\.md$/.test(path);
}

function isSubPlanSelection(argument: string, filePath: string): boolean {
    return /^docs\/_planning\/[^/\s]+$/.test(argument)
        && filePath.startsWith(`${argument}/`)
        && filePath !== `${argument}/plan.md`
        && filePath.endsWith(".md");
}

export const filePickerCommands = [
    {
        command: "plan-review",
        description: "Select a plan to review",
        emptyMessage: "No plan.md files found in docs/_planning.",
        matchesSelection: (argument, filePath) => argument === filePath && isPlanPath(argument),
        options: planOptions,
        skill: "plan-review",
        title: "Select a plan to review",
    },
    {
        command: "plan-split",
        description: "Select a plan to split",
        emptyMessage: "No plan.md files found in docs/_planning.",
        matchesSelection: (argument, filePath) => argument === filePath && isPlanPath(argument),
        options: planOptions,
        skill: "plan-split",
        title: "Select a plan to split",
    },
    {
        command: "plan-execute",
        description: "Select sub-plans to execute",
        emptyMessage: "No sub-plan files found in docs/_planning.",
        matchesSelection: isSubPlanSelection,
        options: subPlanOptions,
        skill: "plan-execute",
        title: "Select sub-plans to execute",
    },
] as const satisfies readonly FilePickerCommand[];

function workspaceRoot(worktree: string, directory: string): string {
    return worktree === "/" ? directory : worktree;
}

function setPrompt(prompt: TuiPromptRef, root: string, command: FilePickerCommand, option: FilePickerOption): void {
    const mention = `@${option.argument}`;
    const input = `/${command.command} ${mention} `;
    const start = Bun.stringWidth(`/${command.command} `);

    prompt.set({
        input,
        mode: "normal",
        parts: [
            {
                type: "file",
                mime: "text/plain",
                filename: option.filePath,
                url: pathToFileURL(resolve(root, option.filePath)).href,
                source: {
                    type: "file",
                    path: option.filePath,
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

export function registerFilePickerCommands(api: TuiPluginApi, prompt: () => TuiPromptRef | undefined): void {
    api.keymap.registerLayer({
        commands: filePickerCommands.map((command) => ({
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

                const DialogSelect = api.ui.DialogSelect<FilePickerOption>;

                api.ui.dialog.setSize("medium");
                api.ui.dialog.replace(() => createComponent(DialogSelect, {
                    title: command.title,
                    options: options.map((option) => ({title: option.label, value: option})),
                    onSelect: (option) => {
                        api.ui.dialog.clear();

                        const promptRef = prompt();
                        if (promptRef === undefined) {
                            api.ui.toast({
                                variant: "error",
                                message: "The prompt is not ready.",
                            });

                            return;
                        }

                        setPrompt(promptRef, root, command, option.value);
                    },
                }));
            },
        })),
    });
}

export function filePickerSkill(
    text: string,
    parts: readonly unknown[],
): {argument: string; skill: string} | undefined {
    const filePaths = parts.flatMap((part) => {
        if (typeof part !== "object" || part === null || !("type" in part) || part.type !== "file" || !("source" in part)) {
            return [];
        }

        const {source} = part;
        return typeof source === "object" && source !== null && "type" in source && source.type === "file" && "path" in source
            && typeof source.path === "string"
            ? [source.path]
            : [];
    });

    for (const command of filePickerCommands) {
        const prefix = `/${command.command} @`;
        if (!text.startsWith(prefix)) {
            continue;
        }

        const argument = text.slice(prefix.length).trim();
        if (argument !== "" && filePaths.some((filePath) => command.matchesSelection(argument, filePath))) {
            return {argument, skill: command.skill};
        }
    }
}

export function expandFilePickerCommand(output: {parts: unknown[]}, template: (skill: string) => string): void {
    for (const part of output.parts) {
        if (typeof part !== "object" || part === null || !("type" in part) || part.type !== "text" || !("text" in part)
            || typeof part.text !== "string" || ("synthetic" in part && part.synthetic)) {
            continue;
        }

        const skill = filePickerSkill(part.text, output.parts);
        if (skill === undefined) {
            continue;
        }

        part.text = template(skill.skill).replaceAll("$ARGUMENTS", `@${skill.argument}`).trim();

        return;
    }
}
