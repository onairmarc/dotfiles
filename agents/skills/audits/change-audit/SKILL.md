---
name: change-audit
author: Marc Beinder
description: "Change-scoped audit: validates, dedupes, ranks, and implements fixes for code changed on the current branch"
---

Audit every file changed on the current branch for materially useful simplifications in data structures, state representation, control flow, algorithms, and ownership —
then implement the accepted fixes.

You are the coordinator. Continue until every changed subsystem has been reviewed, validated, and fixed where appropriate.

# 0. Determine the change set

Identify the base branch this branch diverged from (typically `main` or `master`). Run:

```
git diff --name-only --diff-filter=d $(git merge-base HEAD <base-branch>)..HEAD
```

This produces the complete list of changed files. Group them into logical subsystems by directory, namespace, or functional area. Files that do not contain auditable
source code (images, lockfiles, migrations, generated files) should be noted and skipped.

If the branch has no changed files compared to the base, stop and report that there is nothing to audit.

# 1. Establish the coverage contract

From the changed-file list, inventory every affected subsystem.

Read [`audit-commons/inventory.md`](../audit-commons/inventory.md) for the subsystem fields, status values, and scratchpad structure. Scope ownership boundaries to the
changed files, but read unchanged neighbors for context.

# 2. Run bounded subsystem reviews

Read [`audit-commons/worker-brief.md`](../audit-commons/worker-brief.md) for dispatch rules, the worker brief, and the output schema.

**Scope qualifier — prepend to each worker's brief:** "Focus on the changed files. Read unchanged neighboring files for context, but only recommend changes to code that
was already modified on this branch."

# 3. Validate and synthesize

Read [`audit-commons/validation.md`](../audit-commons/validation.md) and follow the validation and synthesis pass.

# 4. Audit the audit

Read [`audit-commons/validation.md`](../audit-commons/validation.md) and follow the audit-the-audit pass. Scope the coverage check to the changed files — if the pass
finds a real omission within the change set, add an explicit subsystem row and audit it.

# 5. Implement the fixes

For each accepted recommendation, in priority order:

1. Trace the full callstack — every caller, callee, event listener, observer, and consumer the change touches — before writing any edit.
2. Implement the simplification. Edit only the minimum set of files required. Do not introduce unrelated changes.
3. Run the test suite scoped to the module (s) containing the changed files — never the whole-repo suite — plus static analysis, after each fix. When the change spans
   several modules, run each touched module's suite separately. If tests fail, fix the root cause — do not disable tests or suppress warnings.
4. Update the audit log with the fix applied status.

If a recommendation cannot be safely implemented without risking regression or requiring a user decision (ambiguous requirements, competing tradeoffs, destructive
actions), flag it to the user with full context via `question` instead of implementing.

# 6. Final verification

After all fixes are applied:

- Run the test suite scoped to the module (s) touched by the change — each touched module's suite separately when several — plus static analysis, one final time. Never
  the whole-repo suite.
- Verify no unrelated files were modified.
- Update the scratchpad with the final status of every subsystem row.

The audit is complete only when:

- every changed subsystem has been reviewed;
- every subsystem has a recommendation with an applied fix or explicit skip;
- every finding has complete evidence, scope, risk, and validation fields;
- duplicates and weak abstractions have been removed;
- priorities and dependencies are internally consistent;
- all tests and static analysis pass.
