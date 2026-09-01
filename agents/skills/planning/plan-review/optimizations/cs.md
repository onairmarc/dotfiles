# C# Optimization Pass

This pass audits general .NET patterns: async/await, LINQ, memory allocation, DI lifetimes, concurrency, and exception handling. It applies to **all** C# projects,
including Avalonia ones — the Avalonia pass covers UI-specific patterns that this pass does not. Detection is done by the caller (any `.csproj` that did not match the
Avalonia check), so there is no `5a` step here.

## 5b–5d — Run the common procedure

Follow `~/.config/opencode/skills/plan-review/optimizations/_common.md` with these parameters:

- `{{OPTIMIZATION_SKILL}}` = `cs-optimization`
- `{{PATH_NOUN}}` = `project`
- `{{DISCARD_PATHS}}` = `bin/`, `obj/`, `*.Tests/` paths
- `{{FIX_EXAMPLES}}` = replace `.Wait()` with `await`, use `TryGetValue` instead of a double lookup, wrap `IDisposable` in `using`
- `{{AUDIT_LABEL}}` = `C# performance audit`
- `{{EXTRA_STEPS}}` = (no stack-specific steps)
