import {afterEach, describe, expect, test} from "bun:test";
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from "node:fs";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {setLocalJetBrainsMcpServer} from "./lib.ts";

describe("project-local JetBrains MCP configuration", () => {
    const directories: string[] = [];

    function project(): string {
        const directory = mkdtempSync(join(tmpdir(), "ai-setup-test-"));
        directories.push(directory);
        const result = Bun.spawnSync(["git", "init", "-q", directory]);
        if (result.exitCode !== 0) {
            throw new Error(result.stderr.toString());
        }

        return directory;
    }

    afterEach(() => {
        for (const directory of directories.splice(0)) {
            rmSync(directory, {recursive: true, force: true});
        }
    });

    test("adds the schema when creating a project configuration", () => {
        const directory = project();
        setLocalJetBrainsMcpServer("rider", true, directory);

        const config = JSON.parse(readFileSync(join(directory, "opencode.json"), "utf8"));
        expect(config.$schema).toBe("https://opencode.ai/config.json");
        expect(config.mcp.servers.rider.disabled).toBe(false);
    });

    test("preserves an existing project schema and configuration", () => {
        const directory = project();
        const path = join(directory, "opencode.json");
        writeFileSync(path, JSON.stringify({$schema: "custom-schema", custom: true}));
        setLocalJetBrainsMcpServer("phpstorm", true, directory);

        const config = JSON.parse(readFileSync(path, "utf8"));
        expect(config.$schema).toBe("custom-schema");
        expect(config.custom).toBe(true);
        expect(config.mcp.servers.phpstorm.disabled).toBe(false);
    });
});
