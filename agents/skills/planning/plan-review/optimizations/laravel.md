# Laravel Optimization Pass

## 5a — Detect Laravel

Read `composer.json` at the repo root (use `Bash(cat *)` or `Read`). Classify:

| Signal                                                      | Result                        |
|-------------------------------------------------------------|-------------------------------|
| `"laravel/framework"` in `require` or `require-dev`         | **Laravel Application**       |
| `"type": "library"` AND any `laravel/` package in `require` | **Laravel Package**           |
| Neither                                                     | **Not Laravel — skip Step 5** |

If `composer.json` does not exist, skip Step 5.

## 5b–5d — Run the common procedure

Follow `~/.config/opencode/skills/plan-review/optimizations/_common.md` with these parameters:

- `{{OPTIMIZATION_SKILL}}` = `laravel-optimization`
- `{{PATH_NOUN}}` = `module`
- `{{DISCARD_PATHS}}` = `vendor/`, `node_modules/`, migration file paths (already handled by `no-db-constraints`)
- `{{FIX_EXAMPLES}}` = add eager loading, wrap in `Cache::remember`, use `->exists()` instead of `->count() > 0`
- `{{AUDIT_LABEL}}` = `Laravel performance audit`
- `{{EXTRA_STEPS}}` = If `laravel-optimization` found DB constraint violations, add a step instructing the agent to run
  `/no-db-constraints <migration-file-path>` for each affected migration — placed before any step that seeds or queries the constrained
  table.
