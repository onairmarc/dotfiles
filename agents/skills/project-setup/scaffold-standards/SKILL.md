---
name: scaffold-standards
description: Scaffold the documentation and coding-standards surface for any project, regardless of language. Interactively interviews the project (stack, test/build/static-analysis/format commands, logging sink, module layout), then copies and fills language-agnostic templates into docs/standards/ — a policies.md index plus one file per policy under docs/standards/policies/, each tagged BLOCK or WARN — along with a docs/_planning/ lifecycle README, root AGENTS.md + README.md, and per-module AGENTS.md + README.md for every discovered sub-project (skeletons for all, deep-dive for the top few). Framework-specific rules come from optional policy packs (Laravel ships today) applied only when the stack matches, and a final review-lens pass iterates the whole surface until it is complete, specific, stack-correct, and internally consistent. Use when the user wants to bootstrap a docs directory, set up coding standards, add a standards/policies doc, or establish convention docs for a new or existing repository.
argument-hint: [ target project root (optional) ]
allowed-tools:
    - Read
    - Write
    - Edit
    - Glob
    - Grep
    - Bash
    - AskUserQuestion
---

# Scaffold Standards Skill

Bootstrap the canonical documentation and coding-standards surface for a project in one run. The skill is **language-agnostic**: it ships a set of generic template
documents under its own `resources/` directory, interviews the target project to learn its stack and conventions, then copies the templates into the project with
**every** token resolved to real content.

**Full-automation contract.** When the run finishes, the written files contain **no `{{…}}` tokens and no `TODO`
markers** — nothing is left for the human to fill in later. The skill closes every gap one of three ways, in this order of preference:

1. **Detection** — read it from the repo (manifests, CI, tooling config).
2. **Agent knowledge** — author it from what is idiomatic for the detected language/stack (e.g. the concrete casing rules for the language, the standard test-file
   location, the conventional error model), then confirm the generated block with the user before writing.
3. **Interview** — ask the user via `AskUserQuestion` for anything neither detection nor agent knowledge can settle (project name, tagline, production log sink,
   project-specific rules).

If a section would otherwise be empty, the skill drives a question to fill it — it never emits a placeholder or a TODO.

What it scaffolds (the **full surface**):

| Artifact             | Destination (default)        | Purpose                                                                |
|----------------------|------------------------------|------------------------------------------------------------------------|
| `policies.md`        | `docs/standards/policies.md` | The **index** of policies — one routing table, no policy bodies.       |
| `policies/*.md`      | `docs/standards/policies/`   | One file per policy: statement, rationale, rules, example, severity.   |
| `glossary.md`        | `docs/standards/glossary.md` | Project-specific terms and acronyms.                                   |
| planning `README.md` | `docs/_planning/README.md`   | Plan lifecycle — plans are throwaway scaffolding, docs land elsewhere. |
| root `AGENTS.md`     | `AGENTS.md`                  | AI-agent guidance and reference-file index.                            |
| root `README.md`     | `README.md`                  | Human-facing project overview.                                         |
| module `AGENTS.md`   | `<module>/AGENTS.md`         | Per-sub-project agent guidance — role, key files, invariants.          |
| module `README.md`   | `<module>/README.md`         | Per-sub-project human overview — purpose, structure, run/test.         |

**One policy, one file.** `policies.md` is an index and nothing more: a reader (human or agent) opens only the one or two policy files their change touches instead of
loading the whole rule set. Every policy file carries the same shape — a one-sentence statement, a rationale paragraph that says *why* the rule earns its cost, a
`**Rules:**` list, a worked
`**Example:**` where one helps, and a severity footer.

**A policy bundles its own reference.** Where a rule needs more than a rules list — the full logging contract, the cross-module reach model — that reference lives
*inside* the policy file, below the severity footer and a `---` rule, not in a separate sibling document. `structured-logging.md` carries the write-side contract and the
read-side diagnostic playbook; `module-isolation.md` carries the reach model and the published-surface working list. One file per rule, and the reader who opens it gets
everything that rule needs.

**Severity.** Every policy is tagged `BLOCK` (a plan that violates it must not proceed without an explicit override) or
`WARN` (the planner surfaces the conflict for human review). The tag appears both in the index row and in the policy file's footer line, and the two must agree.

The templates live at `<skill_dir>/resources/`, mirroring the destination layout, plus
`<skill_dir>/resources/policy-packs/` for framework-specific policy sets (see **Policy Set Selection** below). The skill copies from there — it does not generate document
bodies from scratch.

---

## Pre-flight

1. **Resolve the target project root.** Default to the current working directory. If the user passed a path argument, use it. Confirm the resolved root back to the user
   in one line before proceeding.
2. **Resolve the skill directory** — the directory containing this `SKILL.md`. Templates are at `<skill_dir>/resources/`.
3. **Resolve destination paths.** Default `docs/standards/` for standards docs and `docs/_planning/` for the planning directory. (These were chosen as the
   language-agnostic default; do not assume a `docs/developer/` split.)
4. **Detect collisions.** For each artifact the skill would write — including every file under `docs/standards/policies/`
   — check whether the destination file already exists. An existing `policies.md` that carries policy *bodies* rather than an index is a **merge** case, not an overwrite:
   split its sections into per-policy files and rewrite it as the index, preserving the user's wording. Build the list of would-be-overwritten files. If any exist, you
   MUST surface them and ask the user, per artifact, whether to **skip** (leave the existing file untouched), **overwrite**, or **merge** (open the existing file, read
   it, and fold the template's missing sections in without discarding the user's content). Never blind-overwrite an existing doc.
5. **Read the existing docs layout** if the project already has a `docs/` tree — reuse its conventions (sidebar frontmatter style, existing standards filenames) rather
   than fighting them. Treat an existing `CLAUDE.md` as an alias of `AGENTS.md`: if the repo has `CLAUDE.md` but no `AGENTS.md`, read it as the already-answered
   agent-guidance input and confirm with the user whether to keep writing `CLAUDE.md` or migrate to `AGENTS.md` (default: migrate, leaving a one-line `CLAUDE.md`
   pointer).
6. **Discover sub-projects.** Detect the module/package/project units this repo ships so each can get its own `AGENTS.md` + `README.md`. Discovery is stack-shaped:

   | Stack signal                          | Sub-project unit                                                                            |
                  |---------------------------------------|--------------------------------------------------------------------------------------------|
   | `app_modules/*` or `modules/*` dirs   | Each directory with a `composer.json`.                                                      |
   | `*.sln` / multiple `*.csproj`         | Each `*.csproj` (skip `bin/`, `obj/`, and test projects unless the user wants them).        |
   | root `package.json` `workspaces`      | Each workspace, or every `packages/*/package.json`.                                         |
   | multiple `go.mod` / `pyproject.toml`  | Each non-root module manifest.                                                              |
   | single-project repo                   | No sub-projects — the root docs are the only docs.                                          |

   Use `Glob`; fall back to `find -L` via `Bash` when a source directory is symlinked. Record the list as `{ name, path }` pairs, and drop folders that exist but are not
   first-class deliverables (`examples/`, `tools/`, generated proxies) — confirm the final list with the user in the Interview Phase. If discovery finds nothing, skip the
   Per-Project Docs Phase entirely.
7. **Detect the northstar.** If `{{PLANNING_PATH}}/northstar.md` or `<root>/northstar.md` exists, record its path as `{{NORTHSTAR}}`. The review-lens pass checks that no
   policy contradicts it. If none exists, `{{NORTHSTAR}}` is null and the northstar check is skipped.

---

## Detection Phase

Run a fast, shallow scan of the target root to pre-fill interview answers. Do not deep-read source files. Look at:

- **Manifests** — `package.json`, `*.csproj` / `*.sln`, `pom.xml` / `build.gradle`, `go.mod`, `Cargo.toml`,
  `composer.json`, `pyproject.toml` / `requirements.txt`, `Gemfile`. These reveal language, framework, and often the test/build/analysis/format scripts directly (e.g.
  `package.json` `scripts`, `composer.json` `scripts`). A script named `lint` is ambiguous — open it and see whether it runs the analyzer or the style fixer, because the
  two resolve to different tokens with opposite rules for agents.
- **Tooling config** — linter/formatter/static-analysis config files (`.eslintrc*`, `ruff.toml`, `.rubocop.yml`,
  `phpstan.neon`, `.editorconfig`, `rustfmt.toml`, `Directory.Build.props`).
- **CI files** — `.gitlab-ci.yml` — the authoritative source for how the project is actually built and tested.
- **Module layout** — top-level source directory names that indicate how code is grouped (`app_modules/`, `src/`,
  `packages/`, `cmd/`, `internal/`, project folders in a solution).
- **Logging** — dependencies or config that name a logging library or sink (Serilog, Monolog, Sentry, `slog`, `winston`,
  `structlog`).

- **Framework signature** — the dependency or directory pattern each policy pack gates on (see the pack manifests under
  `<skill_dir>/resources/policy-packs/*/_pack.md`). Check for the framework's **component** packages too, not just its meta-package: a library or in-repo package pulls in
  the pieces it needs (`illuminate/support` rather than `laravel/framework`) and would otherwise miss a pack that applies to it.
- **Concern signatures** — evidence that a *conditional* policy applies: a migrations directory, a queue/worker dependency, a cache/lock API (`Cache`, Redis), a frontend
  build config, an authorization/permission package.

Record what you detected; every detected value becomes a **pre-filled default** in the interview, not a silent assumption.

---

## Policy Set Selection

The set of policy files a project gets is not fixed. Decide it in three tiers, in this order.

### Tier 1 — core policies (always written)

Copied from `<skill_dir>/resources/docs/standards/policies/` for every project:

- `code-style`
- `code-comments`
- `static-analysis`
- `formatter-authority`
- `naming-and-casing`
- `simplicity-first`
- `no-magic-values`
- `strong-typing`
- `data-transfer-objects`
- `configuration-access`
- `typed-config-objects`
- `structured-logging`
- `error-handling`
- `input-validation`
- `testing`
- `test-suite-performance`
- `test-data-factories`
- `test-helper-classes`
- `documentation`
- `dependencies`
- `dependency-licensing`
- `version-control`

### Tier 2 — conditional policies (written only when the concern exists)

Same directory; each has a gate. Detect the gate, then confirm with the user — a policy for a concern the project does not have is noise, and a missing policy for a
concern it does have is a gap.

| Policy                               | Gate                                                                                                                                                                 |
|--------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `data-access.md`                     | The project reads or writes a database or other persistent store.                                                                                                    |
| `schema-migrations.md`               | The project owns a schema and has migration tooling.                                                                                                                 |
| `module-isolation.md`                | `{{MODULE_LAYOUT}}` has more than one module/package.                                                                                                                |
| `background-jobs.md`                 | The project dispatches queued or scheduled background work.                                                                                                          |
| `concurrency-guards.md`              | The project has concurrent writers to the same entity (workers, replicas).                                                                                           |
| `cache-key-naming.md`                | The project uses a cache or distributed lock (`Cache`, Redis, or equivalent). Forced on when `concurrency-guards.md` (or a pack file that supersedes it) is written. |
| `immutable-value-types.md`           | `{{PRIMARY_LANGUAGE}}` has a mutable/immutable split worth mandating.                                                                                                |
| `frontend-component-testing.md`      | The project ships a UI component layer with a component test runner.                                                                                                 |
| `type-sealing.md`                    | `{{PRIMARY_LANGUAGE}}` has sealing keywords AND the user wants the default fixed.                                                                                    |
| `authorization-identifier-naming.md` | The project has named permissions/roles as identifiers.                                                                                                              |

### Tier 3 — framework policy packs

Packs live at `<skill_dir>/resources/policy-packs/<framework>/`, each with an `_pack.md` manifest. Read
[`resources/policy-packs/README.md`](resources/policy-packs/README.md) before using one. The flow:

1. Check each pack's gate against the detected stack. Today the skill ships a **`laravel`** pack (gate: `composer.json` requires `laravel/framework` **or** any
   `illuminate/*` package — the second half catches Laravel packages, which depend on the components rather than on the framework).
2. If a pack gates in, **confirm it with the user via `AskUserQuestion` before adopting it.** A pack is never applied silently, and the user may decline it and keep the
   agnostic core policies instead.
3. For each row in the manifest, evaluate that policy's own gate. Copy in only the ones that match.
4. Honor the manifest's `Supersedes` column: when a pack policy is written, the core policy it supersedes is **not**
   written — the pack file takes its place, including its row in the index. When a pack policy is *skipped* by its own gate, write the core policy it would have
   superseded instead, because the concern still applies even though the framework mechanism does not.
5. Respect the manifest's cross-file dependency notes — a pack policy that links to a Tier 2 policy forces that Tier 2 policy to be written, or the link must be rewritten
   to drop the reference. Also rewrite **inbound** links: a surviving core policy that links to a superseded one is repointed at the pack file that replaced it, per the
   manifest's inbound-link list.
6. Supersession swaps a mechanism, not a rule's weight or its scope. A pack policy must carry the **same severity** as the core policy it supersedes, and must restate
   **every rule** that core policy owned — the core file is never written, so an omitted rule is lost from the project. If the manifest violates either invariant, fix the
   manifest rather than writing the mismatch.

**Where a rule belongs.** Keep a policy agnostic whenever the rule survives being stated in terms of "the project's data-access layer" or "the project's validation
surface" — then let a `{{GEN:…}}` block name the mechanism. Move it into a pack only when stating it agnostically would blunt it. Anything narrower still — a rule true
only of *this* repository, its in-house packages, or one module — is not a template at all: it goes through the interview into a project-specific policy file authored on
the spot, in the same shape as the templates, with its own index row.

---

## Interview Phase

The templates carry two kinds of token, both of which MUST be gone from the output:

- **`{{VALUE}}` tokens** — a single discrete value (project name, a command, a library). Resolve by detection first, then by asking.
- **`{{GEN:…}}` tokens** — a whole block of prose/table content the agent must **author** from the detected stack plus interview answers (for example
  `{{GEN:concrete casing rules for the language}}`). These are where the language-specific substance is written. Author the block, then confirm it with the user before it
  is written to disk.

Interview the user with `AskUserQuestion` to settle everything detection and agent knowledge cannot. Lead every option with what you detected so the user usually just
confirms. Batch into a small number of questions (the tool allows up to 4 per call). Resolve at least the following `{{VALUE}}` tokens:

| Value token                   | Resolve by                                                                                                                                                                                                                                |
|-------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `{{PROJECT_NAME}}`            | Repo directory name → confirm with user.                                                                                                                                                                                                  |
| `{{PROJECT_TAGLINE}}`         | Ask (one-sentence description of the project).                                                                                                                                                                                            |
| `{{PRIMARY_LANGUAGE}}`        | Detect from manifests → confirm.                                                                                                                                                                                                          |
| `{{STACK}}`                   | Detect runtime / framework(s) → confirm.                                                                                                                                                                                                  |
| `{{TEST_FRAMEWORK}}`          | Detect → confirm.                                                                                                                                                                                                                         |
| `{{TEST_COMMAND}}`            | Detect from scripts / CI → confirm (never guess a command; ask if absent).                                                                                                                                                                |
| `{{BUILD_COMMAND}}`           | Detect → confirm (ask if absent).                                                                                                                                                                                                         |
| `{{STATIC_ANALYSIS_COMMAND}}` | Detect → confirm (ask if absent). The **analyzer** run — PHPStan/Psalm, `tsc --noEmit`, mypy, `go vet`. Reports defects only a human or agent can fix; never rewrites files. Agents are **required** to run this.                         |
| `{{FORMAT_COMMAND}}`          | Detect the **formatter / style linter** → confirm (ask if absent). Pint, Biome, Prettier, php-cs-fixer, an ESLint autofix run, plus any codemod or import sorter. Covers every mode of those tools. Agents are **forbidden** to run this. |
| `{{STATIC_ANALYSIS_TOOL}}`    | Detect from tooling config → confirm.                                                                                                                                                                                                     |
| `{{LOG_LIBRARY}}`             | Detect from dependencies → confirm.                                                                                                                                                                                                       |
| `{{LOG_SINK}}`                | Ask (production log aggregation sink).                                                                                                                                                                                                    |
| `{{MODULE_LAYOUT}}`           | Detect top-level layout → confirm and describe.                                                                                                                                                                                           |
| `{{DEFAULT_BRANCH}}`          | Detect via `git symbolic-ref` → default `main`.                                                                                                                                                                                           |
| `{{DOCS_PATH}}`               | Default `docs/standards` (confirmed in Pre-flight).                                                                                                                                                                                       |
| `{{PLANNING_PATH}}`           | Default `docs/_planning` (confirmed in Pre-flight).                                                                                                                                                                                       |

Resolve `{{STATIC_ANALYSIS_COMMAND}}` and `{{FORMAT_COMMAND}}` to different tools and never emit a combined "lint" command. When a single `lint` script in
`package.json`/`composer.json` runs both, split it: the analyzer half becomes `{{STATIC_ANALYSIS_COMMAND}}`, the style half becomes `{{FORMAT_COMMAND}}`, and the written
docs name both.

For every `{{GEN:…}}` block, author concrete content from the resolved stack. Where the correct content is genuinely a project decision (e.g. "does this project allow raw
SQL?", "what are the project-specific policies?"), ask the user rather than inventing a rule. The goal is that a reader of the finished doc sees real, project-true
content in every section — never a placeholder and never a generic "fill this in later" note.

---

## Fill and Write Phase

Write the policy files **first**, then the index, then the remaining artifacts — the index's rows are determined by what actually landed in `policies/`.

The `<skill_dir>/resources/project/` templates are **not** copied here — they are applied once per sub-project in the Per-Project Docs Phase below. For every other
template — the policy files selected in **Policy Set Selection**, then each remaining template under `<skill_dir>/resources/`, in the order listed in the Pre-flight
table:

1. **Read the template** with the Read tool.
2. **Resolve every `{{VALUE}}` token** to its detected/confirmed value.
3. **Expand every `{{GEN:…}}` token** into the block of content you authored for it. If a `{{GEN:…}}` block turns out to be genuinely not applicable to this project,
   remove the whole section cleanly (heading included) rather than leaving a stub — do not write "N/A" and do not leave the token.
4. **Rewrite internal cross-links** so every `docs/standards/*` and `docs/_planning/*` link resolves against the chosen
   `{{DOCS_PATH}}` / `{{PLANNING_PATH}}`. Policy files link to each other as `./<name>.md` and to sibling standards docs as `../<name>.md` — verify both forms after any
   path change.
5. **Honor the per-file collision decision** from Pre-flight (skip / overwrite / merge). Only the Write and Edit tools write files — never shell redirection.

**Policy files carry a severity.** Every policy file ends with `> Severity for plan review: **BLOCK**.` or `**WARN**.`
The templates ship a default; change it only when the user says the project treats that rule differently, and change the index row to match in the same edit.

**One rule is not negotiable per project.** `formatter-authority.md` ships the fixed stance that **CI owns formatting and style linting entirely, and a coding agent never
runs those tools in any mode, `--check` and `--dry-run` included**. Do not interview the user about who runs the formatter, do not soften the rule, do not add a read-only
carve-out for it, and do not drop it below BLOCK. Resolve `{{FORMAT_COMMAND}}` to this project's real formatter/style-linter command and leave the stance as written. The
mirror rule also holds: `static-analysis.md` **requires** the agent to run `{{STATIC_ANALYSIS_COMMAND}}`, and that must not be softened either. Keep the two straight —
conflating them is the failure mode this pair of policies exists to prevent.

**Project-specific policies.** Rules unique to this repository come out of the interview, not a template. Author each as its own file in `policies/` in the same shape
(statement, rationale, rules, example, severity) and give it an index row. Do not append them as sections inside another policy file.

**Before writing each file, scan it for any remaining `{{` or the string `TODO`.** If either is present, the file is not ready — resolve it (loop back to
detection/knowledge/interview) before writing. A written file with a leftover token is a skill failure.

Create the destination directories as needed (via the Write tool writing into them; do not `mkdir` files that the tool will create).

---

## Wire-up Phase

After the files land, make them cohere:

1. **Policy index accuracy.** `policies.md` carries exactly one row per policy file that was written — no row for a policy that was skipped or superseded, no policy file
   missing from the index. Each row's severity matches the footer inside the file it links to. Remove any category section left with no rows; add a section for any pack
   category (e.g. authorization, frontend) that received a policy.
2. **Policy-to-policy links.** Open every written policy file and confirm each `./<name>.md` link points at a file that was actually written. A link to a skipped policy
   is either fixed by writing that policy or by removing the reference — never left dangling.
3. **AGENTS.md reference index.** Ensure the root `AGENTS.md` "Reference Files" table links to every standards doc that was actually written (skip rows for artifacts the
   user chose to skip), and that it routes to `policies.md` as the policy index rather than listing individual policies.
4. **README.md "Further Documentation".** Ensure the root `README.md` points at `AGENTS.md` and the standards directory.
5. **Planning lifecycle pointer.** Ensure `AGENTS.md` carries the "before touching a plan, read the planning README"
   pointer, matching the planning `README.md` that was written.
6. **Cross-doc links and anchors.** `policies.md` should link to `glossary.md`. Verify the in-file anchors resolve in the two policies that bundle a full reference:
   `structured-logging.md` (policy → write-side contract → read-side playbook) and `module-isolation.md` (policy → reach model).

---

## Per-Project Docs Phase

If Pre-flight discovered sub-projects, give each its own `AGENTS.md` + `README.md` so an agent working inside a module reads module-scoped guidance without loading the
whole repo. Skip this phase entirely for a single-project repo. The templates are at `<skill_dir>/resources/project/AGENTS.md` and
`<skill_dir>/resources/project/README.md`; they use the same `{{VALUE}}` / `{{GEN:…}}` machinery and the same full-automation contract — **no `{{` token and no `TODO`
survives** in a written file.

**Skeletons for every module first.** For each discovered sub-project, copy both templates into `<module>/`, resolving:

- `{{MODULE_NAME}}` — the module's name.
- `{{ROOT_RELATIVE}}` — the relative path from the module directory back to the repo root (e.g. `../..` for `app_modules/billing/`), so the "supplements the root
  AGENTS.md" link resolves.
- `{{GEN:…}}` blocks — author from the module's manifest and top-level tree. A skeleton lists the module's top-level directories with a one-line role each and states
  plainly when no invariants have been captured yet; it never leaves a placeholder. Honor the per-file collision decision from Pre-flight (skip / overwrite / merge).

A skeleton with correct headers, a resolved role, working cross-links, and an honest "no invariants captured yet" line is a real deliverable — better than an invented
body that drifts from the code.

**Deep-dive the top few.** After the skeletons land, ask the user via `AskUserQuestion` which 3–5 modules to fully populate now (recommend the ones they emphasized in the
Interview Phase). For each selected module, run one consolidated `AskUserQuestion`:

> **`<module>` deep-dive.** (1) The 5–10 most important files or directories and each one's role. (2) Any invariants, gotchas, or boot-order constraints an agent must
> respect. (3) Run/test commands specific to this module, if they differ from the root commands.

Then Edit that module's `AGENTS.md` + `README.md` to fold the answers into the Key Files, Invariants / Hot Spots, Key Components, and Running / Testing sections. Modules
not selected stay as skeletons for a later session or human authoring.

**Wire the modules into the root.** Add one row per module to the root `AGENTS.md` "Reference Files" table (domain → the module's `AGENTS.md`), and surface the modules in
the root `README.md` Architecture section. Every `{{ROOT_RELATIVE}}/AGENTS.md` link and every root-to-module link must resolve.

---

## Review-Lens Phase

After every file is written and wired, re-read the whole generated surface and pass it through five lenses. This is an **iterate-until-clean** loop, not a one-shot
checklist — each round drives concrete edits, then re-runs every lens.

- **Lens A — Completeness.** Every discovered module has paired `AGENTS.md` + `README.md` (skeleton at minimum). Every policy that landed has a `policies.md` index row
  and, where load-bearing, an `AGENTS.md` rules bullet. Every sibling standards artifact promised in the templates exists and is non-empty.
- **Lens B — Specificity.** Every policy carries a concrete `BLOCK`/`WARN` footer, and its statement is true of *this* project and false of some other project of the same
  stack. Generic platitudes are tightened or removed.
- **Lens C — Stack-fit.** Every invoked command, tool name, file extension, and config path matches the detected stack — no `.csproj` in a Laravel doc, no `composer.json`
  in a .NET doc, no combined "lint" command where the analyzer and the formatter must stay split.
- **Lens D — Agent-readiness.** An agent can open the root `AGENTS.md` cold and follow the Reference Files table to the right sub-doc or module for any domain. Every
  cross-link resolves to a file that was actually written.
- **Lens E — Consistency.** Project and module names are spelled identically across every file; docs/planning paths agree everywhere; anchor links point at headings that
  exist. If `{{NORTHSTAR}}` is set, no policy contradicts a northstar principle — flag any that does.

When a lens surfaces issues, present them via `AskUserQuestion` (at most 4 questions per call, ranked BLOCK-equivalents → stack-fit errors → ambiguity → completeness,
tightly-related issues consolidated). Write the fixes to disk **before** the next question, re-read the changed files, and re-run all five lenses. Repeat until a full
pass finds nothing. Issues the agent can resolve itself (a broken link, a missing index row, a misspelled module name) are fixed directly without a question.

---

## Deliverable

Report, in a short summary (not by dumping file contents):

- The resolved project root, `{{DOCS_PATH}}`, and `{{PLANNING_PATH}}`.
- The policy set: how many policies were written, which conditional policies gated **in** and which gated **out** (and why), which pack was adopted (or that none
  applied), and which core policies a pack superseded.
- The sub-projects discovered: how many got skeleton `AGENTS.md` + `README.md` and which were deep-dived (or that the repo is single-project and the phase was skipped).
- The list of files written, skipped, or merged.
- How many review-lens rounds ran and that the final pass was clean.
- Confirmation that the written files are complete — no tokens, no TODO markers, every section carries real project-specific content.

---

## Self-Check Before Finalizing

- [ ] Target root, docs path, and planning path were confirmed with the user before any file was written.
- [ ] Every existing destination file was surfaced and its skip/overwrite/merge decision honored — nothing was blind-overwritten.
- [ ] **No written file contains a `{{` token or the string `TODO`** — every value was detected/asked and every
  `{{GEN:…}}` block was authored into real content (or its section was removed as not applicable). Nothing was left for the human to complete, and no value was
  fabricated.
- [ ] Every `{{GEN:…}}` block that the agent authored from stack knowledge (not from an explicit user answer) was confirmed with the user before it was written.
- [ ] Every Tier 2 conditional policy was decided explicitly — gated in or out against its stated gate, with the decision confirmed by the user rather than assumed.
- [ ] Any policy pack was confirmed with the user before adoption, its `Supersedes` column was honored (superseded core policies not written, skipped pack policies
  replaced by their core counterpart), and its cross-file dependency notes were satisfied — including the inbound links from surviving core policies into superseded ones.
- [ ] Every supersession preserved severity and rule coverage: the pack file's footer severity equals the superseded core policy's, and no rule the core policy owned was
  dropped on the way into the pack file.
- [ ] `policies.md` has exactly one row per written policy file, each severity matching that file's footer, and no row pointing at a file that was not written. No Tier 2
  policy is pre-listed in the template, so every conditional policy that gated in has a row authored for it.
- [ ] `{{FORMAT_COMMAND}}` and `{{STATIC_ANALYSIS_COMMAND}}` resolved to **different tools** — the style rewriter and the defect analyzer — with no combined "lint"
  command emitted anywhere. `formatter-authority.md` still bars the first at BLOCK in every mode, and `static-analysis.md` still requires the second.
- [ ] All internal cross-links resolve against the chosen docs/planning paths — including every `./<name>.md` link between policy files.
- [ ] The `AGENTS.md` reference index lists exactly the standards docs that were written and routes to the policy index, not to individual policy files.
- [ ] Every discovered sub-project has paired `AGENTS.md` + `README.md` (skeleton at minimum), each `{{ROOT_RELATIVE}}` link resolves, and every module is wired into the
  root `AGENTS.md` Reference Files table and root `README.md` Architecture section. (Skipped only for a genuinely single-project repo.)
- [ ] The five review lenses ran as an iterate-until-clean loop, every surfaced issue was fixed on disk before the next question, and a full final pass found nothing — no
  broken cross-link, no name-spelling drift, and no policy contradicting `{{NORTHSTAR}}` when one exists.
- [ ] No file was written via shell redirection — only Write/Edit.
- [ ] The summary reports written/skipped/merged files and confirms zero remaining tokens/TODOs.