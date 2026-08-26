# Policy Packs

A **policy pack** is a set of policy documents that are only correct for a specific framework or ecosystem. The core templates under
[`../docs/standards/policies/`](../docs/standards/policies/) are language-agnostic by design: they state the *concern* (validate at the boundary, guard concurrency, keep
config typed) and leave the mechanism to a `{{GEN:…}}` block. A pack states the mechanism directly, because for that framework there is a single right answer worth
writing down.

Each pack directory contains:

- `_pack.md` — the **manifest**. It declares the pack's detection gate and one row per policy: filename, severity, index category, the gate that decides whether that
  individual policy is written, and which core policy the pack file **supersedes** (if any).
- One Markdown file per policy, in the same shape as the core templates: title, one-sentence statement, rationale, `**Rules:**`, `**Example:**`, severity footer.

## How the skill uses a pack

1. During detection, the skill checks each pack's gate (a manifest entry, dependency, or directory signature in the target repo).
2. If the gate matches, it confirms the pack with the user before adopting it — a pack is never applied silently.
3. For each pack policy whose own gate matches, the file is copied into `{{DOCS_PATH}}/policies/` alongside the core policies.
4. Where a pack policy declares `Supersedes`, the named core policy is **not** written — the pack file replaces it, and the index carries the pack file's row in that core
   policy's place. Pack policies with no `Supersedes` value are additive.
5. A core policy that survives may still link to one that was superseded. The skill rewrites those inbound links to point at the replacing pack file; each pack manifest
   lists the ones its own supersessions create.

## Two invariants supersession must hold

A pack states the *mechanism* a rule is enforced by. It does not get to change what the rule costs or what it covers:

- **Severity is inherited.** A pack policy carries the same `BLOCK`/`WARN` severity as the core policy it supersedes. A project does not acquire a stricter rule because
  of the framework it happens to be built on; severity changes only when the user says the project treats that rule differently.
- **Rules are carried forward.** The superseded core file is never written, so any rule it owned that the pack file omits disappears from the project entirely. A pack
  policy must restate every rule of the file it replaces, in the framework's own terms.

Pack files are still templates: they carry `{{PROJECT_NAME}}`, `{{MODULE_LAYOUT}}`, and similar tokens, and are filled by the same Fill and Write phase as everything
else. A written pack file must contain no `{{` token and no `TODO`, exactly like a core policy.

## Adding a pack

Create `<framework>/_pack.md` plus the policy files — the leading underscore keeps the manifest sorted to the top of the directory listing. Keep a policy in a pack
**only** when it cannot be stated agnostically without losing its teeth. If the rule survives being written in terms of "the project's data-access layer" or "the
project's validation surface", it belongs in the core templates with a `{{GEN:…}}` block instead.
