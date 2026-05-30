# Build Lua provisioner library

## Dependencies

**Blocked by:** none
**Blocks:** 03-populate-manifest-and-configurators.md

---

## Context

The Dotfiles Tooling Modernization plan replaces the parallel `install.sh` / `install.ps1` per-tool installer
codepaths with a Lua-based provisioner driven by a single declarative manifest. This sub-plan creates the
provisioner runtime (entry point + library modules) but leaves the manifest empty so the next sub-plan can
populate it.

After this sub-plan, `lua provision/main.lua mac` runs through the dispatch loop against an empty manifest and
exits cleanly. The shell loader migration (sub-plan 05) is independent of this work.

### DF_ROOT_DIRECTORY resolution (used everywhere)

Every entrypoint resolves `DF_ROOT_DIRECTORY` the same way: honor the existing env var if set; otherwise fall back
to `$HOME/Documents/GitHub/dotfiles`. The Lua provisioner uses this rule too:

```lua
-- provision/lib/platform.lua
function M.dotfiles_root()
  return os.getenv("DF_ROOT_DIRECTORY") or (os.getenv("HOME") .. "/Documents/GitHub/dotfiles")
end
```

### Idempotency state shape

`~/.df_data/state.json`:

```json
{
  "schema_version": 1,
  "tools_installed":   { "gh": true, "1password": true },
  "configurators_run": { "iterm": "2026-05-29T10:00:00Z" },
  "migrations_run":    {
    "20250830_124338_setup_df_data_directory": "2026-05-29T10:00:00Z",
    "private:20250101_000000_some_private_migration": "imported"
  }
}
```

Source-of-truth rules the library must implement:

- **Tools**: provisioner queries the live backend on each run (`brew list`, `brew list --cask`, `choco list <id>
  --exact --limit-output`); `state.tools_installed` is an optimization, not the source of truth.
- **Configurators**: `state.configurators_run` *is* the source of truth (timestamp only — no version field).
  One-shot semantics; never re-run automatically once present.
- **Migrations**: `state.migrations_run` *is* the source of truth. Public migrations key on bare name;
  private-repo migrations key with a `private:` prefix.
- **Scripts**: not tracked in `state.json`. Re-run every provision.

### Failure handling

Provisioner accumulates failures rather than stopping. For each tool / script / configurator that throws or
returns non-zero from `os.execute`:

- Log the failure via `log.error(name, msg)`.
- Record it in an in-memory `failures` list (not in `state.json`).
- Continue to the next entry.

At end of run, print a summary table (counts: installed, skipped-already-present, failed). If `#failures > 0`,
exit with code 1 so the calling shell stub propagates failure; otherwise exit 0.

**Migrations are the one exception**: a migration failure stops further migration execution. Tools, scripts, and
configurators are independent and continue past failures.

### Lua runtime requirement

Target Lua 5.4 (the version Homebrew and Chocolatey install). Avoid features removed in 5.4 (`unpack` →
`table.unpack`, no implicit string→number coercion in arithmetic edge cases). LuaJIT compatibility not required.
No third-party deps beyond the vendored `provision/lib/vendor/json.lua` (rxi/json.lua, MIT).

---

## Steps

1. **Create provision scaffolding.**
   - Create `provision/` directory with subdirs `lib/`, `lib/vendor/`, `configurators/`, `migrations/`.
   - Create empty `provision/main.lua` and `provision/manifest.lua` (just `return {}` for now in
     `manifest.lua` — the next sub-plan populates it).
   - Vendor `rxi/json.lua` at `provision/lib/vendor/json.lua` — pin to the latest tagged release at vendoring
     time; write the upstream URL, license, and pinned commit SHA into a new `provision/lib/vendor/README.md`.

2. **Write `provision/lib/platform.lua`.**
   - Detect platform: read first CLI arg of `main.lua` (`mac` or `win`/`windows`), validate against allowlist.
   - Expose helpers: `is_mac()`, `is_windows()`, `home()`, `dotfiles_root()` (env-var-with-fallback per Context),
     `data_dir()` (= `$HOME/.df_data`).

3. **Write `provision/lib/log.lua`.**
   - Functions: `info`, `warn`, `error`, `ok`, `step`.
   - Use ANSI colors if `io.stdout:isatty()` returns true and `$NO_COLOR` unset.

4. **Write `provision/lib/state.lua`.**
   - Load/save `~/.df_data/state.json` using the vendored `provision/lib/vendor/json.lua`.
   - API: `state.load()`, `state.save(s)`, `state.mark_done(s, category, name)`, `state.has_run(s, category, name)`.
   - Create `~/.df_data/` if missing.

5. **Write `provision/lib/backend.lua`.**
   - Backends: `brew`, `cask`, `choco`.
   - Each implements `is_installed(id, app_path?)` and `install(id, opts)`.
   - `brew.is_installed` runs `brew list --formula 2>/dev/null | grep -qx <id>` (and `brew list --cask` for casks).
   - `choco.is_installed` runs `choco list <id> --exact --limit-output` (Choco v2 syntax — fixes the broken
     `--local-only` flag in the current `install.ps1`).
   - `brew.install` calls `brew tap <tap>` first when `opts.tap` is set, then `brew install <id>`.
   - When `opts.app` is set for cask backend, the absolute `.app` path acts as a pre-install existence check;
     mirrors the current `install_tool` behavior in `install.sh:15`.

6. **Write `provision/lib/scripts.lua`.**
   - One function: `run(entry)`. Given `{ kind="curl", url=..., pipe_to=... }`, execute
     `os.execute("curl -fsSL " .. url .. " | " .. pipe_to)`.
   - No state lookup, no state write. Always runs.

7. **Write `provision/lib/migrations.lua`.**
   - Exposes `run_pending(state)`. Migration modules return a table
     `{ description = "...", up = function() ... end }`.
   - Discover modules by name from `manifest.migrations`, `require` them, run `up()` if not in
     `state.migrations_run` (matched by bare name; the `private:` prefix is a recorded convention but the runner
     doesn't apply it itself — that is done by the legacy-history-import migration in sub-plan 03).
   - On success, stamp `state.migrations_run[name] = iso_timestamp()`.
   - On error, log and **stop** (do not continue past a failed migration).

8. **Write `provision/main.lua`.**
   - `package.path` extended to include `provision/?.lua;provision/?/init.lua`.
   - Args: `<platform> [--tools-only|--scripts-only|--configurators-only|--migrate]`.
   - Default: run tools, then scripts, then configurators, then migrations.
   - For each tool entry matching platform: `backend.install` if not `is_installed`.
   - For each script entry matching platform: `scripts.run` (always re-runs; relies on installer idempotency).
   - For each configurator entry matching platform: run module if not in `state.configurators_run`. Stamp on
     success.
   - For each migration: delegate to `lib.migrations.run_pending(state)`.
   - Implement failure-accumulation rules from Context.
   - Print summary table at end (counts of installed / skipped / failed). Exit 0 if no failures, 1 otherwise.

---

## Acceptance Criteria

- `provision/` directory tree exists with `main.lua`, `manifest.lua`, `lib/`, `lib/vendor/`, `configurators/`,
  `migrations/`. `lib/vendor/json.lua` is in place, MIT-licensed, with a `lib/vendor/README.md` recording the
  upstream URL and pinned commit SHA.
- `lua provision/main.lua mac` exits 0 against the empty manifest and prints a summary with zero counts in every
  category (no tools, no scripts, no configurators, no migrations).
- `lua provision/main.lua windows` exits 0 the same way.
- `lua provision/main.lua linux` (or any other invalid platform) exits non-zero with a clear error message
  from `platform.lua`'s allowlist validation.
- `~/.df_data/state.json` is created on first run with `schema_version: 1` and empty `tools_installed` /
  `configurators_run` / `migrations_run` maps.
- A second run of `lua provision/main.lua mac` is a no-op and exits 0.
- Each library module loads via `require` without error: `lua -e 'require("provision.lib.platform"); require
  ("provision.lib.log"); require("provision.lib.state"); require("provision.lib.backend"); require("provision.lib
  .scripts"); require("provision.lib.migrations")'` exits 0.
