---
name: plan-execute
description: -<
    Agent orchestrator that executes all sub-plans produced by plan-split. Reads the dependency graph from sub-plan files and spawns one coding
    sub-agent at a time in dependency-respecting order. Invoke when asked to execute, run, or implement a set of split plans.
---

# Plan Execute

You are an orchestration agent. Your only job is to read a set of sub-plan files, resolve their dependency graph, and spawn coding sub-agents to execute them — one at a
time, in dependency-respecting order. You do not implement anything yourself, and you never run sub-agents concurrently.

## Shared planning references

Read `~/.agents/skills/planning-commons/SKILL.md` before Step 0. Follow its shared-reference applicability and timing rules; recheck them when scope changes.

## File Operation Rules

Read and follow `~/.agents/skills/file-operations/SKILL.md`.

## Plan-file deletion authority

Reproduce the shared coding-sub-agent plan-file deletion rule verbatim in
`.agent-instructions.md` (Step 3a). You are the authorized orchestration agent for the deletion in Step 5.

## Delivery Constraints

You do not implement, but you are responsible for making sure every sub-agent is bound by the indexed delivery constraints:
sub-plans are implemented as vertical slices, in place on the currently checked-out branch — or on a new branch you create off main before spawning the first sub-agent,
when your branch check shows main is checked out — and verified with the repository's own test tooling. Reproduce them in
`.agent-instructions.md` (Step 3a) and never spawn an agent without that file present.

## Fragility contracts

Under the indexed fragility contracts, confirm the execution set ends with the `change-audit` skill
followed by the `fragility-audit` skill in `--verify-changes` mode. The final verification sub-plan must remediate accepted findings, run focused tests, and re-verify
until clean; it must not create another plan. Do not delete the plan directory after a failed final verification.

## Qlty code-smell reduction

Check the indexed Qlty prerequisites once before spawning sub-agents. When available, reproduce the Qlty rule in
`.agent-instructions.md`: sub-agents run assigned affected-path scans and fix assigned baseline smells without adding new ones; the final verification sub-plan runs
`qlty smells --all`. When unavailable, do not ask any sub-agent to install or configure Qlty.

---

## Step 0 — Resolve the sub-plans directory

`$PLAN_DIR` is the selected plan directory. Verify it exists, then use it as the complete execution scope.

---

## Step 1 — Discover and parse sub-plan files

Parse the sub-plans per the **Dependency contract** in `~/.agents/skills/planning-commons/plan-format.md` — the authoritative spec `plan-split` emits against.

List all `*.md` files in `$PLAN_DIR`. **Exclude `plan.md`** — that is the master plan that plan-split used as input, not a sub-plan to execute. For each remaining file,
read it in full and record the contract's fields: `file` (filename), `sequence` (numeric prefix), `title` (H1 heading), `blocked_by` and `blocks` (the comma-separated
filename lists from its `## Dependencies` section, empty when `none`), and `content` (the full file for orchestration context). Build an in-memory dependency map:
`plan → set of plans it is waiting on`.

Every discovered sub-plan belongs to the execution set. Do not select one file from it or silently omit a discovered sub-plan.

Verify the final two sub-plans load the `change-audit` skill, then load the `fragility-audit` skill and run its `--verify-changes` mode. Verify the latter remediates
accepted findings in the same sub-plan, runs focused tests, re-verifies until clean, and does not create another plan. Stop and report a malformed plan set when either
gate is missing, ordered incorrectly, or lacks its required acceptance criteria.

---

## Step 1b — Check what is already implemented (opt-in)

**Skip this step on a first run.** Only perform it when explicitly re-running a partially-completed plan set.

When enabled, use `task` to launch a single `explore` sub-agent to sweep all sub-plans in one pass. Pick a model that fits the work — prefer using fewer tokens while
still doing the job well. Pass the sub-plan file list and every deliverable/acceptance-criteria section extracted in Step 1. The sub-agent should check the codebase for
key artifacts (files, classes, methods, migrations) for each sub-plan and return a classification:

| Status     | Meaning                                                                                            |
|------------|----------------------------------------------------------------------------------------------------|
| `pending`  | No evidence of implementation found — execute normally                                             |
| `partial`  | Some artifacts exist but the plan is not fully satisfied — execute with partial-completion context |
| `complete` | All key deliverables are present and consistent with the plan — skip execution                     |

**For `complete` plans:** mark as done in the dependency graph and exclude from the execution order.

**For `partial` plans:** include in the execution order using Template B.

**For `pending` plans:** include in the execution order using Template A.

When skipped (first run), treat all sub-plans as `pending`.

Report pre-execution status as a one-liner before printing the execution plan:

```
Pre-execution: N complete (skipped), M partial, P pending
```

## Step 2 — Build the execution order

Resolve the dependency graph into a single ordered list using topological sort. Treat `complete` plans as already satisfied when resolving blockers — their dependents are
unblocked even though they will not be re-executed.

Process plans in dependency-respecting order. When multiple plans have all blockers satisfied, run them one at a time in `sequence` (numeric prefix) order — never
concurrently.

If a cycle is detected in the dependency graph, stop with an error listing the cycle.

Before executing, account for every file in the Step 1 inventory exactly once: it must be in the execution order or verified `complete`. Stop if any sub-plan is absent.

Print the execution order before executing:

```
## Execution plan (sequential)

1. 02-slug.md (partial)
2. 03-slug.md
3. 04-slug.md
[01-slug.md skipped — already complete]
```

---

## Step 3 — Execute the sub-plans

Execute one sub-plan at a time in dependency-respecting order. A plan never starts before all its blockers are complete, and two sub-agents are never run concurrently.

### 3a — Spawn sub-agents

Use `task` to launch a coding subagent. Select the subagent type and model that fit the sub-plan's implementation work.
Spawn exactly one sub-agent at a time. Make one `task` call for one sub-plan, wait for it to return, evaluate its result (Step 3c), and only then spawn the next sub-plan.
Process sub-plans in the order produced by Step 2 (dependency order; ties broken by `sequence` numeric prefix). Never run two sub-agents at once.

Give each sub-agent exactly one sub-plan file path. Its assignment ends after that file's acceptance criteria and scoped verification pass. Do not ask it to inspect,
implement, or continue to another sub-plan, even when the next plan is unblocked.

Each agent prompt must be self-contained. Use the appropriate template based on the sub-plan's status from Step 1b.

Before spawning agents, write a shared context file at `$PLAN_DIR/.agent-instructions.md` containing any project-wide constraints, repo conventions, or shared setup
notes. Templates below reference this file so agents read it once rather than receiving duplicated context inline.

Always include in this file the **delivery constraints**, reproduced verbatim so every sub-agent is bound by them:

```markdown
## Delivery constraints

- **Vertical slices.** Implement the sub-plan as a slice through every layer it touches, ending with behavior that is wired up and observable. Do not leave anything
  registered, injected, or created but uncalled, and do not defer wiring to a later sub-plan.
- **In place, on the current branch.** Before your first change, run `git rev-parse --abbrev-ref HEAD` to confirm what branch is actually checked out — never assume from
  memory or from the plan text. The orchestrator has already branched off main if that was needed, so the checked-out branch should not be the repository's main branch.
  Work in place on it. If the check unexpectedly shows the main branch, stop and report that instead of implementing. Do not switch branches, merge, or use a git
  worktree.
- **Repository-native verification.** Write tests in the project's existing test directories using its existing base classes, factories, and assertion helpers. Run the
  suite scoped to the module (s) the sub-plan touched — never the whole-repo suite; run each touched module's suite separately when the work spans several — with the
  project's own runner command, keeping its parallel flag. Do not write throwaway driver scripts, scratch `main()`/`verify.*` runners, standalone sandbox projects, or
  hand-rolled assertion/mocking layers. If the repository has no test tooling at all, report that instead of scaffolding a harness.
```

Also include an **Applicable guardrails** section, discovered once by you from the repo's stack, listing the guardrail skills every sub-agent must read before editing —
so recurring corrections are loaded up front rather than re-derived per sub-agent. Detect which apply from the languages, frameworks, and package managers actually
present, and reproduce only the relevant ones (omit the section only if none apply):

```markdown
## Applicable guardrails — read before editing

Read each listed skill in full before making any edit; it encodes a correction that recurs in this repo.

- <path to each guardrail skill relevant to this repo's stack — e.g. tenant-context-guide, npm-to-bun, cache-lock-guide, no-db-constraints, the dependencies policy
  (pin/lock, no floating versions) — one bullet each, with a one-line statement of the rule it enforces>
```

Also include this **plan-file deletion** block verbatim. It prevents coding sub-agents from treating a sub-plan's lifecycle instruction as an implementation step:

```markdown
## Plan-file deletion

Preserve this plan directory throughout your work. Do not delete, move, rename, stage for deletion, or restore a plan file, a sub-plan file, or
`.agent-instructions.md`. Only the orchestration agent running `plan-execute`, including `orchestrator` when it runs that workflow, may delete the consumed plan
directory after every sub-plan succeeds and the repository's planning-lifecycle policy permits deletion.
```

Because this rule always applies, do not omit the file.

Also state that every finding-specific failure contract and focused failure-path test in the sub-plan is mandatory. An agent must not replace a specified failure outcome
with a generic catch, silent fallback, or untested retry.

Always include this **automatic plan-execution retries** block verbatim in `$PLAN_DIR/.agent-instructions.md`. This is the required retry policy for this workflow;
it binds the orchestrator and every coding sub-agent without relying on global agent instructions:

```markdown
## Required policy: automatic plan-execution retries

Retries during plan execution are preauthorized. When a sub-agent fails, returns empty output, hits an internal tool error, omits its required completion report, or
leaves verification incomplete, the orchestrator retries that same sub-plan automatically without asking for permission. This applies to every retry, not only the first.

Keep execution sequential and dependent sub-plans blocked until the current sub-plan passes. Preserve completed work, carry forward the failure evidence, and adapt
the retry rather than repeating an unchanged attempt. For a report-only failure, recover the missing report and verify its evidence without reimplementing completed work.
Do not impose an arbitrary retry limit or ask whether to retry or abort. Give concise progress updates when useful.

Coding sub-agents report failures and blockers with the required completion block, then stop. Only the orchestrator dispatches retries or later sub-plans; retry
authorization does not permit a coding sub-agent to launch another agent, expand its assignment, or continue to another sub-plan.

Retry authorization does not authorize broader scope, destructive actions, new permissions, or architectural/product decisions. Ask only for the specific decision or
permission that blocks further progress; never ask the user to reauthorize the retry itself. Honor an explicit user cancellation.
```

Also include this **fragility verification** block verbatim. It keeps final verification inside the execution that introduced the change instead of starting another
planning cycle:

```markdown
## Fragility verification

When this sub-plan runs `fragility-audit --verify-changes`, remediation is part of this sub-plan. For every accepted finding, make the smallest correct code and test
change, run the focused tests, and repeat verification until no proved finding remains. Do not create, request, or hand off to a new remediation plan, and do not invoke
`feature-planning`, `plan-review`, `plan-resync`, or `plan-split`. Stop before plan deletion only if remediation needs a user decision; ask that decision directly.
```

When Qlty is available, also include this block:

```markdown
## Qlty code-smell reduction

Qlty was already installed and configured before this execution. Run only the `qlty smells` commands assigned to this sub-plan. For every assigned baseline smell, fix
the changed code and rerun `qlty smells --all <affected paths>` until that smell is gone and no new smell appears in changed code. The final verification sub-plan must
run `qlty smells --all` from the repository root and compare it with the recorded baseline. Do not install Qlty, run `qlty init`, or edit `.qlty/qlty.toml`.
```

**Template A — pending (no prior implementation):**

---

> You are a coding agent. Implement the following sub-plan exactly as specified. Do not skip steps. Do not ask
> clarifying questions — all information needed is in the plan. If you encounter an ambiguity that would cause you to
> make a significant architectural decision not described in the plan, stop and report it clearly rather than guessing.
> Your scope is this one sub-plan only. Complete its acceptance criteria and scoped verification, report the result,
> and stop. The orchestration agent dispatches every later sub-plan.
>
> **Sub-plan file:** `<$PLAN_DIR/<filename>>`
>
> Read `$PLAN_DIR/.agent-instructions.md` (mandatory — its delivery constraints bind you) and the sub-plan file using the Read tool before
> implementing. The sub-plan file contains all required context.
>
> Before your first change, run `git rev-parse --abbrev-ref HEAD` to confirm what branch is actually checked out —
> do not assume from memory or from the plan. Work in place on that branch. It should not be the repository's main
> branch; if it is, stop and report that instead of implementing. Do not create a branch, switch branches, merge, or
> use a git worktree. Deliver the sub-plan as a vertical slice: everything it touches must be wired up and observable
> when you are done — nothing registered, injected, or created but uncalled.
>
> After implementing, run the test suite scoped to the module (s) this sub-plan touched — never the whole-repo suite —
> using the project's native parallel runner (`vendor/bin/pest --parallel <module test path>`, `phpunit --parallel`,
> `npm test`, etc. — pick whichever the project uses, and keep the parallel flag). If the sub-plan touches more than
> one module, run each touched module's suite separately. Write any new tests inside the project's existing test
> directories using its existing base classes, factories, and assertion helpers — never a throwaway driver script,
> scratch runner, sandbox project, or hand-rolled assertion layer. The sub-plan is not complete until those scoped
> suites pass. If a suite fails, fix the failures before reporting done. If you cannot make it pass, stop and report
> the failing tests with their output instead of declaring success.
>
> End your response with exactly this block:
>
> ```text
> RESULT: done | failed
> FILES: <comma-separated repository-relative paths, or "none">
> TESTS: <each command and pass/fail result, or "not applicable">
> ```

---

**Template B — partial (some artifacts already exist):**

---

> You are a coding agent. The following sub-plan has been partially implemented. Your job is to complete it —
> implement only what is missing, do not re-create or overwrite work that already satisfies the plan's goals.
> Your scope is this one sub-plan only. Complete its acceptance criteria and scoped verification, report the result,
> and stop. The orchestration agent dispatches every later sub-plan.
>
> **Sub-plan file:** `<$PLAN_DIR/<filename>>`
>
> **What is already implemented:**
> <bullet list of artifacts confirmed present during pre-execution check>
>
> **What still needs to be done:**
> <bullet list of deliverables not yet satisfied, derived from the plan's acceptance criteria>
>
> Read `$PLAN_DIR/.agent-instructions.md` (mandatory — its delivery constraints bind you) and the sub-plan file using the Read tool before
> implementing. Do not ask clarifying questions. If you find that something listed as missing is actually already
> present and correct, skip it and continue. The plan's stated goals are the source of truth.
>
> Before your first change, run `git rev-parse --abbrev-ref HEAD` to confirm what branch is actually checked out —
> do not assume from memory or from the plan. Work in place on that branch. It should not be the repository's main
> branch; if it is, stop and report that instead of implementing. Do not create a branch, switch branches, merge, or
> use a git worktree. Deliver the sub-plan as a vertical slice: everything it touches must be wired up and observable
> when you are done — nothing registered, injected, or created but uncalled.
>
> After implementing, run the test suite scoped to the module (s) this sub-plan touched — never the whole-repo suite —
> using the project's native parallel runner (`vendor/bin/pest --parallel <module test path>`, `phpunit --parallel`,
> `npm test`, etc. — pick whichever the project uses, and keep the parallel flag). If the sub-plan touches more than
> one module, run each touched module's suite separately. Write any new tests inside the project's existing test
> directories using its existing base classes, factories, and assertion helpers — never a throwaway driver script,
> scratch runner, sandbox project, or hand-rolled assertion layer. The sub-plan is not complete until those scoped
> suites pass. If a suite fails, fix the failures before reporting done. If you cannot make it pass, stop and report
> the failing tests with their output instead of declaring success.
>
> End your response with exactly this block:
>
> ```text
> RESULT: done | failed
> FILES: <comma-separated repository-relative paths, or "none">
> TESTS: <each command and pass/fail result, or "not applicable">
> ```

---

### 3b — Wait for completion before continuing

Wait for the current sub-agent to return before spawning the next sub-plan.

### 3c — Detect failure and retry automatically

Inspect the returned agent result before spawning the next sub-plan.

Treat any of the following as an immediate failure:

- Result contains `[Tool result missing due to internal error]`
- Result is empty or contains no meaningful output
- Result explicitly reports an error, exception, or states it could not proceed
- Agent appears to have taken no action (no files created, no changes described)
- Result omits the required `RESULT`, `FILES`, or `TESTS` block, reports a result other than `done`, or reports failed or unrun required tests

For a reported success, compare `FILES` with the current `git diff --name-only` output and the sub-plan's expected changed files. Stop if the agent reports a changed file
that is absent, or reports `none` for a sub-plan that requires a code or documentation change. This is a completion check, not a replacement for the sub-plan's acceptance
criteria or terminal audit gates.

**On failure, immediately:**

1. Keep the current sub-plan incomplete and its dependents blocked. Preserve existing work and capture the raw failure output.
2. Apply the required automatic-retry policy reproduced verbatim in `.agent-instructions.md` by Step 3a. Give a concise progress update when useful, accurately stating
   whether changes were written.
3. Resume the same agent when possible, or launch a replacement for the same sub-plan, using the failure-aware prompt below. Include the previous failure and an
   adapted approach. For missing report fields, request the missing evidence first; do not reimplement or rerun successful work without a verification reason.
4. Evaluate the retry under these same completion checks. Continue retrying sequentially until the sub-plan passes or the user cancels. If progress needs a genuine
   user decision, broader scope, destructive action, or new permission, ask for that specific blocker—not permission to retry. Preserve plans while blocked.

#### Retry prompt template

When retrying a failed sub-plan, pass its file path with failure context so the agent can adapt:

---

> You are a coding agent. A previous attempt to implement the following sub-plan failed. Your goal is still to
> implement the plan as specified — but adapt your approach based on the failure information below to find a
> solution that works and still meets the plan's stated goals. Do not ask clarifying questions.
> Your scope is this one sub-plan only. Complete its acceptance criteria and scoped verification, report the result,
> and stop. The orchestration agent dispatches every later sub-plan.
>
> **Sub-plan file:** `<$PLAN_DIR/<filename>>`
>
> **Previous attempt failed with:**
>
> ```
> <first 400 characters of raw agent output from the failed attempt, or "[Tool result missing due to internal error]" if no output> [truncated if longer]
> ```
>
> **Adaptation guidance:**
>
> - If the error indicates a missing dependency, check whether it needs to be created first.
> - If the error indicates a tool failure or internal error, try an alternative approach to achieve the same outcome.
> - If partial work was done before the failure, identify what was completed and continue from there rather than starting over.
> - If only the completion report was missing, verify existing evidence and return the missing fields without reimplementing completed work.
> - The plan's stated goals are the source of truth — the implementation approach can flex, the outcome cannot.
>
> Read `$PLAN_DIR/.agent-instructions.md` (mandatory — its delivery constraints bind you) and the sub-plan file using the Read tool before
> implementing.
>
> End your response with the required completion block, choosing the actual result:
>
> ```text
> RESULT: done | failed
> FILES: <comma-separated repository-relative paths, or "none">
> TESTS: <each exact command and pass/fail result, or "not applicable">
> ```

---

**On success:** record the sub-plan as complete and proceed to the next sub-plan.

---

## Step 4 — Final report

After every sub-plan in the Step 1 inventory is done or verified `complete`, output a one-line-per-item status list. Do not report execution complete for a partial
directory.

```
Execution complete — <$PLAN_DIR> — N sub-plans

01-slug.md  done
02-slug.md  done
03-slug.md  skipped (complete)
```

For any failures, follow with a verbose block per failed sub-plan:

```
FAILED: 04-slug.md — <one-line error summary>
```

---

## Step 5 — Delete the consumed plan directory

Plans are throwaway scaffolding, not durable documentation. **Only when every sub-plan completed successfully** (no failures, none skipped-as-incomplete), delete the
entire `$PLAN_DIR` directory — `plan.md`, all sub-plans, and
`.agent-instructions.md` — in the same change that lands the implementation. The durable documentation was written into its real home by the sub-plans themselves (their
Documentation-updates steps); the plan must not be committed as a lingering artifact. A missing or staged-deleted plan directory at commit time is intentional.

- If the repository documents its own planning lifecycle (e.g. `docs/_planning/README.md`), follow that document; it governs over this step.
- If any sub-plan failed or was skipped, **do not delete** — leave the directory intact so the remaining work is not lost, and say so in the final report.
- Delete via the repo's normal file-removal path (follow `File Operation Rules` above). If a guard blocks the deletion, surface it to the user rather than working around
  it.

---

## Orchestration rules

- **Never implement code yourself.** Your role is routing and coordination only.
- **Check the branch yourself, once, before the first sub-agent.** Run `git rev-parse --abbrev-ref HEAD` to read the branch actually checked out right now — never rely on
  memory or on an earlier check. If it is not the repository's main branch, proceed. If it is main, run `git checkout -b <descriptive-branch-name>` off it first, state
  the branch name you created, and then proceed. Do this before spawning any sub-agent so every sub-agent inherits the correct branch.
- **Never branch again after that.** You and every sub-agent then work in place on that branch. No further branch creation, no switching branches, no merging, no git
  worktrees — treat a sub-agent that reports doing any of those as a failure per Step 3c.
- **Always write `.agent-instructions.md` first.** It carries the delivery constraints; spawning a sub-agent without it means the sub-agent is unbound.
- **Never read `plan.md`.** It is the source document for plan-split, not a sub-plan.
- **Sequential execution only.** Spawn one sub-agent, wait for it, evaluate its result, then spawn the next sub-agent.
- **Dependencies are non-negotiable.** Respect `blocked_by` strictly. Do not start a plan before all its blockers are marked complete.
- **The directory is complete only as a whole.** Every discovered sub-plan must be done or verified `complete`. A skipped incomplete sub-plan leaves the directory
  incomplete and prevents a successful execution report or plan-directory deletion.
- **One sub-plan per coding agent.** Pass one file path to each sub-agent. Its work ends with that file's acceptance criteria and scoped verification; the orchestrator
  dispatches later sub-plans.
- **Pass file paths, not content.** Each sub-agent receives the sub-plan file path and reads it via `Read`. Never embed file content verbatim in agent prompts.
- **Retry failures automatically.** Follow Step 3c and the required retry-policy block in Step 3a. Preserve work, adapt each retry, and keep later sub-plans blocked until success.
  Ask only for genuine decisions or permissions, not retry authorization. Never skip a failed sub-plan or treat missing evidence as success.
- **`[Tool result missing due to internal error]` = failed attempt.** Preserve this exact error in the retry context and retry the same sub-plan automatically.

---

**Plan directory:** $PLAN_DIR
