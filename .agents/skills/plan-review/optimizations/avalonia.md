# Avalonia Optimization Pass

## 5a — Confirm Avalonia

You have already detected at least one `.csproj` containing an Avalonia `PackageReference` or
`<UseAvalonia>true</UseAvalonia>`. No further detection needed — continue.

## 5b — Extract explicit paths from the plan

Re-read the final (enriched) plan file. Collect every **directory or file path** that appears in implementation
steps — anything that looks like an Avalonia source path (e.g. `src/MyApp`, `src/MyApp.Desktop`,
`src/Views`, `src/ViewModels`). Deduplicate and discard:

- `bin/`, `obj/`
- `tests/` or `*.Tests/` paths (test files, not source)
- Any path that does not exist on disk (`Bash(test -f *)`)

If no valid source paths survive, use the most specific directory the plan targets overall (e.g. `src/` or the
project folder). **Never pass an empty or repo-root path** — avalonia-optimization scanning the entire repo
defeats the purpose.

## 5c — Invoke avalonia-optimization

Spawn an `Agent` sub-agent with **`model: opus`** for each unique top-level project path extracted in 5b. Use
this prompt (fill in the bracketed values):

```
Run the avalonia-optimization skill on `<project-path>`.
Context: this audit follows a plan-review pass on `<plan-file-path>`.
Do NOT invoke feature-planning or write to any plan file.
Return your full structured audit findings so the caller can incorporate them into the reviewed plan.
```

Example: if the plan touches `src/MyApp/Views/MainView.axaml` and `src/MyApp/ViewModels/MainViewModel.cs`,
pass `src/MyApp` as the project path (the project directory, not the individual files).

If the plan spans multiple unrelated project directories, spawn one Agent per directory. Do not combine
unrelated paths into a single invocation. Collect all sub-agent results before proceeding to 5d.

## 5d — Incorporate findings into the reviewed plan

After avalonia-optimization completes, read its audit results (the structured findings it emits before handing
off to feature-planning). Then re-open the plan file you have been enriching and incorporate the performance
findings directly into it — do **not** leave them in a separate optimization plan file.

**How to incorporate:**

1. Locate the implementation steps section of the reviewed plan.
2. For each avalonia-optimization finding that applies to code touched by the plan:
    - If the plan already has a step that modifies the affected file/method, **annotate that step** with a
      `> ⚠ Performance note:` blockquote describing the issue and the required fix (e.g. add
      `VirtualizingStackPanel`, replace `Opacity=0` with `IsVisible`, unsubscribe event handlers in `Unloaded`,
      offload CPU work via `Task.Run`).
    - If no existing step covers the affected code, **add a new numbered step** in the appropriate phase that
      addresses the finding. Follow the same step format used elsewhere in the plan (file path, before/after code
      snippet or AXAML diff).
3. Write the updated plan back to disk with `Edit` (or `Write` if a full rewrite is cleaner).
4. Re-read the updated plan and confirm no new ambiguities were introduced by the additions. If any were, resolve
   them as much as you can on your own and use the `AskUserQuestion` tool for any that you cannot.

If avalonia-optimization found **no issues**, add a single note at the bottom of the plan:

```markdown
> **Avalonia performance audit:** no issues found in the scanned project paths.
```

Then write the plan and proceed to the final summary.