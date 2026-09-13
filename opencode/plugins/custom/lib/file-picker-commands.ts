import type {TuiPluginApi, TuiPromptRef} from "@opencode-ai/plugin/tui";
import {createComponent} from "@opentui/solid";
import {readdirSync, statSync} from "node:fs";
import {join, resolve} from "node:path";
import {pathToFileURL} from "node:url";

export type FilePickerOption = {
    argument: string;
    filePath: string;
    label: string;
};

export type FilePickerCommand = {
    argumentPlaceholder: "$ARGUMENTS" | "$PLAN_DIR";
    command: string;
    description: string;
    emptyMessage: string;
    excludesPlanningDirectory?(directory: string): boolean;
    matchesSelection(argument: string, filePath: string): boolean;
    options(root: string, excludesPlanningDirectory?: (directory: string) => boolean): FilePickerOption[];
    retainsSelectedFileInPrompt: boolean;
    skill: string;
    title: string;
};

function hasSubPlans(directory: string): boolean {
    try {
        return readdirSync(directory, {withFileTypes: true})
            .some((entry) => entry.isFile() && /^\d{2}-.+\.md$/.test(entry.name));
    } catch {
        return false;
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

function planOptions(root: string, excludesPlanningDirectory: (directory: string) => boolean = () => false): FilePickerOption[] {
    const planningDirectory = join(root, "docs", "_planning");
    try {
        return readdirSync(planningDirectory, {withFileTypes: true})
            .filter((entry) => {
                if (!entry.isDirectory()) {
                    return false;
                }

                if (excludesPlanningDirectory(join(planningDirectory, entry.name))) {
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

function workspaceRoot(worktree: string, directory: string): string {
    return worktree === "/" ? directory : worktree;
}

export const filePickerCommands: readonly FilePickerCommand[] = [
    {
        argumentPlaceholder: "$ARGUMENTS",
        command: "plan-review",
        description: "Select a plan to review",
        emptyMessage: "No plan.md files found in docs/_planning.",
        matchesSelection: (argument, filePath) => argument === filePath && isPlanPath(argument),
        options: planOptions,
        retainsSelectedFileInPrompt: true,
        skill: "plan-review",
        title: "Select a plan to review",
    },
    {
        argumentPlaceholder: "$ARGUMENTS",
        command: "plan-split",
        description: "Select a plan to split",
        emptyMessage: "No plan.md files found in docs/_planning.",
        excludesPlanningDirectory: hasSubPlans,
        matchesSelection: (argument, filePath) => argument === filePath && isPlanPath(argument),
        options: planOptions,
        retainsSelectedFileInPrompt: true,
        skill: "plan-split",
        title: "Select a plan to split",
    },
    {
        argumentPlaceholder: "$PLAN_DIR",
        command: "plan-execute",
        description: "Select sub-plans to execute",
        emptyMessage: "No sub-plan files found in docs/_planning.",
        matchesSelection: isSubPlanSelection,
        options: subPlanOptions,
        retainsSelectedFileInPrompt: false,
        skill: "plan-execute",
        title: "Select sub-plans to execute",
    },
];

export function filePickerSkill(
    text: string,
    parts: readonly unknown[],
): { argument: string; argumentPlaceholder: "$ARGUMENTS" | "$PLAN_DIR"; filePath: string; retainsSelectedFileInPrompt: boolean; skill: string } | undefined {
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
        const filePath = filePaths.find((path) => command.matchesSelection(argument, path));
        if (argument !== "" && filePath !== undefined) {
            return {
                argument,
                argumentPlaceholder: command.argumentPlaceholder,
                filePath,
                retainsSelectedFileInPrompt: command.retainsSelectedFileInPrompt,
                skill: command.skill,
            };
        }
    }
}

export function expandFilePickerCommand(output: { parts: unknown[] }, template: (skill: string) => string): void {
    for (const part of output.parts) {
        if (typeof part !== "object" || part === null || !("type" in part) || part.type !== "text" || !("text" in part)
            || typeof part.text !== "string" || ("synthetic" in part && part.synthetic)) {
            continue;
        }

        const skill = filePickerSkill(part.text, output.parts);
        if (skill === undefined) {
            continue;
        }

        part.text = template(skill.skill).replaceAll(skill.argumentPlaceholder, `@${skill.argument}`).trim();
        if (!skill.retainsSelectedFileInPrompt) {
            const selectedFileIndex = output.parts.findIndex((candidate) => {
                if (typeof candidate !== "object" || candidate === null || !("type" in candidate) || candidate.type !== "file"
                    || !("source" in candidate)) {
                    return false;
                }

                const {source} = candidate;
                return typeof source === "object" && source !== null && "type" in source && source.type === "file" && "path" in source
                    && source.path === skill.filePath;
            });

            if (selectedFileIndex !== -1) {
                output.parts.splice(selectedFileIndex, 1);
            }
        }

        return;
    }
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
                const options = command.options(root, command.excludesPlanningDirectory);
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
