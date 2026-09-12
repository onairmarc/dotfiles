import {readdirSync, statSync} from "node:fs";
import {join} from "node:path";

export type FilePickerOption = {
    label: string;
    path: string;
};

export type FilePickerCommand = {
    command: string;
    description: string;
    emptyMessage: string;
    matchesPath(path: string): boolean;
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
                label: entry.name,
                path: `docs/_planning/${entry.name}/plan.md`,
            }))
            .sort((left, right) => left.label.localeCompare(right.label));
    } catch {
        return [];
    }
}

export const filePickerCommands = [
    {
        command: "plan-review",
        description: "Select a plan to review",
        emptyMessage: "No plan.md files found in docs/_planning.",
        matchesPath: (path) => /^docs\/_planning\/[^/\s]+\/plan\.md$/.test(path),
        options: planOptions,
        skill: "plan-review",
        title: "Select a plan to review",
    },
] as const satisfies readonly FilePickerCommand[];
