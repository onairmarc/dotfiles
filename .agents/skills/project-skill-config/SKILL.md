---
name: project-skill-config
description: Detects user-level skills that do not apply to the current repository and disables them in the repo's .claude/settings.json via skillOverrides. Discovers skills dynamically at invocation, analyzes the repo's tech stack, reasons about relevance, and asks for confirmation before writing.
allowed-tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash(ls *)
  - Bash(find *)
  - Bash(find -L *)
  - AskUserQuestion
model: sonnet
---

# Project Skill Config

Disable user-level skills that don't apply to this repository.

---

## Step 0 — Establish paths

Set these variables for use throughout the skill:

- `$REPO_ROOT` — current working directory (the repository root)
- `$REPO_SETTINGS` — `$REPO_ROOT/.claude/settings.json`
- `$USER_SKILLS_DIR` — `~/.claude/skills`
- `$PLUGIN_CACHE_DIR` — `~/.claude/plugins/cache`

---

## Step 1 — Discover user-level skills

The skills directory may be a symlink to a centrally managed location. Use `find -L` (follows symlinks) rather than
Glob for all skill discovery — Glob does not traverse symlinked directories.

Run in parallel:

1. **Local skills:** Run `find -L ~/.claude/skills -name SKILL.md -maxdepth 2`. For each path returned, read its
   YAML frontmatter to extract `name` and `description`. Record as `{ name, description, source: "local", path }`.

2. **Plugin skills:** Run `find -L ~/.claude/plugins/cache -name SKILL.md -maxdepth 6`. For each path returned,
   read its YAML frontmatter to extract `name` and `description`. Plugin skills are namespaced — extract the plugin
   name from the path (the directory segment immediately after `cache/`) and record as
   `{ name: "<plugin>:<name>", description, source: "plugin:<plugin>", path }`.

Merge both lists into `$ALL_SKILLS`. Deduplicate by name (prefer local over plugin if duplicate names exist).

Skills that are purely meta-infrastructure (e.g., `file-operations`, `update-config`, `keybindings-help`,
`fewer-permission-prompts`, `simplify`, `loop`, `schedule`, `init`, `review`) are **always applicable** to any repo —
exclude them from the candidate list for disabling. Do not disable skills that help AI Agents operate; only disable
skills that target a specific language, framework, or platform that this repo doesn't use.

---

## Step 2 — Analyze the repository's tech stack

Gather signals about what this repo uses. Run all discovery in parallel:

### 2a — Language and runtime signals

Check for these files at `$REPO_ROOT`:

| File                                             | Signal                                  |
|--------------------------------------------------|-----------------------------------------|
| `package.json`                                   | JavaScript / TypeScript (Node.js / Bun) |
| `bun.lock` or `bun.lockb`                        | Bun as package manager                  |
| `package-lock.json`                              | npm as package manager                  |
| `yarn.lock`                                      | yarn as package manager                 |
| `composer.json`                                  | PHP                                     |
| `composer.lock`                                  | PHP (confirmed)                         |
| `*.csproj`, `*.sln`, `*.fsproj`                  | .NET / C#                               |
| `go.mod`                                         | Go                                      |
| `Cargo.toml`                                     | Rust                                    |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python                                  |
| `Gemfile`                                        | Ruby                                    |
| `pom.xml`, `build.gradle`                        | Java / Kotlin                           |

### 2b — Framework signals

- If `composer.json` exists: read it. Check `require` for `laravel/framework` (Laravel), `filament/*` (Filament),
  `livewire/livewire` (Livewire).
- If `package.json` exists: read it. Check `dependencies` and `devDependencies` for `react`, `vue`, `svelte`, `next`,
  `nuxt`, `astro`, `electron`, `avalonia` (rare but possible).
- If `*.csproj` exists: read one. Check for `Avalonia`, `MAUI`, `WPF`, `Blazor`, `ASP.NET` package references.

### 2c — Build and CI signals

Check for `Dockerfile`, `.gitlab-ci.yml`, `.github/workflows/*.yml`. Note build tool names if present.

### 2d — Read AGENTS.md and CLAUDE.md if present

Read `$REPO_ROOT/AGENTS.md`, `$REPO_ROOT/CLAUDE.md` or `$REPO_ROOT/.claude/CLAUDE.md` if either exists. Extract any tech
stack statements (e.g., "This is a Laravel 11 application", "Built with .NET 8 and Avalonia").

Summarize what you found as `$STACK` — a brief description like "PHP / Laravel 11 / Livewire" or ".NET 8 / C# /
Avalonia" or "TypeScript / Next.js / Bun".

---

## Step 3 — Reason about skill relevance

For each skill in `$ALL_SKILLS` (excluding the always-applicable ones from Step 1), reason about whether it applies to
`$STACK`.

A skill is **irrelevant** if:

- Its `description` targets a specific language, framework, or platform that is NOT present in `$STACK`.
- A reasonable developer looking at the skill description and the repo's tech stack would immediately conclude the skill
  has no use in this repo.

A skill is **applicable** (do NOT disable) if:

- Its `description` is general-purpose (planning, docs, review, optimization without a specific language qualifier).
- Its `description` targets a technology that IS present in `$STACK`.
- The skill's scope is ambiguous — when in doubt, leave it enabled.

For each irrelevant skill, record:

- `name` — the skill name as it appears in `skillOverrides`
- `reason` — one short phrase explaining why (e.g., "PHP/Laravel skill, repo is .NET/C#")

---

## Step 4 — Check existing settings

Read `$REPO_SETTINGS` if it exists. Parse the JSON.

Extract the existing `skillOverrides` object (may be absent). Identify:

- Skills already set to `"off"` — note them; the skill will preserve these.
- Skills already set to `"on"` — these have been explicitly enabled; **do not override them** with `"off"`.
- Skills in your irrelevant list that are already `"off"` — mark as "already disabled" in the report.

---

## Step 4b — Reevaluate existing overrides for drift

This step checks whether previously configured overrides are still correct. Two things can change over time that
make a prior override stale: the repo's tech stack (e.g., a PHP dependency added, C# removed) or the skill itself
(e.g., its description was updated and it now covers a technology this repo uses, or it was narrowed and no longer
applies).

For each skill in the existing `skillOverrides`, cross-reference against the current skill description (already
read in Step 1 — use that data, do not re-read) and `$STACK`:

- **Currently `"off"`:** Reason about whether `$STACK` now includes the technology this skill currently targets
  (based on its current description). If yes — either the stack grew or the skill's scope changed to match it —
  flag as a candidate to **re-enable**. Note which changed: stack, skill description, or both.
- **Currently `"on"`:** Reason about whether `$STACK` still includes the technology this skill currently targets.
  If no, flag as a candidate to **disable**. Note which changed: stack, skill description, or both.

Record each candidate as `{ name, current: "on"|"off", recommended: "on"|"off", reason, what_changed }`.

Do NOT flag a skill for change unless the evidence clearly supports it. Ambiguity means no recommendation.

If the skill from `$ALL_SKILLS` has no matching entry (skill was removed from the user's skills dir entirely),
note it separately as a stale override — the skill no longer exists and the override can be cleaned up.

If no existing overrides warrant a change, skip the reevaluation section of the report entirely.

---

## Step 5 — Present proposed changes

Output a report in this format:

```
## Project Skill Config — Analysis

**Repository:** $REPO_ROOT
**Detected stack:** $STACK

### Skills to disable (not in this repo's stack)

| Skill | Reason |
|-------|--------|
| laravel-optimization | PHP/Laravel skill, repo is .NET/C# |
| livewire-upgrade-analysis | Livewire/PHP skill, repo is .NET/C# |
| code-review-php | PHP skill, repo is .NET/C# |
| ... | ... |

### Already disabled (no change needed)

| Skill | Current state |
|-------|---------------|
| ... | already "off" in settings.json |

### Skills kept enabled

All other skills are either general-purpose or apply to this repo's stack.

---

### Reevaluation — existing overrides

(Only shown if Step 4b found candidates for change.)

The following skills are already configured in `skillOverrides` but may need updating:

| Skill | Current | Recommended | What changed | Reason |
|-------|---------|-------------|--------------|--------|
| laravel-optimization | off | on | stack | composer.json now includes laravel/framework |
| code-review-cs | on | off | skill description | skill now targets Blazor only, repo has no Blazor |
| some-old-skill | off | remove | skill deleted | skill no longer exists in ~/.claude/skills |
```

Omit the reevaluation section entirely if Step 4b produced no candidates.

If there are no new skills to disable AND no reevaluation candidates, say so and stop.

---

## Step 6 — Ask for confirmation

Use `AskUserQuestion` with up to two questions in one call — one for new disables (if any), one for reevaluation
changes (if any). Omit a question if its section had no candidates.

**Question 1 — New disables** (only if Step 3 produced new skills to disable):

> **Disable these skills in `$REPO_SETTINGS`?**
>
> This will add the listed skills to `skillOverrides: "off"`. Only affects this repo.

Options:

- **Yes, apply all** — write all proposed disables
- **No, skip** — skip new disables

**Question 2 — Reevaluation changes** (only if Step 4b produced candidates):

> **Apply reevaluation changes to existing overrides?**
>
> These skills already have overrides set, but the current stack or skill definitions suggest they should change.

Options:

- **Yes, apply all** — apply all recommended reevaluation changes
- **No, skip** — leave existing overrides unchanged

Wait for both answers before proceeding.

---

## Step 7 — Write settings.json

If the user chose **No, skip** for both questions: stop. Output "No changes made."

If the user approved either or both:

### 7a — Read or initialize settings

If `$REPO_SETTINGS` exists: read it and parse the JSON. Preserve all existing keys.

If it does not exist: start with `{}`. Ensure the `.claude/` directory exists — if not, note that it will be created.

### 7b — Merge skillOverrides

Take the existing `skillOverrides` object (or `{}`). Apply approved changes in this order:

1. **New disables** (if user approved Question 1): for each skill in the proposed disable list that is NOT already
   `"on"`: set `skillOverrides["<skill-name>"] = "off"`.

2. **Reevaluation changes** (if user approved Question 2): for each candidate from Step 4b:
    - `recommended: "on"` → set `skillOverrides["<skill-name>"] = "on"` (re-enable)
    - `recommended: "off"` → set `skillOverrides["<skill-name>"] = "off"` (disable)
    - `recommended: "remove"` (stale, skill deleted) → remove the key from `skillOverrides` entirely

### 7c — Write

Serialize the full settings object to pretty-printed JSON (2-space indent). Write it to `$REPO_SETTINGS`.

If the file did not exist before: use Write. If it existed: use Edit — replace the entire file content.

### 7d — Confirm

Output:

```
Done. Wrote skillOverrides to $REPO_SETTINGS.

New disables (N): <comma-separated list>
Reevaluation changes (N): <skill: off→on>, <skill: on→off>, <skill: removed (stale)>
```

---

## Constraints

- Never disable skills that are general-purpose or whose applicability is uncertain.
- Never disable skills explicitly set to `"on"` in existing settings.
- Never modify user-level skill files or global `~/.claude/settings.json`.
- One repo, one invocation — this skill operates only on `$REPO_ROOT`.
- If the detected stack is ambiguous (e.g., a mono-repo with multiple languages), err on the side of keeping skills
  enabled. Disable only where the evidence is clear.
