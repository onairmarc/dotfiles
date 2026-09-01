# TanStack Optimization Pass

## 5a — Confirm TanStack

You have already detected at least one `@tanstack/react-query`, `@tanstack/react-table`, `@tanstack/react-router`,
`@tanstack/react-form`, or `@tanstack/react-virtual` (or the matching `*-core`) dependency in a `package.json`. No further detection needed — continue.

## 5b–5d — Run the common procedure

Follow `~/.config/opencode/skills/plan-review/optimizations/_common.md` with these parameters:

- `{{OPTIMIZATION_SKILL}}` = `tanstack-optimization`
- `{{PATH_NOUN}}` = `project`
- `{{DISCARD_PATHS}}` = `node_modules/`, `dist/`, `.next/`, `vendor/`, `*.test.*` / `*.spec.*` paths
- `{{FIX_EXAMPLES}}` = hoist `new QueryClient()` out of render, add the missing value to `queryKey`, memoize `columns` /
  `data` for `useReactTable`, virtualize or paginate unbounded rows
- `{{AUDIT_LABEL}}` = `TanStack performance audit`
- `{{EXTRA_STEPS}}` = (no stack-specific steps)

The TanStack pass internally calls `react-optimization --audit-only` and merges both sets of findings, so do not also run `react.md` when this pass matched.
