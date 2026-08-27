---
name: delivery-constraints
description: Canonical delivery constraints shared across all planning skills — vertical slices, in-place branch discipline, and repository-native test tooling. Read this file at the start of any skill that plans, splits, reviews, resyncs, or executes an implementation plan.
---

# Delivery Constraints

These constraints are non-negotiable. Every plan, sub-plan, review lens, and executing agent is held against them.

---

## 1. Build in vertical slices

Every plan, phase, and sub-plan must deliver a **vertical slice** — a change that cuts through every layer it touches and leaves the system with one more thing that
actually works end to end. It must not deliver a horizontal layer that nothing yet consumes.

**A vertical slice:**

- Cuts top to bottom through whatever layers the feature involves — schema/migration, domain/model, service/business logic, transport (API, command, event, hub), and
  UI/presentation — for one narrow piece of behavior.
- Is observable when complete: a user, an operator, a caller, or a test can exercise the new behavior and see the result. "Done" is described in terms of behavior, not in
  terms of files created.
- Is wired up. Nothing is left registered-but-unreferenced, injected-but-uncalled, or built-but-unrouted at the end of a slice.
- Leaves the codebase in a state where the repository's own test suite runs and passes, so the next slice starts from a verified baseline.

**A horizontal layer — do not plan one:**

- "Create all the models", then "create all the repositories", then "create all the controllers", then "wire it up at the end".
- A phase whose entire deliverable is scaffolding, interfaces, or abstractions that no caller uses yet.
- A phase that cannot be tested on its own because the layer above or below it does not exist yet.

**Narrow the behavior, not the stack.** When a slice is too large, cut it by taking a smaller piece of behavior all the way through the stack — one endpoint instead of
five, one field instead of the whole form, the happy path before the edge cases. Never cut it by removing a layer and deferring it to a later phase.

**Permitted exception:** genuinely shared groundwork that multiple slices depend on and that cannot be sensibly co-located with the first slice (for example a schema
migration that three slices all read, or a package/dependency install). Keep it as small as possible, place it first, and state explicitly in the plan why it cannot live
inside the first vertical slice. Anything that *can* live inside the first slice must.

---

## 2. Build in place, on the current branch — unless that branch is main

All implementation work happens in place, in the main working tree, on the branch that is already checked out — **provided that branch is not the repository's main
branch**.

**Always check the branch before deciding.** Immediately before any implementation work begins, run `git rev-parse --abbrev-ref HEAD` to read the branch that is actually
checked out right now, and `git symbolic-ref --short refs/remotes/origin/HEAD` (falling back to `main`, then `master`) to identify the repository's main branch. Never
rely on memory, on an earlier check in the same session, or on what a plan file says the branch is — re-run the check every time.

**If the current branch is not the main branch:**

- Work in place on it.
- Do **not** create a new branch.
- Do **not** switch branches.

**If the current branch is the main branch:**

- Create a new branch off it first — `git checkout -b <descriptive-branch-name>` — and state the branch name being created.
- Then work in place on that new branch for the remainder of the work.
- Do this once, before the first change; do not branch again mid-work.

**In both cases:**

- Do **not** create or use a git worktree.
- Do **not** commit to a detached HEAD.
- Do **not** merge branches.

Plans must not contain a step that switches to an existing branch or merges branches, and must not assume the work lands on some other pre-existing branch. The only
branch creation a plan may contain is the "branch off main if currently on main" step above, which must be preceded by an explicit branch check. If a plan's work
genuinely appears to belong on a different existing branch, stop and surface that to the user rather than switching branches.

---

## 3. Test with the repository's own tooling — no bespoke harnesses

Verification uses what the repository already provides. Discover the project's test framework, runner command, base test case, factories/fixtures, and assertion helpers,
then write tests that fit them.

**Required:**

- Tests live in the repository's existing test directories and follow its existing test naming, structure, and base classes.
- Tests are run with the project's own runner command (e.g. `vendor/bin/pest --parallel`, `phpunit`, `dotnet test`, `npm test`) — whatever the repo actually uses.
- Verification runs the suite **scoped to the module (s) the slice touched — never the whole-repo suite**. When a slice spans several modules, run each touched module's
  suite separately. Keep the runner's own parallel flag; the only sanctioned parallelism is inside the test runner, never across agents.
- New test dependencies are added only when the repository has no existing way to cover the case, and the plan states why.

**Forbidden — these are the "useless test harnesses" this rule exists to stop:**

- Throwaway driver scripts, scratch `main()` runners, one-off `verify.php` / `check.js` / `tmp_test.*` files written just to prove a change works.
- Custom assertion helpers, mini test runners, or bespoke mocking layers that duplicate what the project's framework already provides.
- Standalone sandbox projects, scratch directories, or parallel harness apps created outside the repository's normal test layout.
- Tests written purely to satisfy a coverage box that assert nothing meaningful about behavior.

**If the repository has no test tooling at all:** say so explicitly in the plan and describe how the slice will be verified using what does exist (the app's own run
command, an existing CLI entry point, a lint/build step). Do not invent a test framework or scaffold a harness to fill the gap without the user asking for one.
