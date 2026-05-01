# Laravel Optimization Pass

## 5a — Detect Laravel

Read `composer.json` at the repo root (use `Bash(cat *)` or `Read`). Classify:

| Signal                                                      | Result                        |
|-------------------------------------------------------------|-------------------------------|
| `"laravel/framework"` in `require` or `require-dev`         | **Laravel Application**       |
| `"type": "library"` AND any `laravel/` package in `require` | **Laravel Package**           |
| Neither                                                     | **Not Laravel — skip Step 5** |

If `composer.json` does not exist, skip Step 5.

## 5b — Extract explicit paths from the plan

If Laravel is detected, re-read the final (enriched) plan file. Collect every **directory or file path** that
appears in implementation steps — anything that looks like a source path (e.g. `app/Services/Foo`,
`src/Http/Controllers`, `packages/my-package/src`). Deduplicate and discard:

- `vendor/`
- `node_modules/`
- `tests/` paths (test files, not source)
- Migration file paths (already handled by `no-db-constraints`)
- Any path that does not exist on disk (`Bash(test -f *)`)

If no valid source paths survive, use the most specific directory the plan targets overall (e.g. `app/` for an
application plan, `src/` for a package). **Never pass an empty or repo-root path** — laravel-optimization
scanning the entire codebase defeats the purpose.

## 5c — Invoke laravel-optimization

Call `Skill(laravel-optimization)` once per unique top-level module path extracted in 5b. Pass:

```
<module-path> [extra context: this audit follows a plan-review pass on <plan-file-path>]
```

Example: if the plan touches `app/Services/Billing` and `app/Http/Controllers/BillingController.php`, pass
`app/Services/Billing` as the module path (the directory, not the individual file).

If the plan spans multiple unrelated module directories, invoke the skill once per directory. Do not combine
unrelated paths into a single invocation.

## 5d — Incorporate findings into the reviewed plan

After laravel-optimization completes, read its audit results (the structured findings it emits before handing off
to feature-planning). Then re-open the plan file you have been enriching and incorporate the performance findings
directly into it — do **not** leave them in a separate optimization plan file.

**How to incorporate:**

1. Locate the implementation steps section of the reviewed plan.
2. For each laravel-optimization finding that applies to code touched by the plan:
    - If the plan already has a step that modifies the affected file/method, **annotate that step** with a
      `> ⚠ Performance note:` blockquote describing the issue and the required fix (e.g. add eager loading, wrap in
      `Cache::remember`, use `->exists()` instead of `->count() > 0`).
    - If no existing step covers the affected code, **add a new numbered step** in the appropriate phase that
      addresses the finding. Follow the same step format used elsewhere in the plan (file path, before/after code
      snippet).
3. If laravel-optimization found DB constraint violations, add a step instructing the agent to run
   `/no-db-constraints <migration-file-path>` for each affected migration — place it before any step that seeds
   or queries the constrained table.
4. Write the updated plan back to disk with `Edit` (or `Write` if a full rewrite is cleaner).
5. Re-read the updated plan and confirm no new ambiguities were introduced by the additions. If any were, resolve
   them as much as you can on your own and use the `AskUserQuestion` tool for any that you cannot.

If laravel-optimization found **no issues**, add a single note at the bottom of the plan:

```markdown
> **Laravel performance audit:** no issues found in the scanned module paths.
```

Then write the plan and proceed to the final summary.