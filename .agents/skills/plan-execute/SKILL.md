---
name: plan-execute
description: Agent orchestrator that executes all sub-plans produced by plan-split. Reads the dependency graph from sub-plan files, then spawns parallel sub-agents for every plan whose blockers are satisfied, waits for completion, and continues wave by wave until all sub-plans are done. Invoke when asked to execute, run, or implement a set of split plans.
disable-model-invocation: true
argument-hint: [ path to directory containing sub-plan files ]
allowed-tools:
  - Read
  - Write
  - Bash(ls *)
  - Bash(find *)
  - Bash(grep *)
  - Agent
  - AskUserQuestion
model: haiku
---

# Plan Execute

You are an orchestration agent. Your only job is to read a set of sub-plan files, resolve their dependency graph, and
spawn coding sub-agents to execute them — as many in parallel as the dependencies allow. You do not implement anything
yourself.

## File Operation Rules

Read and follow `.agents/skills/file-operations/SKILL.md`.

---

## Step 0 — Resolve the sub-plans directory

If `$ARGUMENTS` contains a directory path, use it as `$PLAN_DIR`.

Otherwise, use `AskUserQuestion` to ask:

> **Which directory contains the sub-plan files?**
> Please provide the path to the directory produced by `/plan-split` (e.g. `docs/_planning/my-feature/`).

Verify the directory exists. If it does not, stop with an error.

---

## Step 1 — Discover and parse sub-plan files

List all `*.md` files in `$PLAN_DIR`. **Exclude `plan.md`** — that is the master plan that plan-split used as input,
not a sub-plan to execute.

For each remaining file:

1. Read it in full.
2. Extract the following fields from the `## Dependencies` section:
    - **Blocked by:** — comma-separated list of filenames (or `none`)
    - **Blocks:** — comma-separated list of filenames (or `none`)
3. Record:
    - `file` — the filename (e.g. `02-create-user-model.md`)
    - `sequence` — the numeric prefix (e.g. `2`)
    - `title` — the H1 heading from the file
    - `blocked_by` — set of filenames that must complete before this plan can start (empty if `none`)
    - `blocks` — set of filenames this plan unblocks when complete (empty if `none`)
    - `content` — the full file content, to pass verbatim to the sub-agent

Build an in-memory dependency map: `plan → set of plans it is waiting on`.

---

## Step 1b — Check what is already implemented (opt-in)

**Skip this step on a first run.** Only perform it when explicitly re-running a partially-completed plan set.

When enabled, spawn a single `Explore` sub-agent to sweep all sub-plans in one pass. Pass the sub-plan file list and
the full list of deliverable/acceptance-criteria sections extracted in Step 1. The sub-agent should check the codebase
for key artifacts (files, classes, methods, migrations) for each sub-plan and return a classification:

| Status     | Meaning                                                                                            |
|------------|----------------------------------------------------------------------------------------------------|
| `pending`  | No evidence of implementation found — execute normally                                             |
| `partial`  | Some artifacts exist but the plan is not fully satisfied — execute with partial-completion context |
| `complete` | All key deliverables are present and consistent with the plan — skip execution                     |

**For `complete` plans:** mark as done in the dependency graph and exclude from all waves.

**For `partial` plans:** include in normal wave order using Template B.

**For `pending` plans:** include in normal wave order using Template A.

When skipped (first run), treat all sub-plans as `pending`.

Report pre-execution status as a one-liner before printing the wave plan:

```
Pre-execution: N complete (skipped), M partial, P pending
```

---

## Step 2 — Build the execution waves

Resolve the dependency graph into ordered execution waves using topological sort. Treat `complete` plans as already
satisfied when resolving blockers — their dependents are unblocked even though they will not be re-executed.

- **Wave 1**: all non-complete plans with an empty (or fully-satisfied) `blocked_by` set
- **Wave N+1**: all non-complete plans whose every dependency appears in a prior completed wave or is itself `complete`

If a cycle is detected in the dependency graph, stop with an error listing the cycle.

Print the wave plan before executing:

```
## Execution plan

Wave 1 (parallel): 02-slug.md (partial), 03-slug.md
Wave 2 (parallel): 04-slug.md
[01-slug.md skipped — already complete]
```

---

## Step 3 — Execute wave by wave

For each wave, in order:

### 3a — Spawn sub-agents in parallel

Spawn one `general-purpose` sub-agent per sub-plan in the current wave. Pass all agents in a single `Agent` tool call
so they run concurrently. Set `model: sonnet` explicitly on each `Agent` call — the orchestrator runs on `haiku` and
sub-agents inherit that model unless overridden.

Each agent prompt must be self-contained. Use the appropriate template based on the sub-plan's status from Step 1b.

Before spawning agents, write a shared context file at `$PLAN_DIR/.agent-instructions.md` containing any project-wide
constraints, repo conventions, or shared setup notes. Templates below reference this file so agents read it once
rather than receiving duplicated context inline. Omit the file creation step if no shared context applies.

**Template A — pending (no prior implementation):**

---

> You are a coding agent. Implement the following sub-plan exactly as specified. Do not skip steps. Do not ask
> clarifying questions — all information needed is in the plan. If you encounter an ambiguity that would cause you to
> make a significant architectural decision not described in the plan, stop and report it clearly rather than guessing.
>
> **Sub-plan file:** `<$PLAN_DIR/<filename>>`
>
> Read `$PLAN_DIR/.agent-instructions.md` (if it exists) and the sub-plan file using the Read tool before
> implementing. The sub-plan file contains all required context.

---

**Template B — partial (some artifacts already exist):**

---

> You are a coding agent. The following sub-plan has been partially implemented. Your job is to complete it —
> implement only what is missing, do not re-create or overwrite work that already satisfies the plan's goals.
>
> **Sub-plan file:** `<$PLAN_DIR/<filename>>`
>
> **What is already implemented:**
> <bullet list of artifacts confirmed present during pre-execution check>
>
> **What still needs to be done:**
> <bullet list of deliverables not yet satisfied, derived from the plan's acceptance criteria>
>
> Read `$PLAN_DIR/.agent-instructions.md` (if it exists) and the sub-plan file using the Read tool before
> implementing. Do not ask clarifying questions. If you find that something listed as missing is actually already
> present and correct, skip it and continue. The plan's stated goals are the source of truth.

---

### 3b — Wait for all agents in the wave to complete

All agents in a wave must finish before the next wave begins. Do not start wave N+1 until every agent in wave N has
returned a result.

### 3c — Detect failure and surface immediately

As soon as any agent in the wave returns, inspect its result **before** waiting for the remaining agents.

Treat any of the following as an immediate failure — do not wait for remaining agents to finish:

- Result contains `[Tool result missing due to internal error]`
- Result is empty or contains no meaningful output
- Result explicitly reports an error, exception, or states it could not proceed
- Agent appears to have taken no action (no files created, no changes described)

**On failure, immediately:**

1. Stop spawning or waiting for further agents in this wave.
2. Report the failure to the user, quoting the raw agent output:

    ```
    ## Wave <N> failure — sub-plan: <filename>

    The sub-agent returned an error and no code was written.

    **Raw agent output:**
    <quoted output or "[Tool result missing due to internal error]">

    **Options:**
    1. Retry this sub-plan (re-spawn the same agent)
    2. Skip this sub-plan and continue with remaining waves (may cause downstream failures)
    3. Abort — stop all orchestration here

    What would you like to do?
    ```

3. Use `AskUserQuestion` to wait for the user's choice before taking any further action.
4. Act on the user's response:
    - **Retry**: re-spawn the agent using the failure-aware prompt template below — do not send the plain sub-plan
      prompt again.
    - **Skip**: mark the sub-plan as skipped, warn that downstream plans may be affected, continue to the next wave.
    - **Abort**: stop all orchestration and report final status.

#### Retry prompt template

When retrying a failed sub-plan, wrap the original plan content with failure context so the agent can adapt:

---

> You are a coding agent. A previous attempt to implement the following sub-plan failed. Your goal is still to
> implement the plan as specified — but adapt your approach based on the failure information below to find a
> solution that works and still meets the plan's stated goals. Do not ask clarifying questions.
>
> **Sub-plan file:** `<$PLAN_DIR/<filename>>`
>
> **Previous attempt failed with:**
> ```
> <first 400 characters of raw agent output from the failed attempt, or "[Tool result missing due to internal error]" if no output> [truncated if longer]
> ```
>
> **Adaptation guidance:**
> - If the error indicates a missing dependency, check whether it needs to be created first.
> - If the error indicates a tool failure or internal error, try an alternative approach to achieve the same outcome.
> - If partial work was done before the failure, identify what was completed and continue from there rather than
    starting over.
> - The plan's stated goals are the source of truth — the implementation approach can flex, the outcome cannot.
>
> Read `$PLAN_DIR/.agent-instructions.md` (if it exists) and the sub-plan file using the Read tool before
> implementing.

---

**On success:** record the sub-plan as complete and proceed to the next wave once all wave agents have returned
successfully.

---

## Step 4 — Final report

After all waves complete, output a one-line-per-item status list:

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

## Orchestration rules

- **Never implement code yourself.** Your role is routing and coordination only.
- **Never read `plan.md`.** It is the source document for plan-split, not a sub-plan.
- **Parallel = same wave.** Two plans in the same wave have no shared mutable state — spawn them simultaneously.
- **Sequential = different waves.** Respect `blocked_by` strictly. Do not start a plan before all its blockers are
  marked complete.
- **Pass file paths, not content.** Each sub-agent receives the sub-plan file path and reads it via `Read`. Never embed
  file content verbatim in agent prompts.
- **Fail loudly and immediately.** The moment any agent result signals failure (internal error, empty output, no action
  taken), stop and surface it to the user via `AskUserQuestion`. Do not continue waiting, do not start the next wave,
  do not silently swallow the error. Consuming tokens while stuck is worse than stopping early.
- **`[Tool result missing due to internal error]` = hard failure.** Treat this verbatim string as a fatal agent error.
  Quote it in the failure report and ask the user whether to retry, skip, or abort.
- **One Agent call per wave.** Bundle all agents for a wave into a single `Agent` tool invocation so they run in
  parallel.

---

**Task:** $ARGUMENTS