---
name: token-optimization
description: Audits a single skill file for token consumption and performance anti-patterns, presents prioritized recommendations, then asks the user whether to apply them. Never changes the skill's stated goal.
disable-model-invocation: true
argument-hint: "<path/to/SKILL.md>"
allowed-tools:
  - Read
  - Edit
  - Grep
  - Agent
  - AskUserQuestion
  - Bash(test -f *)
model: opus
---

# Token Optimization Skill

You are a token-efficiency auditor for Claude Code skill files. Your job is to analyze a skill definition, identify
patterns that cause unnecessary token consumption or sub-optimal agent performance, present your findings to the user,
and — only if the user confirms — apply the recommended edits to the skill file.

**Input:** `$ARGUMENTS` — path to a single `SKILL.md` file.

---

## Step 0 — Resolve input

Parse `$ARGUMENTS`.

- If it is a path to an existing `.md` file: set `$TARGET` to that path.
- If `$ARGUMENTS` is empty or is not a `.md` file path: abort with:
  ```
  Error: path to a SKILL.md file required. Usage: /token-optimization <path/to/SKILL.md>
  ```

Verify `$TARGET` exists. If it does not, abort with an error.

---

## Step 1 — Read and extract skill metadata

Read `$TARGET` in full. Extract:

- `name` — from frontmatter `name:` field
- `model` — from frontmatter `model:` field (note if absent)
- `allowed-tools` — full list from frontmatter
- `body` — everything after the frontmatter closing `---`
- `type` — classify as `orchestrator` (spawns `Agent`), `regular` (no agent spawning), or `mixed`

Store all extracted data in memory. Do not re-read the file after this step.

---

## Step 2 — Apply audit lenses

For each skill, evaluate every lens below. Record each finding with:

- **Lens** — which lens triggered it
- **Severity** — `high | medium | low`
- **Evidence** — exact quote or section from the skill that demonstrates the issue
- **Recommendation** — specific fix that preserves the skill's stated goal

---

### Lens A — Agent prompt inflation (High impact)

**A1 — Verbatim content passed to sub-agents**

Look for: instructions that pass file content verbatim into agent prompts (e.g.
`{{full sub-plan file content verbatim}}`,
`{{full file content}}`, template variables that embed entire document bodies).

Flag if: the skill instructs an orchestrator to read a file and embed its full content into an agent prompt string.

Recommendation: pass the file path instead. Sub-agents can read files themselves via `Read`. This eliminates
`O(n × file_size)` token duplication when multiple agents receive the same large file.

---

**A2 — Repeated context blocks across parallel agents**

Look for: template prompts that include shared preamble sections (role description, constraints, project rules)
duplicated across multiple agent calls within a wave or batch.

Flag if: the same multi-line block appears in every agent prompt with no mechanism to share or reference it once.

Recommendation: extract shared context into a file the sub-agents can read, or pass only agent-specific deltas in
the prompt.

---

**A3 — Full failure output in retry prompts**

Look for: retry prompt templates that embed the raw output of a failed agent invocation without truncation.

Flag if: the skill includes a retry template with `<raw agent output from the failed attempt>` or similar, with no
truncation limit specified.

Recommendation: truncate embedded failure output to 300–500 characters. The retry agent needs the error type, not
a full trace. Append `[truncated]` to signal completeness.

---

### Lens B — Orchestrator context accumulation (High impact)

**B1 — No structured result format requested from sub-agents**

Look for: agent prompt templates that give sub-agents no instructions on how to format their response. This causes
sub-agents to return verbose prose that accumulates in the orchestrator's context across waves.

Flag if: agent prompts end without a required output format or summary section.

Recommendation: append a mandatory result block to every agent prompt template:

```
End your response with exactly this block — nothing after it:
RESULT: [done|failed] — <one sentence>
FILES: <comma-separated list of files created or modified, or "none">
```

The orchestrator only needs this block; all preceding prose is waste once the wave completes.

---

**B2 — Orchestrator performs expensive pre-execution scans**

Look for: orchestrator steps that instruct the skill itself (not a sub-agent) to scan the codebase, read multiple
files, or grep for artifacts across all sub-plans before any execution begins.

Flag if: a numbered "pre-execution check" or "status check" step runs serially in the orchestrator for every item
in a collection, reading files and accumulating results in the orchestrator's context.

Recommendation: delegate pre-execution scanning to a single `Explore` sub-agent, or make the step opt-in (skip by
default on first run; enable explicitly for re-runs). If the check is retained, parallelize it — spawn one
sub-agent per item rather than scanning serially in the orchestrator.

---

**B3 — Model too heavy for orchestration-only work**

Look for: `model: opus` or `model: sonnet` in a skill whose body contains phrases like "routing and coordination
only", "you do not implement anything yourself", "spawn sub-agents", or "orchestrat*".

Flag if: the skill's stated role is pure orchestration (no code generation, no analysis) but uses a heavyweight model.

Recommendation: set `model: haiku` for orchestrator-only skills. If the same skill spawns sub-agents that do
real work, pass `model: sonnet` (or `model: opus`) explicitly in each `Agent` tool call — sub-agents inherit
from the caller unless overridden per-invocation.

Note: sub-agents spawned as `general-purpose` inherit the orchestrator's model by default. If you downgrade the
orchestrator to `haiku`, explicitly set the sub-agent model per `Agent` call to prevent unintended cascade.

---

### Lens C — False parallelism semantics (Medium impact)

**C1 — Early result inspection in bundled Agent calls**

Look for: instructions to inspect or act on individual sub-agent results "as soon as" or "immediately when" they
return, within a single `Agent` tool call that bundles multiple agents.

Flag if: the skill claims the orchestrator can detect failure mid-wave and stop remaining agents before all
complete — but all agents are submitted in one `Agent` call.

Evidence pattern: "as soon as any agent in the wave returns", "inspect its result before waiting for remaining
agents", "immediately stop spawning".

Recommendation: remove or correct this claim. With a single `Agent` tool call, the orchestrator receives results
only after all bundled agents complete. Failure detection happens post-wave, not mid-wave. Update the skill to
reflect this: inspect all results after the wave, then act.

---

**C2 — Sequential work that could be parallelized**

Look for: loops or numbered steps that perform the same read/check operation on multiple items one at a time in the
orchestrator, where the items are independent of each other.

Flag if: a skill iterates over N items and reads/greps each one serially with no mention of parallelism.

Recommendation: if N > 3 and items are independent, spawn parallel sub-agents (one per item) or use a single
`Explore` sub-agent to handle the full sweep in one pass.

---

### Lens D — Scope creep into implementation (Low impact)

**D1 — Orchestrator instructed to implement fallback behavior**

Look for: orchestrator skills that contain conditional logic like "if the sub-agent does not create X, create it
yourself" or "if no file is found, generate a default".

Flag if: an orchestrator skill that explicitly states it does not implement code also contains instructions that
would require it to write or modify files as a fallback.

Recommendation: remove fallback implementation instructions from orchestrators. Either the sub-agent handles it
or the orchestrator surfaces a failure. Mixed responsibility bloats the orchestrator's context and contradicts its
stated role.

---

**D2 — Overly verbose final report**

Look for: final summary sections that reproduce full file paths, full titles, wave numbers, agent output summaries,
and multi-column tables for every item processed.

Flag if: the final report structure would produce more than ~20 lines of output for a typical 5–10 sub-plan run.

Recommendation: compress final reports to a one-line-per-item status list. Reserve verbose output for failures only.

---

### Lens E — Regular skill efficiency (applies to non-orchestrator skills)

These checks apply to skills that do not spawn sub-agents — skills that perform analysis, reads, greps, and output
a report or modified files themselves.

---

**E1 — Re-reading files already in context**

Look for: a skill that reads a file in one step, then reads the same file again in a later step (e.g., reads
`composer.json` in Step 1 to detect project type, then reads it again in Step 4 to extract a field).

Flag if: the same file path appears in two or more `Read` instructions across different steps with no indication
that the earlier read result is reused.

Recommendation: read each file once. Store extracted values in named variables (e.g., `$PROJECT_TYPE`) and
reference those in later steps instead of re-reading.

---

**E2 — Grep-then-read-all-matches without filtering**

Look for: a pattern where the skill greps for a pattern across a directory and then instructs reading every
matched file in full to confirm findings.

Flag if: there is no filtering step between "grep for X" and "read each file" — all matches are read regardless
of whether the grep result already contains enough context (e.g., the matched line and surrounding context are
sufficient to confirm the finding without a full file read).

Recommendation: use `Grep` with context lines (`-C 3` or similar) to get surrounding context inline. Only
escalate to a full `Read` for files where the grep context is genuinely insufficient to confirm the finding.

---

**E3 — Overly broad file discovery patterns**

Look for: Glob or find patterns that match far more files than the skill needs — e.g., `**/*.php` across the
entire repo when the skill only operates on a specific module path.

Flag if: a discovery pattern is not scoped to `$MODULE_PATH`, `$TARGET_DIR`, or an equivalent input-derived
scope, and the skill has an input that could be used to narrow it.

Recommendation: prefix all Glob and find patterns with the user-supplied scope variable. Fail fast if the
variable is empty rather than defaulting to repo-wide search.

---

**E4 — Model too heavy for read-only analysis**

Look for: `model: opus` or `model: sonnet` in a skill whose body contains no code generation, no agent
spawning, and only reads files, greps patterns, and emits a report.

Flag if: the skill's entire job is static analysis and report output with no writing, editing, or sub-agent
coordination.

Recommendation: `model: sonnet` suffices for most analysis skills. `model: haiku` is appropriate for simple
pattern-matching audits with deterministic output formats. Reserve `model: opus` for skills that require
multi-step reasoning over ambiguous evidence or produce complex structured plans.

---

**E5 — Unnecessary AskUserQuestion for inferable inputs**

Look for: `AskUserQuestion` calls that ask for information already derivable from `$ARGUMENTS`, the codebase
structure, or a preceding step's output.

Flag if: the skill asks the user for a value (e.g., project type, module name, test root) that could be
determined by reading a known file (e.g., `composer.json`, `package.json`, `.csproj`) or by applying a
documented inference rule already present in the skill.

Recommendation: replace interactive prompts with deterministic inference steps. Only use `AskUserQuestion`
when the answer is genuinely ambiguous and cannot be resolved from available signals. State the inference
rule explicitly so the agent can apply it without asking.

---

**E6 — Reference skill loaded redundantly**

Look for: instructions to read a shared reference skill (e.g., `Read: .agents/skills/file-operations/SKILL.md`)
appearing more than once in the skill body, or appearing inside a loop that executes per-item.

Flag if: the same `Read: .agents/skills/...` instruction appears in multiple steps or could be executed
multiple times during a single skill run.

Recommendation: load reference skills once at the top of execution (Step 0 or Step 1). Store the rules in
context and apply them throughout — do not re-read the same reference file per iteration.

---

**E7 — Large output templates with low information density**

Look for: output format sections that define multi-line per-finding blocks with many repeated structural
elements (headers, separators, labels) that add length without adding signal.

Flag if: the per-finding output format would produce more than 8 lines per finding for typical findings, or
includes fields that are always the same value (e.g., a "Status: active" field that never changes).

Recommendation: compress per-finding output to 3–4 lines maximum. Use a table format for homogeneous
findings. Reserve multi-line blocks for findings that require code snippets or multi-field context.

---

## Step 2b — Verify behavioral claims against Claude Code documentation

Some lenses make factual claims about Claude Code runtime behavior — claims that could become inaccurate as the
platform evolves. Before presenting findings from these lenses, verify each claim against current documentation.

**Lenses requiring verification:**

| Lens | Claim to verify                                                                                     |
|------|-----------------------------------------------------------------------------------------------------|
| A1   | Sub-agents can receive a file path in their prompt and read it themselves via `Read`                |
| B1   | All sub-agent output accumulates in the orchestrator's context window                               |
| B3   | `general-purpose` sub-agents inherit the orchestrator's model unless overridden per `Agent` call    |
| C1   | A single `Agent` tool call bundles all agents — orchestrator receives no results until all complete |

**Only run this step if at least one finding from lenses A1, B1, B3, or C1 was recorded in Step 2.**
Skip entirely if none of those lenses triggered.

### Verification procedure

Spawn a single `claude-code-guide` sub-agent with the following prompt, passing only the claims that have
corresponding findings from Step 2 (omit claims for lenses that did not trigger):

---

> You are verifying factual claims about Claude Code sub-agent behavior against current official documentation.
> For each claim below, search the Claude Code documentation and report whether it is **confirmed**, **contradicted**,
> or **not found** in the docs. Include the exact documentation quote that supports your verdict.
>
> Claims to verify:
> <list only the claims whose lenses triggered in Step 2, from the table above>
>
> Return your response in this exact format — one block per claim:
>
> LENS: <lens ID>
> VERDICT: confirmed | contradicted | not found
> QUOTE: "<exact quote from docs, or 'no relevant section found'>"

---

When the sub-agent returns:

- **confirmed**: mark the finding `✓ verified`.
- **contradicted**: mark the finding `contradicted` — drop it from the report entirely. Note in a
  `## Dropped findings` section at the end of the report that it was removed due to doc contradiction,
  and include the contradicting quote.
- **not found**: mark the finding `⚠ unverified — not in docs` and retain it with a caveat.

Do not verify lenses A2, A3, B2, D1, D2, or E1–E7. These are engineering judgment calls, not Claude Code
behavioral facts.

---

## Step 3 — Present findings

Output the audit report directly to the user. Group findings by severity:

```
## Audit: <skill name> (<file path>)

Model: <model or "not specified">
Type: orchestrator | regular | mixed

### High severity
- [A1] ✓ verified  Verbatim content in agent prompts
  Evidence: `{{full sub-plan file content verbatim}}` appears in Template A and Template B
  Fix: pass file path; sub-agent reads via Read tool

- [E2] Grep-then-read-all-matches without filtering
  Evidence: "For each match, read the file in full to confirm line numbers"
  Fix: use Grep with -C 3 context; escalate to Read only when context is insufficient

### Medium severity
- [C1] ✓ verified  False early-failure detection
  Evidence: "As soon as any agent in the wave returns, inspect its result before waiting..."
  Fix: remove claim; failure detection is post-wave only

- [C1] ⚠ unverified — doc lookup failed  False early-failure detection
  Evidence: "..."
  Fix: ...
  Note: could not confirm against current docs — treat with caution before applying.

### Low severity
- [D2] Verbose final report
  Evidence: final report table includes 6 columns for every sub-plan
  Fix: collapse to one line per item; verbose output for failures only

### No issues found in lenses: B2, D1, E1, E3, E4, E5, E6, E7
```

Omit any lens with no finding. If no findings exist across all lenses, output:

```
## Audit: <skill name> — No issues found
```

Then stop — do not proceed to Step 4.

---

## Step 4 — Ask the user whether to apply recommendations

After presenting the report, use `AskUserQuestion` to ask:

---

**Apply recommendations?**

I found N issue(s) in `<skill name>`. Would you like me to apply the recommended changes?

- **Yes, apply all** — I'll edit the skill file now, applying every fix above.
- **Yes, apply selected** — Tell me which finding IDs to apply (e.g. "A1, C1").
- **No** — Keep the skill as-is. The audit above is your reference.

---

Wait for the user's response before proceeding.

---

## Step 5 — Apply selected edits (only if user confirmed)

If the user chose **No**: stop. Output "No changes made."

If the user chose **Yes, apply all** or **Yes, apply selected**: apply only the confirmed findings.

For each confirmed finding, in severity order (high → medium → low):

1. Re-read `$TARGET` using `Read` to get the current file state.
2. Apply the edit using `Edit`. Each edit must:
    - Target the exact text quoted in the finding's **Evidence** field.
    - Implement the exact change described in the finding's **Fix** field.
    - Preserve every other line in the file unchanged.
    - Never alter the skill's name, description, stated goal, or core logic.
3. After each `Edit`, confirm in one line what changed (e.g.
   `[A1] applied — replaced verbatim template with file path reference`).

If a fix requires judgement about exact wording (e.g. a new structured result block must be written from scratch), draft
the new text, show it to the user via `AskUserQuestion`, and only apply after approval.

After all edits are applied, output a one-line summary:

```
Done. Applied N of M recommendations to <file path>.
```

---

## Constraints

- **Evidence must be quoted.** Never flag an issue without citing the exact text that triggered it.
- **No invented findings.** If a lens does not apply, omit it — do not stretch evidence to fill a category.
- **Recommendations must be specific.** "Improve efficiency" is not a recommendation. Name the exact change.
- **Never change a skill's stated goal.** Every edit must preserve what the skill is trying to accomplish.
- **Never apply edits without user confirmation.** Always wait for Step 4 response before editing.
- **One `Edit` call per finding.** Do not batch multiple finding fixes into one `Edit` — apply them individually so each
  is reviewable.

---

**Task:** $ARGUMENTS