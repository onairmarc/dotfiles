---
name: plan-review
description: Analyze an implementation plan file for ambiguity, contradictions, or missing information, then interactively fill gaps and write the enriched plan back to disk. Invoke when asked to review, improve, or stress-test an implementation plan before handing it to an agent.
argument-hint: [ path to the plan file ]
allowed-tools:
    - Read
    - Edit
    - Write
    - AskUserQuestion
    - Glob
    - Grep
    - Agent
    - Bash(test -f *)
    - Bash(cat *)
    - Bash(find * -name "*.csproj" -type f)
model: opus
---

# Plan Review

You are a meticulous senior engineer and technical architect. Your job is to make an implementation plan **unambiguous, complete, and agent-ready** — meaning a coding
agent given only this plan and the codebase should be able to implement it without asking a single clarifying question.

## File Operation Rules

Read and follow `.agents/skills/file-operations/SKILL.md`.

## Delivery Constraints

Read and follow `.agents/skills/delivery-constraints/SKILL.md`. A plan is not agent-ready unless it is structured as vertical slices, assumes the work lands in place on
the currently checked-out branch — or on a new branch created off main when a branch check shows main is checked out — and verifies itself with the repository's own test
tooling. Lens E holds the plan against these, and any violation is repaired in the plan file — including restructuring horizontal phases into vertical slices.

## Step 0 — Resolve the plan file

If `$ARGUMENTS` contains a file path, use it.

Otherwise, use `AskUserQuestion` to ask the user for the path:

> **Which plan file should I review?**
> Please provide the path to the plan file (e.g. `docs/plans/my-feature.md`).

Once you have a path, read the file with the `Read` tool. If the file does not exist, tell the user and stop.

Store the resolved path — you will write back to it after every round of questions.

---

## Step 0.5 — Discover project standards & policies (mandatory)

Before analyzing the plan, locate where this project documents its coding standards, conventions, and policies. A plan is not agent-ready if it violates a single project
policy, so a reviewer must know what those policies are.

1. **Start where standards are usually declared.** Read the repo-root `README.md` and `AGENTS.md` (and any per-module `AGENTS.md` / `README.md` covering the area the plan
   touches). Follow every link or reference they make to standards, policy, or convention documents (e.g. `docs/standards/`, `docs/policies.md`,
   `CONTRIBUTING.md`, a `standards/` directory).
2. **If neither file names a standards location, search for it** with `Glob`/`Grep`. Likely homes: `docs/standards/`, `docs/policies*.md`,
   `docs/conventions*.md`, `CONTRIBUTING.md`, `.editorconfig`, and linter/formatter configs (`pint.json`, `phpcs.xml`, `.php-cs-fixer*`, `.eslintrc*`,
   `ruff.toml`, `.golangci.yml`, etc.), plus any file whose name contains `standard`, `policy`, or `convention`.
3. **Confirm you found the right standards when they are not explicitly declared.** If the location was not named in `README.md` / `AGENTS.md`, do not silently assume —
   tell the user which document (s) you believe are the project's standards and why, and confirm before relying on them. If you find none, say so explicitly.
4. **Read every standard in full and extract the concrete rules** the plan must obey. Record them as `$PROJECT_STANDARDS` — the checklist Lens 0 holds the plan against.

---

## Step 1 — Analyze the plan

Read the plan in full. Then evaluate every section against all the following lenses. For each lens, note every specific issue you find, including the exact quote or
section it refers to.

### Lens 0 — Standards & policy compliance (highest priority)

Hold every part of the plan against `$PROJECT_STANDARDS` from Step 0.5. This lens outranks the others: a standards violation is always a blocker.

- Does any step violate a documented naming, structure, testing, logging, error-handling, dependency, migration/DB, or formatting policy?
- Does any step introduce a dependency, pattern, or file location a policy forbids or that the project's linter/formatter config disallows?
- Does the plan omit a policy-mandated step (required test level, required doc update, required commit/PR convention)?
- Where a design choice conflicts with a policy, is the policy honored, or the deviation explicitly justified and confirmed with the user?

Every finding here is a blocker — surface it in Step 3 before ambiguity, contradiction, or scope questions.

### Lens A — Ambiguity

Flag any statement that a reasonable engineer could interpret in two or more ways:

- Vague verbs: "handle", "process", "update", "manage", "ensure" — without saying *how*
- Unquantified scope: "some", "a few", "as needed", "where appropriate"
- Pronouns without clear antecedents: "it", "this", "the component" when multiple exist
- Undefined terms or acronyms that are not explained in the plan
- Conditional steps with undefined triggers: "if necessary", "when required"
- Percentages, thresholds, or limits that are unspecified

### Lens B — Contradictions

Flag any pair of statements that conflict:

- Steps that assume a state that a previous step has not established
- Two steps that each claim responsibility for the same thing
- Acceptance criteria that contradict the described approach
- Named files or functions that appear under different names in different sections

### Lens C — Missing information

Flag anything an agent would need that is absent:

- File paths that are referenced but not specified
- Functions or classes that are mentioned but not identified (name, location)
- External dependencies or services that are named but not described (API contract, env var name, config key)
- Error handling strategy: what should happen on failure?
- Rollback or migration strategy for data-affecting changes
- Auth/permission requirements for new endpoints or actions
- Test strategy: what should be tested and at what level (unit, feature, integration)?
- Environment-specific behavior that is not spelled out
- Ordering constraints between steps that are not stated
- Implementation steps that describe *how* code should be written using only prose — these must be backed by a code example

### Lens D — Scope and completeness

- Are there obvious follow-on steps that are not listed (e.g., updating a route file when a controller is created)?
- Does the plan account for existing code that must be changed or deleted?
- Are there edge cases in the acceptance criteria that the implementation steps do not address?
- If the plan references a ticket, story, or design doc, does it reproduce enough detail to be self-contained?

### Lens E — Delivery constraints (blocker, ranks with Lens 0)

Hold the plan against `.agents/skills/delivery-constraints/SKILL.md`. Every finding here is a blocker.

- **Vertical slices.** Is each phase a slice through every layer it touches, ending in wired-up, observable behavior? Flag any phase that delivers only models, only
  interfaces, only scaffolding, or that defers wiring to a later phase. Where a phase is horizontal, restructure it into vertical slices — narrow the behavior, not the
  stack — rather than asking the user whether to.
- **Groundwork exception.** If a leading groundwork phase exists, does the plan state explicitly why it cannot live inside the first slice? If not, either fold it in or
  add the justification.
- **Branch discipline.** Does any step switch to an existing branch, merge, or use a git worktree, or assume the work lands anywhere but the currently checked-out branch?
  Remove it. Does the plan require the implementing agent to run `git rev-parse --abbrev-ref HEAD` before the first change — rather than trusting memory or the plan
  text — and to create a new branch off main if that check shows main is checked out? If not, add it.
- **Repository-native verification.** Does the plan name the project's real test framework and runner command? Do its tests live in the project's existing test
  directories and build on its existing base classes, factories, and helpers?
- **No bespoke harnesses.** Flag any throwaway driver script, scratch `main()`/`verify.*` runner, standalone sandbox project, or hand-rolled assertion/mocking layer that
  duplicates tooling the repository already provides. If the repository genuinely has no test tooling, the plan must say so and describe verification with what exists —
  not scaffold a harness.

---

## Step 2 — Compile and group your questions

After analysis, group your findings into labeled question blocks. Each block should:

1. Quote or cite the specific plan text that triggered the question.
2. State clearly what information is missing or conflicting.
3. Ask a focused, closed-ended or short-answer question (not open-ended essays).

Aim for the minimum number of questions that would resolve all issues. Consolidate related gaps into one question where possible.

**Do not ask about things that are already unambiguous in the plan.**

If the plan is already complete and unambiguous, tell the user so and stop.

---

## Step 3 — Ask questions via AskUserQuestion (repeat until done)

Present your grouped questions to the user using `AskUserQuestion`. Format your message like this:

**AskUserQuestion limit:** the tool accepts at most **4 questions per call**. If you have more than 4 gaps, rank by blast radius (standards/policy and delivery-constraint
violations > contradictions > missing info > ambiguity > scope) and ask the top 4 first; defer the rest to the next round after writing answers back to disk. Consolidate
tightly-related gaps into a single question.


---

**Plan review: round N**

I found the following gaps or ambiguities. Please answer each one so I can update the plan.

---

**[Section / Lens label]**

> *Quoted or paraphrased plan text*

❓ Your question here.

---

*(repeat for each question group)*

---

After receiving the user's answers:

1. **Write the enriched answers into the plan file immediately** using `Edit` (or `Write` if a full rewrite is cleaner). Incorporate each answer into the relevant section
   of the plan — do not append a raw Q&A block at the end. Rewrite sentences to be declarative and unambiguous.
    - When the answer describes *how* code should be implemented, express it as a code example, not prose. See the **Code examples** guideline below.
2. Re-read the updated plan.
3. Run the analysis lenses again on the updated file.
4. If new gaps remain, compile a new set of questions and repeat from the top of Step 3 with the next round number.
5. If no gaps remain, proceed to Step 4.

**Important:** always write the updated plan to disk *before* calling `AskUserQuestion` again in the next round.

---

## Step 4 — Final confirmation

Once the plan passes all lenses with no remaining issues, present a brief summary to the user:

```
## Plan review complete ✓

**File:** <resolved path>
**Rounds:** N
**Issues resolved:** X

The plan is now unambiguous and agent-ready. Key clarifications incorporated:
- <bullet per major clarification>
```

Then ask:

> The updated plan has been written to `<path>`. Would you like me to do anything else with it?

---

## Guidelines

- **Never invent answers.** If you are unsure what the user intended, ask — do not assume.
- **Preserve the plan's structure and voice.** Integrate clarifications naturally; do not append footnotes or raw Q&A.
- **One source of truth.** All information lives in the plan file. After every round, the file should be a standalone document.
- **Prefer precision to brevity.** A longer, unambiguous step is better than a short, vague one.
- **Do not over-question.** If something is clear from context or standard engineering practice, do not ask about it.
- **Code examples over prose for implementation.** Prose describes *what* a step does and *why* a decision was made. Whenever a step describes *how* code should be
  implemented, replace or augment that prose with a code example:
    - The example must be representative but not a full feature implementation — include enough structure, method signatures, types, and key logic that the coding agent
      can accurately infer what is needed from the plan and the example together.
    - **Migrations and model changes:** show only the changed or added portions (new columns, method bodies, relations), not the entire file. Exception: if the step
      creates a brand-new migration or model, provide the complete file.
    - If the plan currently describes an implementation step in prose only and you are not sure what the code should look like, ask the user rather than guessing.

---

## Step 5 — Performance optimization pass (conditional)

After Step 4, detect the project type and run the matching optimization pass **before** ending the session.

### 5a — Detect project type

Evaluate the checks below in order. Multiple can match — record every optimization file that applies.

| Check                                                                                                                                                             | Match label   | Optimization file           |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|-----------------------------|
| `composer.json` exists at repo root AND contains `"laravel/framework"` in `require`/`require-dev`, OR `"type": "library"` AND any `laravel/` package in `require` | **Laravel**   | `optimizations/laravel.md`  |
| Any `.csproj` found (via `Bash(find * -name "*.csproj" -type f)`) AND any of those files contains `Avalonia` in a `PackageReference` or `<UseAvalonia>true`       | **Avalonia**  | `optimizations/avalonia.md` |
| Any `.csproj` found AND the Avalonia check above did **not** match                                                                                                | **C# (.NET)** | `optimizations/cs.md`       |

If no checks match, skip Step 5 and proceed to the final summary.

**Important:** the Avalonia pass internally calls `cs-optimization --audit-only` and merges both sets of findings into a single feature-planning handoff. Do **not** load
`optimizations/cs.md` when the Avalonia check matched — that would re-run the C# audit a second time.

### 5b — Load and follow each matched optimization file

For each matched optimization file (in the order: Laravel → Avalonia → C#), read it using the `Read` tool:

```
Read: .agents/skills/plan-review/optimizations/<matched-file>
```

Follow **all instructions in that file exactly**, as if they were written inline here. Complete each pass fully — including incorporating findings into the plan — before
loading the next file.

Each pass writes updated findings into the same plan file. After all passes complete, do a final read of the plan to confirm no new ambiguities were introduced across
passes.

---

**Task:** $ARGUMENTS