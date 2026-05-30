# Dotfiles Tooling Modernization — Implementation Plan

## Goal

Replace the hand-rolled bash provisioning scripts (`install.sh`, `install.ps1`), the custom source-guard/autoloader
framework (`framework/source_guards.sh`, `framework/__df_autoloader.sh`, `framework/migration_optimizer.sh`,
`framework/migrations/`), and the parallel mac/windows install codepaths with:

1. A **Lua-based provisioner** driven by a single declarative manifest (`provision/manifest.lua`) that installs
   software, runs one-shot configurators, and tracks idempotency state. Mac/Windows divergence lives in manifest
   columns, not parallel script trees.
2. **antidote** as the Zsh plugin manager (replaces the custom `__df_source_once` autoloader on Zsh).
3. A **bash fallback loader** for environments without Zsh (Windows Git Bash / MSYS), preserving identical sourcing
   semantics so all existing functions and aliases keep working.

Success = (a) a fresh Mac or Windows machine provisioned by `bash install.sh` / `pwsh install.ps1` and a new shell with
every alias, function, env var, and prompt behavior currently in `config/*.sh` + `tools/*.sh` working byte-identically to
the current implementation, (b) adding a new tool is a one-line manifest edit, not two script edits, (c) the framework
directory is gone, replaced by `~50 lines` of bash loader + antidote plugin file.

## Out of scope

- Linux/WSL manifest support. Manifest schema must permit a `linux` column but no Linux entries are populated in this
  plan. Future work.
- Replacing or modifying user-facing shell commands. Every alias, function, env var, and prompt produced by the current
  `config/*.sh` and `tools/*.sh` must remain identical in name and behavior.
- Replacing Oh My Zsh. OMZ stays; antidote loads it as a plugin.
- Replacing Homebrew or Chocolatey as the underlying package backends.
- Rewriting `config/func.sh` contents. Its functions are preserved verbatim; only how the file is sourced changes.
- Cross-shell prompt unification. Whatever prompt OMZ currently produces is what the new system produces.
- Secrets management changes (1Password CLI usage stays as-is).

## Affected components

| Component / Module                                | Change type | Summary                                                                                                                |
|---------------------------------------------------|-------------|------------------------------------------------------------------------------------------------------------------------|
| `install.sh`                                      | Modified    | Reduced to ~30-line bootstrap: install brew, install Lua, exec `lua provision/main.lua mac`.                           |
| `install.ps1`                                     | Modified    | Reduced to ~30-line bootstrap: install choco, install Lua, exec `lua provision/main.lua windows`.                      |
| `provision/main.lua`                              | New         | Provisioner entrypoint. Parses platform arg, loads manifest, dispatches install + configurator + migration tasks.      |
| `provision/manifest.lua`                          | New         | Declarative table of tools, configurators, and one-shot migrations. Single source of truth for mac+windows install.    |
| `provision/lib/backend.lua`                       | New         | Package backend abstraction (`brew`, `cask`, `choco`) — `is_installed`, `install`, `tap`.                              |
| `provision/lib/state.lua`                         | New         | Idempotency state (`~/.df_data/state.json`) — `has_run`, `mark_done`.                                                  |
| `provision/lib/platform.lua`                      | New         | Platform detection (`mac`, `windows`) and OS-specific helpers (plist write, symlink, defaults).                        |
| `provision/lib/log.lua`                           | New         | Colored logging (info/warn/error/ok) reading from terminal color support.                                              |
| `provision/configurators/iterm.lua`               | New         | Replaces `configure_iterm` from `install.sh`.                                                                          |
| `provision/configurators/ghostty.lua`             | New         | Replaces `configure_ghostty` from `install.sh`.                                                                        |
| `provision/configurators/capslock.lua`            | New         | Replaces `remap_capslock_to_escape` (delegates to `tools/remap_capslock.sh`, kept).                                    |
| `provision/configurators/stripe_completion.lua`   | New         | Replaces inline stripe completion logic at end of `install.sh:197-204`.                                                |
| `provision/migrations/20250830_124338_setup_df_data_directory.lua` | New | Lua port of existing shell migration.                                                                                  |
| `provision/migrations/20250830_124630_move_sys_cleanup_marker.lua` | New | Lua port of existing shell migration.                                                                                  |
| `framework/__df_autoloader.sh`                    | Deleted     | Replaced by antidote (zsh) and `framework/bash_loader.sh` (bash fallback).                                             |
| `framework/source_guards.sh`                      | Deleted     | Replaced by antidote source-once semantics (zsh) and simple guard in `framework/bash_loader.sh` (bash).                |
| `framework/migration_optimizer.sh`                | Deleted     | Migrations run only from provisioner now, not at shell startup.                                                        |
| `framework/migrations/migrate.sh`                 | Deleted     | Replaced by `provision/lib/migrations.lua`.                                                                            |
| `framework/migrations/migration_helpers.sh`       | Deleted     | Replaced by `provision/lib/migrations.lua`.                                                                            |
| `framework/brew_cache.sh`                         | Deleted     | No longer needed; provisioner queries brew directly and shell startup does not touch brew.                             |
| `framework/logging_functions.sh`                  | Modified    | Trimmed to the functions actually used by surviving shell code (`log_error`, etc.). Sourced directly, no guard.        |
| `framework/bash_loader.sh`                        | New         | Bash fallback (~30 lines): when `$ZSH_VERSION` unset, source `config/*.sh` + `tools/*.sh` in fixed order.              |
| `entrypoint.sh`                                   | Modified    | Detect shell: if zsh, hand off to antidote (via `.zshrc`); if bash, source `framework/bash_loader.sh`.                 |
| `.zshrc`                                          | Modified    | Bootstraps antidote, sources `zsh_plugins.txt`, then sources `entrypoint.sh` for migrations/private dotfiles only.     |
| `zsh_plugins.txt`                                 | New         | antidote plugin bundle. Lists OMZ, autosuggestions, syntax-highlighting, then `path:config/`, `path:tools/`.           |
| `autoloader/mac.sh`                               | Deleted     | Its sourcing list moves into `zsh_plugins.txt` and `framework/bash_loader.sh`.                                         |
| `autoloader/windows.sh`                           | Deleted     | Same.                                                                                                                  |
| `startup/mac.sh`                                  | Modified    | Logic merged into `provision/configurators/` if provisioning, or `config/mac.sh` if runtime. Audit on implementation.  |
| `tools/mac_cleanup.sh` (732 lines, vendored fork) | Unchanged   | Stays vendored. Not in scope for this plan; revisit in a follow-up.                                                    |
| `tools/mac_cleanup_checker.sh`                    | Renamed only | Renamed to `tools/30_mac_cleanup_checker.sh` per §4 ordering table. No logic change.                                  |
| `config/env.sh`                                   | Modified    | Strip hardcoded `/Users/marcbeinder/...` paths. Replace with `$HOME` where the layout is user-agnostic. Move user-specific Herd cert path and `NODE_EXTRA_CA_CERTS` to `dotfiles-private/.config/env.sh`. |
| `autoloader/mac.sh` hardcoded `NODE_EXTRA_CA_CERTS` | Deleted   | Moved to `dotfiles-private/.config/env.sh` (it is a per-machine, per-employer cert path).                              |
| `dotfiles-private/.config/env.sh`                 | Modified (sibling repo) | Receive Herd cert path + `NODE_EXTRA_CA_CERTS` exports. Sibling repo at `../dotfiles-private/`; already sourced via `autoloader/mac.sh:30`. |
| `README.md`                                       | Modified    | Update install instructions to reflect new bootstrap flow.                                                             |
| `.gitignore`                                      | Modified    | Add `.DS_Store`, `.idea/`. Remove tracked instances in a separate commit within step 26.                               |

## Architecture

### 1. Two-stage bootstrap: shell stub → Lua provisioner

```
User runs:  bash install.sh                    (or)  pwsh install.ps1
              │                                         │
              ▼                                         ▼
       [Stage 1: stub]                            [Stage 1: stub]
       - Install Homebrew if missing              - Install Chocolatey if missing
       - brew install lua git                     - choco install lua git -y
       - exec lua provision/main.lua mac          - exec lua provision/main.lua windows
              │                                         │
              ▼                                         ▼
       [Stage 2: Lua provisioner — identical entrypoint, platform passed as arg]
       - Load provision/manifest.lua
       - For each tool entry matching platform: backend.install if not already_installed
       - For each configurator entry matching platform: run module
       - For each migration not in state.json: run module, mark done
       - Write/update ~/.df_data/state.json
```

Stub scripts contain **no per-tool logic**. They cannot drift between platforms because they install the same three
things (package manager, Lua, Git) and then hand off.

### 2. Manifest schema

`provision/manifest.lua` returns a single table:

```lua
return {
  tools = {
    { name = "1password",
      mac  = { backend = "cask",  id = "1password", app = "/Applications/1Password.app" },
      win  = { backend = "choco", id = "1password" } },
    { name = "gh",
      mac  = { backend = "brew",  id = "gh" },
      win  = { backend = "choco", id = "gh" } },
    { name = "trivy",
      mac  = { backend = "brew",  id = "trivy" } },                  -- mac-only
    -- ...
  },

  scripts = {                                                        -- external installers (curl | bash style)
    { name = "opencode",
      mac  = { kind = "curl", url = "https://opencode.ai/install", pipe_to = "bash" },
      win  = nil },
    { name = "bun",
      mac  = { kind = "curl", url = "https://bun.com/install",     pipe_to = "bash" } },
    { name = "syft",
      mac  = { kind = "curl", url = "https://get.anchore.io/syft",
               pipe_to = "sudo sh -s -- -b /usr/local/bin" } },
  },

  configurators = {                                                  -- one-shot config writes; idempotent
    { name = "iterm",   module = "configurators.iterm",   platforms = { "mac" } },
    { name = "ghostty", module = "configurators.ghostty", platforms = { "mac" } },
    { name = "capslock",module = "configurators.capslock",platforms = { "mac" } },
    { name = "stripe_completion", module = "configurators.stripe_completion", platforms = { "mac", "win" } },
  },

  migrations = {                                                     -- ordered, run-once
    "migrations.20250830_124338_setup_df_data_directory",
    "migrations.20250830_124630_move_sys_cleanup_marker",
  },
}
```

A new tool = one line in `tools`. Mac-only tools omit `win`. The provisioner iterates and dispatches.

### 3. Idempotency state

`~/.df_data/state.json` shape:

```json
{
  "schema_version": 1,
  "tools_installed": { "gh": true, "1password": true },
  "configurators_run": { "iterm": "2026-05-29T10:00:00Z" },
  "migrations_run":    { "20250830_124338_setup_df_data_directory": "2026-05-29T10:00:00Z" }
}
```

For tools, the provisioner additionally queries the live backend (`brew list`, `choco list`) on each run; `state.json`
is an optimization, not the source of truth (so removing a tool out-of-band re-installs it next provision).
For configurators and migrations, `state.json` *is* the source of truth — they are one-shot.

Existing `migrations/.migration_history` (line-per-name file) is migrated into `state.json` by migration
`20251201_000000_import_legacy_migration_history.lua` (step 11). The legacy file is then deleted.

### 4. Shell startup: zsh path (antidote)

`.zshrc` becomes:

```sh
export DF_ROOT_DIRECTORY="$HOME/Documents/GitHub/dotfiles"
export DF_DATA_DIR="${DF_DATA_DIR:-$HOME/.df_data}"

# antidote bootstrap (installed by provisioner as `brew install antidote`)
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load "$DF_ROOT_DIRECTORY/zsh_plugins.txt"

# Conditionally load private dotfiles
[ -f "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh" ] && \
  source "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh"
```

`zsh_plugins.txt`:

```
ohmyzsh/ohmyzsh                                  # OMZ first (existing behavior)
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
$DF_ROOT_DIRECTORY path:config kind:path         # auto-sources config/*.sh in lexical order
$DF_ROOT_DIRECTORY path:tools  kind:path         # auto-sources tools/*.sh in lexical order
```

Sourcing order matches the current `autoloader/mac.sh` order. Filenames in `config/` and `tools/` are renamed where
necessary (prefix `00_`, `10_`, etc.) so lexical order equals the current explicit order. Concretely:

| Current order in `autoloader/mac.sh` | New filename                       |
|--------------------------------------|------------------------------------|
| `config/omz.sh`                      | `config/00_omz.sh`                 |
| `config/env.sh`                      | `config/10_env.sh`                 |
| `config/color.sh`                    | `config/20_color.sh`               |
| `config/alias.sh`                    | `config/30_alias.sh`               |
| `config/func.sh`                     | `config/40_func.sh`                |
| `tools/aws.sh`                       | `tools/10_aws.sh`                  |
| `tools/docker.sh`                    | `tools/20_docker.sh`               |
| `config/mac.sh`                      | `config/50_mac.sh`                 |
| `tools/mac_cleanup_checker.sh`       | `tools/30_mac_cleanup_checker.sh`  |
| `tools/nano.sh`                      | `tools/40_nano.sh`                 |
| `tools/stripe.sh`                    | `tools/50_stripe.sh`               |
| `config/tmux.sh`                     | `config/60_tmux.sh`                |

A `config/mac.sh` / `tools/mac_cleanup_checker.sh` / `tools/nano.sh` / `tools/stripe.sh` that are mac-only must guard
themselves internally with `is_mac || return 0` (the helpers are defined in `config/40_func.sh`, which always sources
first — verified). `config/40_func.sh` already defines `is_mac`, `is_windows`, `is_linux`.

OMZ's prompt and plugin selection are read by `config/00_omz.sh` exactly as today; antidote's load of `ohmyzsh/ohmyzsh`
is a no-op in that regard because `00_omz.sh` overrides `$ZSH` and re-runs `oh-my-zsh.sh`. **Verify on implementation
that ordering doesn't double-source OMZ; if it does, drop the `ohmyzsh/ohmyzsh` antidote line and let `00_omz.sh`
handle OMZ as today.** (See step 7.)

### 5. Shell startup: bash fallback (Git Bash / MSYS / non-zsh)

`entrypoint.sh` becomes:

```sh
if [ -n "$ZSH_VERSION" ]; then
  return 0   # .zshrc handles everything via antidote
fi
source "$DF_ROOT_DIRECTORY/framework/bash_loader.sh"
```

`framework/bash_loader.sh` (~30 lines):

```sh
#!/usr/bin/env bash
# Minimal source-once guard + ordered sourcing for non-zsh shells.
__df_loaded=":"
__df_source_once() {
  case "$__df_loaded" in *":$1:"*) return 0;; esac
  [ -f "$1" ] || return 1
  # shellcheck disable=SC1090
  source "$1"
  __df_loaded="$__df_loaded$1:"
}

for f in "$DF_ROOT_DIRECTORY"/config/[0-9]*_*.sh "$DF_ROOT_DIRECTORY"/tools/[0-9]*_*.sh; do
  __df_source_once "$f"
done

[ -f "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh" ] && \
  source "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh"
```

This file is the **entire** replacement for `framework/source_guards.sh` (139 lines), `framework/__df_autoloader.sh`
(50 lines), `autoloader/mac.sh` (35 lines), and `autoloader/windows.sh` (25 lines). Net deletion: ~219 lines.

Bash users (Git Bash on Windows) get the same set of files sourced in the same order. No antidote on Windows because
zsh on Windows is unreliable (the `choco install zsh` flow exists but is not the primary Windows shell). If a Windows
user does run Zsh under MSYS2 / WSL, antidote works there too because the `.zshrc` flow is OS-agnostic — only the
provisioner needs to know the OS.

### 6. Configurators: macOS plist writes etc.

Lua configurators use `os.execute` for `defaults write` / `PlistBuddy` / `ln -s` / `mkdir -p`. They are thin wrappers
around the existing shell snippets in `install.sh`. Translating bash → Lua here is mechanical; the goal is centralizing
the call site, not rewriting the commands. Each configurator records completion in `state.json` and re-runs only if
its `version` field (in the manifest entry) bumps.

`provision/configurators/capslock.lua` and any other configurator that delegates to a kept-as-shell tool (e.g.
`tools/remap_capslock.sh`) just `os.execute("bash " .. dotfiles_root .. "/tools/remap_capslock.sh --enable")`. The
script stays; Lua is the orchestrator.

### 6a. Failure handling

Provisioner accumulates failures rather than stopping. For each tool, script, configurator, or migration that throws
or returns non-zero from `os.execute`:

- Log the failure via `log.error(name, msg)`.
- Record it in an in-memory `failures` list (not in `state.json`).
- Continue to the next entry.

At end of run, print a summary table (counts: installed, skipped-already-present, failed). If `#failures > 0`, exit
with code 1 so the calling shell stub propagates failure; otherwise exit 0. Re-running the provisioner retries failed
entries because they were never marked done in `state.json`.

Migrations are the one exception: a migration failure stops further migration execution (a later migration may depend
on an earlier one's state). Tools and scripts and configurators are independent and continue past failures.

### 6b. Lua runtime requirement

Target Lua 5.4 (the version Homebrew and Chocolatey install). Code must avoid features removed in 5.4 (`unpack` →
`table.unpack`, no implicit string→number coercion in arithmetic edge cases). LuaJIT compatibility is not required.
No third-party deps beyond the vendored `provision/lib/vendor/json.lua` (rxi/json.lua, MIT).

### 7. Migrations in Lua

`provision/lib/migrations.lua` exposes `run_pending(state)`. Migration modules are Lua files in `provision/migrations/`
returning a table `{ description = "...", up = function() ... end }`. The runner:

1. Reads ordered list from `manifest.migrations`.
2. Skips entries already in `state.migrations_run`.
3. Calls `up()`. On success, stamps `state.migrations_run[name] = iso_timestamp()`.
4. On error, logs and stops (do not continue past a failed migration — current shell behavior continues silently; the
   new behavior is strictly safer).

Migrations are not invoked at shell startup. They run only when the user runs `lua provision/main.lua mac --migrate` or
the full `bash install.sh`. The user must accept that adding a new migration requires re-running the provisioner;
this is documented in `README.md`.

### 8. Stripping hardcoded user paths

`dotfiles-private` layout (verified from `../dotfiles-private/`): uses `.config/env.sh`, `.config/alias.sh`,
`.config/func.sh`, `.tools/github_token.sh`. Already sourced today via `autoloader/mac.sh:30` → `dotfiles-private/
entrypoint.sh` → individual `source` calls. After this plan, the same load path remains (zsh: via the private
entrypoint sourced from `.zshrc`; bash: via `framework/bash_loader.sh`).

Per-file changes:

- `config/env.sh:11` (`HERD_PHP_83_INI_SCAN_DIR`) — currently `/Users/marcbeinder/Library/Application Support/Herd/
  config/php/83/`. The Herd install layout is the same for every user, just under a different `$HOME`. **Change to
  `$HOME/Library/Application Support/Herd/config/php/83/`. Keep in dotfiles (not private)** because every Herd user
  has this same structure.
- `config/env.sh:55` (`_append_path_mac "/Users/marcbeinder/Library/Application Support/Herd/bin"`) — same reasoning;
  **change to `$HOME/...`. Keep in dotfiles.**
- `autoloader/mac.sh:26` (`NODE_EXTRA_CA_CERTS=".../Herd/config/valet/CA/LaravelValetCASelfSigned.pem"`) — this is a
  Marc-specific cert file generated by Marc's local Herd install. **Move to `dotfiles-private/.config/env.sh`**
  (append a single `export NODE_EXTRA_CA_CERTS="$HOME/Library/Application Support/Herd/config/valet/CA/
  LaravelValetCASelfSigned.pem"` line). The Herd path itself is generic, but exporting it depends on the user
  actually using Herd/Valet, which is workflow-specific — private repo is the right home.
- `$DF_ROOT_DIRECTORY` in `framework/__df_autoloader.sh:11` — already uses `$HOME`. After this plan, this line moves
  into `.zshrc` (zsh) and `framework/bash_loader.sh` (bash). No path hardcode reintroduced.

No other hardcoded `/Users/marcbeinder` paths exist in the public repo (verified by `grep -r '/Users/marcbeinder'
config/ tools/ framework/ autoloader/ install.sh`).

## Implementation steps

1. **Capture pre-change behavior snapshot.** Before any file rename or deletion, on the current working machine:

   ```sh
   {
     alias
     typeset -f | sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\) *() *{.*/\1/p' | sort -u
     echo "$PATH" | tr ':' '\n' | sort -u
     env | grep -E '^(DF_|HERD_|JAVA_|ANDROID_|XDEBUG_|HOMEBREW_|ZSH_|NODE_EXTRA_CA_CERTS|ANDROID_SDK_ROOT)=' | sort
   } > /tmp/dotfiles-baseline.txt
   ```

   Capture once in zsh and once in bash; save as `dotfiles-baseline-zsh.txt` and `dotfiles-baseline-bash.txt`.
   This is the regression oracle for steps 16 and 27-28.

2. **Create provision scaffolding.**
   - Create `provision/` directory with subdirs `lib/`, `lib/vendor/`, `configurators/`, `migrations/`.
   - Create empty `provision/main.lua` and `provision/manifest.lua`.
   - Vendor `rxi/json.lua` at `provision/lib/vendor/json.lua`.

3. **Write `provision/lib/platform.lua`.**
   - Detect platform: read first CLI arg of `main.lua` (`mac` or `win`), validate against allowlist.
   - Expose helpers: `is_mac()`, `is_windows()`, `home()`, `dotfiles_root()`, `data_dir()`.

4. **Write `provision/lib/log.lua`.**
   - Functions: `info`, `warn`, `error`, `ok`, `step`.
   - Use ANSI colors if `io.stdout:isatty()` returns true and `$NO_COLOR` unset.

5. **Write `provision/lib/state.lua`.**
   - Load/save `~/.df_data/state.json` using a vendored single-file JSON library
     (`provision/lib/vendor/json.lua` — use `rxi/json.lua`, MIT-licensed, ~280 lines).
   - API: `state.load()`, `state.save(s)`, `state.mark_done(s, category, name)`, `state.has_run(s, category, name)`.
   - Create `~/.df_data/` if missing.

6. **Write `provision/lib/backend.lua`.**
   - Backends: `brew`, `cask`, `choco`.
   - Each implements `is_installed(id, app_path?)` and `install(id, opts)`.
   - `brew.is_installed` runs `brew list --formula 2>/dev/null | grep -qx <id>` (and `brew list --cask` for casks).
   - `choco.is_installed` runs `choco list <id> --exact --limit-output` (Choco v2 syntax — fixes the broken
     `--local-only` flag in the current `install.ps1`).
   - `brew.install` handles `tap` option via `brew tap <tap_name>` first when set.

7. **Write `provision/lib/migrations.lua`.**
   - Discover modules by name from `manifest.migrations`, `require` them, run `up()` if not in `state.migrations_run`.

8. **Write `provision/main.lua`.**
   - `package.path` extended to include `provision/?.lua;provision/?/init.lua`.
   - Args: `<platform> [--tools-only|--configurators-only|--migrate]`.
   - Default: run tools, then scripts (curl | bash entries), then configurators, then migrations.
   - Print summary at end (counts of installed / skipped / failed).
   - **OMZ ordering verification**: after sourcing zsh_plugins.txt during dev test, run `echo $ZSH; type prompt`
     and confirm OMZ is loaded exactly once. If double-load detected, remove the `ohmyzsh/ohmyzsh` antidote line and
     update `zsh_plugins.txt`.

9. **Write `provision/manifest.lua`.**
   - Translate every `install_tool` call from `install.sh` and every `Install-ChocoTool` call from `install.ps1` into
     a single merged `tools` table. Use the current `install.sh` list as the master superset.
   - Translate the three `curl | bash`-style installers (OpenCode, Bun, Syft) into `scripts`.
   - List the four configurators in `configurators`.
   - List the two existing migrations in `migrations`, plus a new legacy-history-import migration.

10. **Port `configure_iterm`, `configure_ghostty`, `remap_capslock_to_escape`, and the inline stripe-completion block
   from `install.sh` into Lua modules under `provision/configurators/`.**
   - `iterm.lua`: replicates `install.sh:25-45`.
   - `ghostty.lua`: replicates `install.sh:47-66`.
   - `capslock.lua`: `os.execute("bash " .. root .. "/tools/remap_capslock.sh --enable")`.
   - `stripe_completion.lua`: replicates `install.sh:196-204`.

11. **Port the two existing shell migrations to Lua under `provision/migrations/`.**
    - Read each shell migration; translate its `mv`/`mkdir`/`rm` calls to Lua via `os.execute` or `lfs` (avoid adding
      `lfs` dependency — `os.execute` is sufficient and matches the shell migration style).
    - Test each migration's idempotency by running provisioner twice in a row and confirming no errors.

12. **Add `provision/migrations/20251201_000000_import_legacy_migration_history.lua`.**
    - Reads the in-repo `$DF_ROOT_DIRECTORY/migrations/.migration_history` file (line-per-migration-name flat file).
    - If `$DF_PRIVATE_DIRECTORY` is set and `$DF_PRIVATE_DIRECTORY/.migrations/.migration_history` exists, also reads
      that one and stamps under the `private` migration namespace in `state.json`.
    - For each line found, sets `state.migrations_run[name] = "imported"`.
    - Does not delete the legacy file (keep as audit trail; the new runner ignores it).

13. **Rewrite `install.sh` as ~30-line bootstrap.**
    - Install Homebrew if missing (existing block, copy verbatim).
    - `brew install lua git` if missing.
    - `cd "$DOTFILES_DIRECTORY" && exec lua provision/main.lua mac`.
    - Delete every `install_tool` line, `configure_*`, and inline curl block — they all live in Lua now.

14. **Rewrite `install.ps1` as ~30-line bootstrap.**
    - Install Chocolatey if missing (existing block, copy verbatim).
    - `choco install lua git -y` if missing.
    - `lua $DotfilesDirectory\provision\main.lua windows`.
    - Delete every `Install-ChocoTool` line.

15. **Add antidote to manifest** as a mac-only brew install (`{ name = "antidote", mac = { backend = "brew", id = "antidote" } }`).

16. **Create `zsh_plugins.txt` in repo root** with the contents from §4.

17. **Rewrite `.zshrc`** to the form in §4. Validate: open a new shell, run `type art`, `type pest`, `type tf_mode`,
    `type mac_cleanup`, `echo $PATH | tr : '\n' | sort -u`, `alias | wc -l` and compare to pre-change snapshot
    captured in step 1. Diff must be empty.

18. **Rewrite `entrypoint.sh`** to the form in §5 (zsh → return; bash → source `framework/bash_loader.sh`).

19. **Write `framework/bash_loader.sh`** as in §5.

20. **Rename `config/*.sh` and `tools/*.sh` to numeric-prefixed forms** per the table in §4. Use `git mv` so history is
    preserved. Verify each rename touches exactly one file.

21. **Add internal `is_mac || return 0` guards to every file Windows does not currently load.**
    Per `autoloader/windows.sh`, Windows currently sources only: `env`, `color`, `alias`, `func`, `aws`, `docker`.
    Every other file must short-circuit on non-mac to preserve current Windows behavior exactly. Guard targets:
    - `config/00_omz.sh` (zsh + OMZ — Windows bash has no zsh runtime; guard with `[ -n "$ZSH_VERSION" ] || return 0`
      rather than `is_mac` so Linux/WSL zsh users can also load it later).
    - `config/50_mac.sh` (`is_mac || return 0`).
    - `config/60_tmux.sh` (`is_mac || return 0`).
    - `tools/30_mac_cleanup_checker.sh` (`is_mac || return 0`).
    - `tools/40_nano.sh` (`is_mac || return 0`).
    - `tools/50_stripe.sh` (`is_mac || return 0`).

    Confirm `is_mac` is defined by the time these load: `config/40_func.sh` loads before any guarded file in the
    lexical order from §4. Verify by `grep -n 'is_mac' config/40_func.sh` after rename.

22. **Trim `framework/logging_functions.sh`** to only the functions referenced by surviving shell code. Source it
    directly from `config/40_func.sh` at top via plain `source` (no guard needed; loaded once by antidote/bash_loader).

23. **Delete framework files no longer needed.**
    Confirm with the user before deleting (per `.agents/AGENTS.md` file-operation rules). Targets:
    - `framework/__df_autoloader.sh`
    - `framework/source_guards.sh`
    - `framework/migration_optimizer.sh`
    - `framework/migrations/migrate.sh`
    - `framework/migrations/migration_helpers.sh`
    - `framework/brew_cache.sh`
    - `autoloader/mac.sh`
    - `autoloader/windows.sh`
    - The `autoloader/` directory itself, once empty.

24. **Keep `tools/mac_cleanup.sh` vendored.** Out of scope per requirements decision. Rename only to fit ordering
    (it is not in the autoloader chain — it is invoked by `config/40_func.sh:mac_cleanup()` via `bash $DF_ROOT/tools/
    mac_cleanup.sh`, so no rename is required). Leave the file untouched.

25. **Strip hardcoded user paths from `config/10_env.sh`** (formerly `config/env.sh`).
    - Replace `/Users/marcbeinder/Library/Application Support/Herd/config/php/83/` (line 11) with
      `$HOME/Library/Application Support/Herd/config/php/83/`.
    - Replace `/Users/marcbeinder/Library/Application Support/Herd/bin` (line 55) with
      `$HOME/Library/Application Support/Herd/bin`.
    - Delete the `NODE_EXTRA_CA_CERTS` export from `autoloader/mac.sh:26` (file is being deleted in step 22 anyway).
    - Append to `../dotfiles-private/.config/env.sh`:
      `export NODE_EXTRA_CA_CERTS="$HOME/Library/Application Support/Herd/config/valet/CA/LaravelValetCASelfSigned.pem"`
    Use `Edit` on the sibling repo file. The sibling repo at `../dotfiles-private/` already exists (verified by file
    listing) and is sourced today via the conditional load in the current `autoloader/mac.sh:30`; the new `.zshrc`
    and `framework/bash_loader.sh` both preserve that conditional load.

26. **Update `.gitignore`** to add `.DS_Store` and `.idea/`. In a separate commit, `git rm --cached` tracked instances.

27. **Update `README.md`** with new install instructions: `bash install.sh` (Mac) / `pwsh install.ps1` (Windows). Note
    that adding a tool = edit `provision/manifest.lua`. Note Lua is now a hard runtime dep for provisioning (not for
    shell startup).

28. **Manual end-to-end test on a clean macOS VM (or fresh user account):**
    - Run `bash install.sh` from clone.
    - Confirm brew, lua, antidote installed.
    - Confirm every manifest tool present (`brew list` and `brew list --cask`).
    - Open new Terminal/iTerm shell, confirm every existing alias and function works.
    - Run twice; confirm second run reports all idempotent and exits cleanly.

29. **Manual end-to-end test on a clean Windows VM (or fresh user account):**
    - Run `pwsh install.ps1` from clone.
    - Confirm choco, lua installed.
    - Confirm every manifest Windows tool present (`choco list`).
    - Open Git Bash, confirm `framework/bash_loader.sh` sources `config/*` and `tools/*` and every alias/function works.
    - Run twice; confirm idempotent.

30. **Capture before/after metrics for README.md:**
    - Line count: framework + autoloader + install.sh + install.ps1 (before vs after).
    - Tool-add cost: lines changed to add a tool (before: 2 scripts × ~1 line = 2 + drift risk; after: 1 manifest line).

## Configuration

No new user-facing configuration keys. The Lua provisioner accepts CLI flags (`--tools-only`, `--configurators-only`,
`--migrate`) but these are operator flags, not user-tunable behavior.

`~/.df_data/state.json` is internal state, not user config — users do not edit it.

Existing env vars (`DF_ROOT_DIRECTORY`, `DF_DATA_DIR`, `DF_DEBUG_TIMING`) are preserved. `DF_DEBUG_TIMING` becomes a
no-op in the new architecture (no custom timing harness); document this in README.md.

## Migration

No database migrations. State migration only: legacy `migrations/.migration_history` flat-file → `~/.df_data/state.json`
(JSON), handled by the new Lua migration in step 11. After that migration runs once, the legacy file is deleted.

This migration is included in the implementation steps and runs automatically on the first provisioner invocation
after the rewrite ships.

## Tests

Dotfiles repo has no test framework today. Adding one (busted, ShellSpec) is out of scope per the "simplicity over
completeness" principle. Verification is manual end-to-end on clean VMs (steps 27-28) plus the byte-identical UX
verification in step 16 (alias/function/PATH diff against pre-change snapshot).

For each logical unit that contains logic, the verification approach:

| Unit                                    | Approach                                                                                          |
|-----------------------------------------|---------------------------------------------------------------------------------------------------|
| `provision/lib/state.lua`               | Manual: provision twice, confirm second run skips already-done items per `state.json`.            |
| `provision/lib/backend.lua` (brew/cask) | Manual: install one tool fresh, re-run, confirm "already installed" branch.                       |
| `provision/lib/backend.lua` (choco)     | Manual on Windows VM (step 28).                                                                   |
| `provision/lib/migrations.lua`          | Manual: run provisioner, confirm both ported migrations execute once. Re-run, confirm no re-run.  |
| Each `provision/configurators/*.lua`    | Manual: run, inspect the resulting plist/symlink/config-file. Re-run, confirm no change/error.    |
| Each `provision/migrations/*.lua`       | Manual: run, confirm intended state achieved. Re-run, confirm idempotent.                         |
| `framework/bash_loader.sh`              | Manual: launch bash, confirm `type` reports every expected function. Diff `alias` output.         |
| `.zshrc` + `zsh_plugins.txt`            | Manual: launch zsh, capture `alias`, `typeset -f`, `echo $PATH`, diff against pre-change snapshot. |

Capture the pre-change snapshot during step 1 (before any deletion), to a tmp file outside the repo. The snapshot
script:

```sh
{
  alias
  typeset -f | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)'
  echo $PATH | tr ':' '\n' | sort -u
  env | grep -E '^(DF_|HERD_|JAVA_|ANDROID_|XDEBUG_|HOMEBREW_|ZSH_)' | sort
} > /tmp/dotfiles-baseline.txt
```

Post-change comparison must produce an empty diff (allowing for ordering differences in alias output, which `sort`
handles).

## Documentation updates

- `README.md` — new install flow, manifest-edit instruction, note on Lua dependency, before/after metrics from step 29.
- `.agents/AGENTS.md` — no changes (file-operation and language rules unchanged; no new architectural conventions
  introduced beyond what this plan documents).
- New `provision/README.md` — short developer doc explaining manifest schema, how to add a tool, configurator, or
  migration. Single page, no sub-pages.
- No user-facing CLI behavior changes, so no CLAUDE.md update needed.
