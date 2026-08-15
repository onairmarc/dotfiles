# Optimization Pass — Common Procedure

The shared 5b–5d procedure for every stack-specific optimization pass. Each stack file (`laravel.md`, `cs.md`, `avalonia.md`) runs its own
`5a` detection, sets the handful of parameters below, then follows this procedure. Wherever a `{{PARAM}}` appears, substitute the value the stack file provides:

| Parameter                | Meaning                                                                            |
|--------------------------|------------------------------------------------------------------------------------|
| `{{OPTIMIZATION_SKILL}}` | The optimization skill to invoke (e.g. `laravel-optimization`).                    |
| `{{PATH_NOUN}}`          | What a scanned path is called for this stack — `module` or `project`.              |
| `{{DISCARD_PATHS}}`      | The build/vendor/generated directories to drop when collecting paths.              |
| `{{FIX_EXAMPLES}}`       | Two or three representative fixes, used in the `> ⚠ Performance note:` examples.  |
| `{{AUDIT_LABEL}}`        | The label for the no-issues note (e.g. `Laravel performance audit`).               |
| `{{EXTRA_STEPS}}`        | Optional stack-specific incorporation steps; omit if the stack file declares none. |

---

## 5b — Extract explicit paths from the plan

Re-read the final (enriched) plan file. Collect every **directory or file path** that appears in implementation steps — anything that looks like a source path.
Deduplicate and discard:

- `{{DISCARD_PATHS}}`
- `tests/` paths (test files, not source)
- Any path that does not exist on disk (`Bash(test -f *)`)

If no valid source paths survive, use the most specific directory the plan targets overall. **Never pass an empty or repo-root path** —
`{{OPTIMIZATION_SKILL}}` scanning the entire repo defeats the purpose.

## 5c — Invoke `{{OPTIMIZATION_SKILL}}`

Spawn an `Agent` sub-agent with **`model: opus`** for each unique top-level `{{PATH_NOUN}}` path extracted in 5b. Use this prompt (fill in the bracketed values):

```
Run the {{OPTIMIZATION_SKILL}} skill on `<{{PATH_NOUN}}-path>`.
Context: this audit follows a plan-review pass on `<plan-file-path>`.
Do NOT invoke feature-planning or write to any plan file.
Return your full structured audit findings so the caller can incorporate them into the reviewed plan.
```

Pass the `{{PATH_NOUN}}` directory, not an individual file. If the plan spans multiple unrelated `{{PATH_NOUN}}` directories, spawn one Agent per directory — do not
combine unrelated paths into a single invocation. Collect all sub-agent results before proceeding to 5d.

## 5d — Incorporate findings into the reviewed plan

After `{{OPTIMIZATION_SKILL}}` completes, read its audit results (the structured findings it emits before handing off to feature-planning). Then re-open the plan file you
have been enriching and incorporate the performance findings directly into it — do **not** leave them in a separate optimization plan file.

**How to incorporate:**

1. Locate the implementation steps section of the reviewed plan.
2. For each `{{OPTIMIZATION_SKILL}}` finding that applies to code touched by the plan:
    - If the plan already has a step that modifies the affected file/method, **annotate that step** with a `> ⚠ Performance note:`
      blockquote describing the issue and the required fix (e.g. {{FIX_EXAMPLES}}).
    - If no existing step covers the affected code, **add a new numbered step** in the appropriate phase that addresses the finding. Follow the same step format used
      elsewhere in the plan (file path, before/after code snippet).
3. {{EXTRA_STEPS}}
4. Write the updated plan back to disk with `Edit` (or `Write` if a full rewrite is cleaner).
5. Re-read the updated plan and confirm no new ambiguities were introduced by the additions. If any were, resolve them as much as you can on your own and use the
   `AskUserQuestion` tool for any that you cannot.

If `{{OPTIMIZATION_SKILL}}` found **no issues**, add a single note at the bottom of the plan:

```markdown
> **{{AUDIT_LABEL}}:** no issues found in the scanned paths.
```

Then write the plan and proceed to the final summary.
