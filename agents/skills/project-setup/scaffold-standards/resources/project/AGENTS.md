# {{MODULE_NAME}} — Agent Guidance

This supplements the [root AGENTS.md]({{ROOT_RELATIVE}}/AGENTS.md). Read that first for the standards index, key commands, and load-bearing rules; this file covers only
what is specific to `{{MODULE_NAME}}`.

## Role

{{GEN:one paragraph on what this module/package/project does and where it sits in the system — authored from the module's manifest and source layout, confirmed with the
user for the modules selected for deep-dive.}}

## Key Files

{{GEN:one bullet per important entry point — the public surface, the hub types, the wiring/registration file. For a skeleton (a module not selected for deep-dive), list
the top-level directories with a one-line role each. For a deep-dive module, list every file an agent must know with an annotation. Do not invent files — read the module
tree.}}

## Invariants / Hot Spots

{{GEN:the module-specific rules that survive a grep — "the cache holds DTO types only", "the X handler is the sole revert path", "boot order must not be reordered". These
come from the deep-dive interview; for a skeleton, leave a single bullet noting the module has no captured invariants yet. Never write a placeholder token.}}
