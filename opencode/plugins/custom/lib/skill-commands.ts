import {readFileSync} from "node:fs";
import {homedir} from "node:os";
import {join} from "node:path";

export function skillTemplate(skill: string): string {
    const configDirectory = process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config");
    const path = join(configDirectory, "opencode", "skills", skill, "SKILL.md");
    return readFileSync(path, "utf8");
}

export const skillCommands = {
    "feature-planning": {
        description: "Create a feature implementation plan.",
        skill: "feature-planning",
    },
    "plan-resync": {
        description: "Reconcile an implementation plan with the current codebase.",
        skill: "plan-resync",
    },
} as const;
