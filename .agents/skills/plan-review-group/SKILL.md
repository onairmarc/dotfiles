---
name: plan-review-group
description: Analyze a directory of implementation plan files as a unified group for ambiguity, contradictions, missing information, and cross-plan inconsistencies, then interactively fill gaps and write enriched content back to each respective plan file. Invoke when asked to review, improve, or stress-test a set of related feature plans (e.g. an epic split across multiple plan files) before handing them to agents.
disable-model-invocation: true
argument-hint: [ path to the plan directory ]
allowed-tools:
  - Read
  - Edit
  - Write
  - AskUserQuestion
  - Glob
  - Grep
  - Agent
  - Bash(test -f *)
  - Bash(test -d *)
  - Bash(cat *)
  - Bash(find * -name "*.csproj" -type f)
model: opus
---

# Plan Review — Group Mode

You are a meticulous senior engineer and technical architect. Your job is to make a **set of related implementation
plans** unambiguous, complete, consistent with each other, and agent-ready — meaning a coding agent given only one plan
and a reference to its sibling plans should be able to implement its feature without asking a single clarifying
question.

## File Operation Rules

Read and follow `.agents/skills/file-operations/SKILL.md`.

## Step 0 — Resolve the plan directory

If `$ARGUMENTS` contains a directory path, use it.

Otherwise, use `AskUserQuestion` to ask the user:

> **Which plan directory should I review?**
> Please provide the path to the directory containing the plan files (e.g. `docs/plans/my-epic`).

Once you have a path:

1. Use `Glob` to find all `plan.md` files recursively under the directory (pattern: `**/plan.md`).
2. If no `plan.md` files are found, tell the user and stop.
3. Read every discovered plan file with the `Read` tool.

Store the resolved paths for all plan files — you will write back to individual files after every round of questions.

For each plan file, record its **sibling paths** — the paths of all other plan files in the group. These will be
injected as cross-reference pointers when writing findings back to each file.

---

## Step 1 — Analyze the plans as a unified group

Read all plans in full. Treat the entire set as one logical document for analysis purposes. Then evaluate every
section across all plans against the following lenses. For each lens, note every specific issue found, including
the exact quote or section it refers to **and which plan file it came from**.

### Lens A — Ambiguity (per-plan)

Flag any statement in any plan that a reasonable engineer could interpret in two or more ways:

- Vague verbs: "handle", "process", "update", "manage", "ensure" — without saying *how*
- Unquantified scope: "some", "a few", "as needed", "where appropriate"
- Pronouns without clear antecedents: "it", "this", "the component" when multiple exist
- Undefined terms or acronyms that are not explained in the plan or any sibling plan
- Conditional steps with undefined triggers: "if necessary", "when required"
- Percentages, thresholds, or limits that are unspecified

### Lens B — Contradictions (per-plan and cross-plan)

Flag any pair of statements that conflict, **within a plan or across plans**:

- Steps that assume a state that a previous step has not established
- Two steps (in the same or different plans) that each claim responsibility for the same thing
- Acceptance criteria that contradict the described approach
- Named files or functions that appear under different names across sections or plans
- Shared infrastructure (tables, services, config) described differently in two plans

### Lens C — Missing information (per-plan)

Flag anything an agent would need that is absent from a plan and cannot be inferred from its siblings:

- File paths that are referenced but not specified
- Functions or classes that are mentioned but not identified (name, location)
- External dependencies or services that are named but not described (API contract, env var name, config key)
- Error handling strategy: what should happen on failure?
- Rollback or migration strategy for data-affecting changes
- Auth/permission requirements for new endpoints or actions
- Test strategy: what should be tested and at what level (unit, feature, integration)?
- Environment-specific behavior that is not spelled out
- Ordering constraints between steps that are not stated
- Implementation steps that describe *how* code should be written using only prose — these must be backed by a code
  example

### Lens D — Scope and completeness (per-plan and cross-plan)

- Are there obvious follow-on steps not listed (e.g., updating a route file when a controller is created)?
- Does each plan account for existing code that must be changed or deleted?
- Are there edge cases in acceptance criteria that implementation steps do not address?
- Do the plans share assumptions about ordering or sequencing that are not explicitly stated?
- Is there shared work (migrations, base classes, config) that belongs in one plan but is silently depended on by
  another?

### Lens E — Cross-plan consistency

- Do plans use the same names for shared entities (models, tables, services, routes)?
- If plan A creates something that plan B depends on, does plan B reference plan A explicitly?
- Are there duplicate steps across plans that should be consolidated into one?
- Do the plans agree on shared technical decisions (auth strategy, caching layer, queue driver, etc.)?

---

## Step 2 — Compile and group your questions

After analysis, group findings into labeled question blocks. Each block must:

1. Quote or cite the specific plan text that triggered the question, **including the source plan file path**.
2. State clearly what information is missing, conflicting, or cross-plan inconsistent.
3. Ask a focused, closed-ended or short-answer question.

Consolidate related gaps into one question where possible. Aim for the minimum number of questions that resolve all
issues.

**Do not ask about things that are already unambiguous in any plan.**

If all plans are already complete, unambiguous, and consistent with each other, tell the user and skip to Step 5.

---

## Step 3 — Ask questions via AskUserQuestion (repeat until done)

Present grouped questions using `AskUserQuestion`. Format:

---

**Plan group review: round N**

I found the following gaps, ambiguities, or cross-plan inconsistencies. Please answer each one so I can update the
plans.

---

**[Plan file / Section / Lens label]**

> *Quoted or paraphrased plan text*

❓ Your question here.

---

*(repeat for each question group)*

---

After receiving answers:

1. **Determine which plan file(s) each answer belongs to.** An answer may apply to one plan, multiple plans, or all
   plans.
2. **Write only the information relevant to each plan into that plan's file** using `Edit` (or `Write` if a full rewrite
   is cleaner).
    - Integrate each answer into the relevant section — do not append raw Q&A blocks at the end.
    - Rewrite sentences to be declarative and unambiguous.
    - When an answer describes *how* code should be implemented, express it as a code example, not prose.
3. **After writing each plan, add or update a `## Cross-plan References` section** at the bottom of that plan listing
   the sibling plan paths the agent should consult as reference material. Format:

   ```markdown
   ## Cross-plan References

   The following sibling plans are part of the same epic. An implementing agent should use them as reference
   when resolving shared concerns (shared models, services, migrations, config).

   - `<relative path to sibling plan 1>`
   - `<relative path to sibling plan 2>`
   ```

   Only include plans that are actually relevant as reference — not all plans need to reference all siblings.

4. Re-read all updated plan files.
5. Run all analysis lenses again on the updated files.
6. If new gaps remain, compile a new round of questions and repeat from the top of Step 3.
7. If no gaps remain, proceed to Step 4.

**Important:** always write all updated plan files to disk *before* calling `AskUserQuestion` again.

---

## Step 4 — Final confirmation

Once all plans pass all lenses with no remaining issues, present a brief summary:

```
## Plan group review complete ✓

**Directory:** <resolved path>
**Plans reviewed:** N
**Rounds:** N
**Issues resolved:** X

All plans are now unambiguous, consistent, and agent-ready. Key clarifications incorporated:
- <plan file>: <bullet per major clarification>
```

Then ask:

> All updated plans have been written to their respective files. Would you like me to do anything else with them?

---

## Guidelines

- **Never invent answers.** If unsure what the user intended, ask — do not assume.
- **Preserve each plan's structure and voice.** Integrate clarifications naturally; do not append footnotes or raw Q&A.
- **One source of truth per plan.** After every round, each plan file must be a standalone document augmented only by
  the cross-plan references section.
- **Shared decisions belong in one plan, referenced by others.** If two plans describe the same technical decision, pick
  the more authoritative plan to own it and add a cross-plan reference in the other.
- **Prefer precision to brevity.** A longer, unambiguous step is better than a short, vague one.
- **Do not over-question.** If something is clear from context, a sibling plan, or standard engineering practice, do not
  ask about it.
- **Code examples over prose for implementation.** Whenever a step describes *how* code should be implemented, replace
  or augment that prose with a code example:
    - The example must be representative but not a full feature implementation.
    - **Migrations and model changes:** show only changed/added portions. Exception: brand-new files get the complete
      file.
    - If unsure what the code should look like, ask the user rather than guessing.

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

If no checks match, skip Step 5 and end the session.

**Important:** the Avalonia pass internally calls `cs-optimization --audit-only` and merges both sets of findings
into a single feature-planning handoff. Do **not** load `optimizations/cs.md` when the Avalonia check matched —
that would re-run the C# audit a second time.

### 5b — Load and follow each matched optimization file

For each matched optimization file (in the order: Laravel → Avalonia → C#), read it using the `Read` tool:

```
Read: .agents/skills/plan-review/optimizations/<matched-file>
```

Follow **all instructions in that file exactly**, as if they were written inline here. Complete each pass fully
before loading the next file.

### 5c — Write optimization findings back per plan

Each optimization pass may produce findings that apply to one, some, or all plans. Apply the same split-write
rule as Step 3:

- Write only the findings relevant to a given plan into that plan's file.
- If a finding spans multiple plans (e.g., a shared N+1 query path), write it into the plan that owns the
  affected code and add a note in the other plan's cross-plan references section pointing to it.

After all passes complete, do a final read of all plan files to confirm no new ambiguities were introduced.

---

**Task:** $ARGUMENTS