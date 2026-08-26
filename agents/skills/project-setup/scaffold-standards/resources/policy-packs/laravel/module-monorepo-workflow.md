# Module Addition Workflow

A new in-repo module is added through the project's monorepo tooling; the root `composer.json` `replace` block and path repositories are generated, never hand-edited.

Each module is a Composer package symlinked into the root install through a path repository. The root manifest's `replace` block and the merged requirements are derived
data: the tooling computes them from the module manifests. A hand-edit desynchronizes the two, and the failure shows up as an install that resolves differently on CI than
on a developer machine — usually days later, in an unrelated pull request.

**Rules:**

- Create a module by scaffolding its own `composer.json` with the correct PSR-4 autoload and `autoload-dev` mappings, then running the merge/regeneration command.
- Never hand-edit the root `replace` block, the merged `require` entries, or the path-repository list.
- A module's own `composer.json` is the source of truth for its dependencies; add a requirement there, then regenerate.
- A requirement added to a module manifest lands in the **root** `composer.lock` and therefore in the shipped application. Check its license — and its transitive tree —
  before adding it: GPL, AGPL, and SSPL packages are forbidden and halt the work, per [Dependency Licensing](./dependency-licensing.md). `composer licenses` reports the
  resolved tree for the root install; a module's own manifest does not show what it drags in.
- Register the module's service provider through the project's module discovery mechanism, not by appending to a hard-coded list.
- A new module ships with its own `AGENTS.md` and `README.md` and is reachable from the root documentation index — see [Documentation](./documentation.md).
- {{GEN:name the monorepo tool and the exact regeneration command this project uses, and where modules live given {{MODULE_LAYOUT}}. Detect from the repo and confirm.}}

> Severity for plan review: **BLOCK**.
