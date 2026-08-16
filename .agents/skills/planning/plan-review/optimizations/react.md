# React Optimization Pass

## 5a — Detect React

Read `package.json` at the repo root and any workspace `package.json` files (exclude `node_modules/`). Classify:

| Signal                                                         | Result                      |
|----------------------------------------------------------------|-----------------------------|
| `"react"` in `dependencies` or `devDependencies`               | **React — continue**        |
| No `package.json`, or no `react` in any workspace package.json | **Not React — skip Step 5** |

Detection is done by the caller when the TanStack check did **not** match, so if you reached this file, React is present
and TanStack is not. Continue.

## 5b–5d — Run the common procedure

Follow `~/.claude/skills/plan-review/optimizations/_common.md` with these parameters:

- `{{OPTIMIZATION_SKILL}}` = `react-optimization`
- `{{PATH_NOUN}}` = `project`
- `{{DISCARD_PATHS}}` = `node_modules/`, `dist/`, `.next/`, `vendor/`, `*.test.*` / `*.spec.*` paths
- `{{FIX_EXAMPLES}}` = extract an inline component to module scope, replace `.sort(` on props with `toSorted()`, lazy-load
  a heavy editor with `React.lazy`
- `{{AUDIT_LABEL}}` = `React performance audit`
- `{{EXTRA_STEPS}}` = (no stack-specific steps)
