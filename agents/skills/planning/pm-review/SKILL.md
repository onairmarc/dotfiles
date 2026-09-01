---
name: pm-review
description: "Language-agnostic product-manager brain for a repository. Reads a committed per-repo (or per-module) pm-review.md knowledge base — product, personas, domains, invariants, glossary, constraints/non-goals, success metrics, custom lenses, severity calibration, and ship bar — then runs in one of two modes. DISCOVERY mode (default): given a feature idea or problem, applies the PM's deep domain knowledge to surface impacted domains, invariants at risk, affected personas, edge cases, success metrics, risks, and open questions, and writes a discovery brief for the feature-planning skill to consume. REVIEW mode (--review): reviews the current branch's diff against main through the same knowledge base. If no config exists, it bootstraps one interactively first. Use during planning discovery, or when asked for a PM review, product review, or a product manager's take on an idea or change."
argument-hint: "[<feature idea>] [--review] [--lang <ext>] [--module <name>]"
disable-model-invocation: true
allowed-tools:
    - Read
    - Write
    - Grep
    - Glob
    - AskUserQuestion
    - Bash(git branch --show-current)
    - Bash(git rev-parse --git-dir)
    - Bash(git diff main...HEAD *)
    - Bash(git diff main..HEAD *)
    - Bash(git log main..HEAD *)
    - Bash(git diff --stat *)
    - Bash(git diff --name-only *)
    - Bash(gh pr view:*)
    - Bash(gh pr diff:*)
---

# PM Review

Act as the **Product Manager for the specific product this repository (or module) builds** — someone who carries the product's deep domain knowledge in their head. The
product is not hardcoded into this skill; it lives in a committed **`pm-review.md` knowledge base**. This skill's job is to load that knowledge base and then reason with
it in one of two modes.

- **Discovery mode (default)** — the PM's domain expertise applied *before* a plan exists. Given a feature idea or a problem, surface what a seasoned PM for this product
  would know: which domains and invariants it touches, who it affects, the edge cases and risks, the metrics that define success, and the questions that must be answered
  before planning. Produces a **discovery brief** that the `feature-planning` skill consumes.
- **Review mode (`--review`)** — the PM's domain expertise applied *after* code exists. Review the current branch's diff against `main` for business impact, user
  experience, compliance, data safety, and feature completeness — never code style.

Both modes read the **same** knowledge base. This top-level file handles what both modes share — locating and bootstrapping the knowledge base, and selecting the mode —
then hands off to the matching mode file under `resources/`.

Follow these steps precisely.

---

## Step 0 — Detect Mode

Scan `$ARGUMENTS`:

- If it contains `--review` → **MODE = review**. Verify a git repo and a non-`main` branch (`git rev-parse --git-dir`,
  `git branch --show-current`); if not in a repo or sitting on `main`, tell the user there is nothing to review and stop.
- Otherwise → **MODE = discovery**. The remaining non-flag text of `$ARGUMENTS` is the feature idea / problem statement. If it is empty, ask the user for the idea (one or
  two sentences) with `AskUserQuestion` before continuing.

`--lang <ext>` and `--module <name>` may accompany either mode. Strip all flags from `$ARGUMENTS` before using the remainder as the feature idea.

---

## Step 1 — Locate the Knowledge Base

The knowledge base lives at one of two granularities:

- **Single-product repo:** `.agents/pm-review.md` is the knowledge base itself.
- **Large / multi-module repo:** `.agents/pm-review.md` is an **index** pointing to per-module knowledge bases at
  `app_modules/<MODULE>/pm-review.md` (or whatever module path the index lists). Each module file is a full knowledge base for that module.

Resolution order:

1. Read `.agents/pm-review.md`. If it does not exist, go to **Step 2 (Bootstrap)**.
2. Decide whether it is an **index** or a **knowledge base**:
    - It is an **index** if its front matter sets `index: true` (or it only lists module → path mappings and defines no
      `product:` / `custom_lenses:`).
    - Otherwise it is a **knowledge base** — use it directly; skip the bootstrap (Step 2) and go to Step 3.
3. If it is an index, select the module knowledge base:
    - If the user passed `--module <name>`, use that module's path.
    - **Review mode, no `--module`:** run `git diff --name-only main...HEAD`, map the changed paths to module (s) via the index, and use the matching knowledge base (s).
      If changes span multiple modules, review each against its own knowledge base and produce one report section per module. If nothing maps, ask which module to use.
    - **Discovery mode, no `--module`:** infer the target module from the feature idea and the index's domain descriptions; if it is ambiguous, ask the user which module
      the idea belongs to.
    - If a selected module's `pm-review.md` is missing, go to **Step 2 (Bootstrap)** for that module.

Read the resolved knowledge base **in full** before proceeding. Schema is in Step 2.

---

## Step 2 — Bootstrap a Missing Knowledge Base

Never reason about product impact from guessed context. If the needed knowledge base is missing, build it first, interactively.

1. **Gather signal from the repo** to propose real defaults — read `README.md`, `AGENTS.md`, package manifests (`composer.json`, `package.json`, `*.csproj`,
   `pyproject.toml`, `go.mod`, etc.), and top-level domain/model directory names. Trace enough to form a genuine inference; do not fabricate.
2. **Interview the user with `AskUserQuestion`**, pre-filling every option with your inference so the user mostly confirms. Cover, at minimum: the product one-liner,
   primary personas, the business domains that carry product risk, the domain invariants that must never break, the success metrics the product optimizes, known
   constraints / non-goals, the top custom lenses (named question checklists), how `Critical`/`High` severity is calibrated for this product, and the ship bar. Seed the
   glossary from terms you already saw in the repo.
3. **Write the knowledge base** with the `Write` tool:
    - Single-product repo → `.agents/pm-review.md`.
    - Module in a multi-module repo → `app_modules/<MODULE>/pm-review.md`, and ensure `.agents/pm-review.md` exists as an index listing that module → path mapping (create
      or update it).
4. Confirm the written knowledge base back to the user, then continue to Step 3.

### Knowledge base schema

```markdown
---
product: <one-line description of what this product does and for whom>
personas:
  - <persona>: <what they use the product to accomplish, what they fear breaking>
domains:
  - <business domain that carries product risk, e.g. invoicing, dunning, tax>
invariants:
  - <a rule about the product/domain that must never be violated by any change>
constraints:
  - <a hard constraint the product operates under (regulatory, contractual, technical)>
non_goals:
  - <something this product deliberately does NOT do — guards against scope creep>
success_metrics:
  - <a metric/KPI the product optimizes, and the direction that is "good">
severity_calibration:
  critical: <what a Critical finding means for THIS product — the specific outcomes>
  high: <what High means for this product>
  medium: <what Medium means for this product>
  low: <what Low means for this product>
ship_bar:
  - <a condition a change must satisfy to be considered release-ready for this product>
---

# PM Knowledge Base: <product name>

## Glossary

- **<term>** — <what it means in this product's domain>

## Custom Lenses

### <Lens name>

- <product-specific question to ask of every relevant change or idea>
- <another question>
```

The **index** form of `.agents/pm-review.md`:

```markdown
---
index: true
---

# PM Review Index

- `app_modules/<MODULE-A>` — <one-line domain description> → `app_modules/<MODULE-A>/pm-review.md`
- `app_modules/<MODULE-B>` — <one-line domain description> → `app_modules/<MODULE-B>/pm-review.md`
```

The `domains` one-liners in the index let discovery mode route an idea to the right module without reading every file.

---

## Step 3 — Locate the Northstar

The knowledge base captures the product's *domain*; the **northstar** captures the product's *vision* — its in-scope capabilities, explicit out-of-scope list, guiding
principles (each annotated BLOCK or WARN), and sanctioned feature set. Both modes hold their reasoning against it, so load it here once.

Resolve `$PLAN_DIR` and the `$NORTHSTAR` ladder per `~/.config/opencode/skills/planning-commons/paths.md`. Read the resolved northstar in full. If none exists,
`$NORTHSTAR = null`
— the mode files skip every northstar check silently rather than inventing vision constraints.

### Keep the northstar and the knowledge base in sync

The knowledge base (domain) and the northstar (vision) are companions: neither requires the other, but a product is best served when both exist and agree. Handle their
relationship, but **never create or edit the northstar from this skill** — it is produced only by the user explicitly invoking the `northstar` skill.

- **Northstar missing (`$NORTHSTAR = null`) but a knowledge base exists:** once, before handing off, recommend the user run the `northstar` skill to capture the product
  vision so future discovery and review can check scope and guiding principles. State it as a one-line recommendation and continue — do not block, and do not write
  `northstar.md` yourself.
- **Both exist but drift:** if you notice the knowledge base and northstar contradict each other — e.g. a knowledge-base
  `domain` the northstar lists as Out of Scope, a `persona` absent from the northstar's Primary Users, or a `non_goal` that the northstar treats as in-scope — surface the
  specific conflict to the user and recommend reconciling it by re-running the owning skill (`northstar` for vision, `pm-review` bootstrap for the knowledge base). Do not
  silently pick a winner.

---

## Step 4 — Run the Selected Mode

With the knowledge base and (if present) the northstar loaded, hand off to the mode file and follow it exactly:

- **MODE = discovery** → read and follow `resources/discovery.md`.
- **MODE = review** → read and follow `resources/review.md`.

Both mode files assume the knowledge base is already resolved and read, and that `$NORTHSTAR` is set (to a path or `null`). Do not duplicate their lens sets here — each
lives in the mode file so the mode applies it the right way.
