# Avalonia Optimization Pass

## 5a — Confirm Avalonia

You have already detected at least one `.csproj` containing an Avalonia `PackageReference` or `<UseAvalonia>true</UseAvalonia>`. No further
detection needed — continue.

## 5b–5d — Run the common procedure

Follow `~/.claude/skills/plan-review/optimizations/_common.md` with these parameters:

- `{{OPTIMIZATION_SKILL}}` = `avalonia-optimization`
- `{{PATH_NOUN}}` = `project`
- `{{DISCARD_PATHS}}` = `bin/`, `obj/`, `*.Tests/` paths
- `{{FIX_EXAMPLES}}` = add `VirtualizingStackPanel`, replace `Opacity=0` with `IsVisible`, unsubscribe event handlers in `Unloaded`,
  offload CPU work via `Task.Run`
- `{{AUDIT_LABEL}}` = `Avalonia performance audit`
- `{{EXTRA_STEPS}}` = (no stack-specific steps)

The Avalonia pass internally calls `cs-optimization --audit-only` and merges both sets of findings, so do not also run `cs.md` when this
pass matched.
