# Dotfiles Tooling Modernization — Implementation Plan

## Goal

Replace the hand-rolled bash provisioning scripts (`install.sh`, `install.ps1`), the custom source-guard/autoloader
framework (`framework/source_guards.sh`, `framework/__df_autoloader.sh`, `framework/migration_optimizer.sh`,
`framework/migrations/`), and the parallel mac/windows install codepaths with:

1. A **Lua-based provisioner** driven by a single declarative manifest (`provision/manifest.lua`) that installs
   software, runs one-shot configurators, and tracks idempotency state. Mac/Windows divergence lives in manifest
   columns, not parallel script trees.
2. **antidote** as the Zsh plugin manager. It loads OMZ (`ohmyzsh/ohmyzsh`), upstream plugins
   (`zsh-users/zsh-autosuggestions`, `zsh-users/zsh-syntax-highlighting`), and the local `shell/` plugin (a single
   entry script that sources every numbered file in lexical order). Replaces the custom `__df_source_once`
   autoloader on Zsh entirely.
3. A **bash fallback loader** for environments without Zsh (Windows Git Bash / MSYS), preserving identical sourcing
   semantics by running the same in-directory file loop that the local antidote plugin runs under Zsh.

Success = (a) a fresh Mac or Windows machine provisioned by `bash install.sh` / `pwsh install.ps1` and a new shell with
every alias, function, env var, and prompt behavior currently in `config/*.sh` + `tools/*.sh` working byte-identically to
the current implementation, (b) adding a new tool is a one-line manifest edit, not two script edits, (c) the framework
directory is gone, replaced by `~30 lines` of bash loader + a one-line antidote local-plugin entry script.

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
- `startup/mac.sh` is deleted, not ported. It is not wired into any LaunchAgent / login item today and runs only when
  the user manually invokes it; the OpenVPN-launch / cliclick automation it contains is not part of normal shell
  startup and is out of scope for this refactor.

## Affected components

| Component / Module                                | Change type            | Summary                                                                                                                |
|---------------------------------------------------|------------------------|------------------------------------------------------------------------------------------------------------------------|
| `install.sh`                                      | Modified               | Reduced to ~40-line bootstrap: install brew + git + lua, clone repo if absent, exec `lua provision/main.lua mac`.      |
| `install.ps1`                                     | Modified               | Reduced to ~40-line bootstrap: install choco + git + lua, clone repo if absent, exec `lua provision/main.lua windows`. |
| `provision/main.lua`                              | New                    | Provisioner entrypoint. Parses platform arg, loads manifest, dispatches install + configurator + migration tasks.      |
| `provision/manifest.lua`                          | New                    | Declarative table of tools, scripts, configurators, and one-shot migrations. Single source of truth for mac+windows.   |
| `provision/lib/backend.lua`                       | New                    | Package backend abstraction (`brew`, `cask`, `choco`) — `is_installed`, `install`, `tap`.                              |
| `provision/lib/state.lua`                         | New                    | Idempotency state (`~/.df_data/state.json`) — `has_run`, `mark_done`.                                                  |
| `provision/lib/platform.lua`                      | New                    | Platform detection (`mac`, `windows`) and OS-specific helpers (plist write, symlink, defaults).                        |
| `provision/lib/log.lua`                           | New                    | Colored logging (info/warn/error/ok) reading from terminal color support.                                              |
| `provision/lib/migrations.lua`                    | New                    | Migration runner (ordered, stop-on-failure).                                                                           |
| `provision/lib/scripts.lua`                       | New                    | Curl-pipe-bash runner for `scripts` manifest entries. Always re-runs; no state tracking.                               |
| `provision/lib/vendor/json.lua`                   | New (vendored)         | `rxi/json.lua` (MIT, ~280 lines). Pin to the latest tagged release at vendoring time; record the commit hash in `provision/lib/vendor/README.md`. |
| `provision/configurators/iterm.lua`               | New                    | Replaces `configure_iterm` from `install.sh`.                                                                          |
| `provision/configurators/ghostty.lua`             | New                    | Replaces `configure_ghostty` from `install.sh`.                                                                        |
| `provision/configurators/capslock.lua`            | New                    | Replaces `remap_capslock_to_escape` (delegates to `tools/remap_capslock.sh`, kept).                                    |
| `provision/configurators/stripe_completion.lua`   | New                    | Replaces inline stripe completion logic at end of `install.sh:197-204`.                                                |
| `provision/migrations/20250830_124338_setup_df_data_directory.lua` | New   | Lua port of existing shell migration.                                                                                  |
| `provision/migrations/20250830_124630_move_sys_cleanup_marker.lua` | New   | Lua port of existing shell migration.                                                                                  |
| `provision/migrations/20251201_000000_import_legacy_migration_history.lua` | New | Imports `migrations/.migration_history` (and private equivalent) into `state.json`. See §7.                            |
| `framework/__df_autoloader.sh`                    | Deleted                | Replaced by antidote (zsh) and `framework/bash_loader.sh` (bash fallback).                                             |
| `framework/source_guards.sh`                      | Deleted                | Replaced by antidote source-once semantics (zsh) and simple guard in `framework/bash_loader.sh` (bash).                |
| `framework/migration_optimizer.sh`                | Deleted                | Migrations run only from provisioner now, not at shell startup.                                                        |
| `framework/migrations/migrate.sh`                 | Deleted                | Replaced by `provision/lib/migrations.lua`.                                                                            |
| `framework/migrations/migration_helpers.sh`       | Deleted                | Replaced by `provision/lib/migrations.lua`.                                                                            |
| `framework/migrations/` (empty dir)               | Deleted                | Remove the directory itself after its contents are deleted.                                                            |
| `framework/brew_cache.sh`                         | Deleted                | No longer needed; provisioner queries brew directly and shell startup does not touch brew.                             |
| `framework/logging_functions.sh`                  | Unchanged              | Kept verbatim (all seven `log_*` functions retained — see step 27). Sourced directly by `shell/40_func.plugin.zsh` and by `tools/copy_jetbrains_keymaps.sh`. |
| `framework/bash_loader.sh`                        | New                    | Bash fallback (~30 lines): when `$ZSH_VERSION` unset, source `shell/[0-9]*_*.plugin.zsh` in lexical order.             |
| `entrypoint.sh`                                   | Modified               | Detect shell: if zsh, return immediately (`.zshrc` handles everything via antidote); if bash, source `framework/bash_loader.sh`. |
| `.zshrc`                                          | Modified               | Sets `DF_ROOT_DIRECTORY` (env-var-with-fallback), exports OMZ prelude vars, bootstraps antidote, loads `zsh_plugins.txt`, applies OMZ postlude, sources private dotfiles entrypoint. See §4. |
| `zsh_plugins.txt`                                 | New                    | antidote plugin bundle. Lists OMZ, autosuggestions, syntax-highlighting, then the local `shell` plugin. See §4.        |
| `shell/` (new dir)                                | New                    | Holds the renamed `config/*.sh` and the autoloader-sourced `tools/*.sh` files, with numeric prefixes encoding original load order. Filenames end in `.plugin.zsh`. See §4. |
| `shell/shell.plugin.zsh`                          | New                    | Antidote entry script for the local plugin: sources every `[0-9]*_*.plugin.zsh` sibling in lexical order. Identical loop used by `framework/bash_loader.sh`. |
| `autoloader/mac.sh`                               | Deleted                | Its sourcing list becomes the lexical order of files in `shell/`.                                                      |
| `autoloader/windows.sh`                           | Deleted                | Same.                                                                                                                  |
| `autoloader/` (empty dir)                         | Deleted                | Remove the directory itself once empty.                                                                                |
| `startup/mac.sh`                                  | Deleted                | Not wired into any LaunchAgent / login item; only ever ran on manual invocation. Out of scope per §Out-of-scope.       |
| `startup/` (empty dir)                            | Deleted                | Remove the directory itself once empty.                                                                                |
| `config/omz.sh`                                   | Deleted                | OMZ is loaded by antidote (`ohmyzsh/ohmyzsh` in `zsh_plugins.txt`). The configuration this file used to set (`ZSH`, `ZSH_THEME`, `ZSH_CUSTOM`, `zstyle ':omz:update'`, etc.) moves into `.zshrc` as the OMZ prelude; post-load tweaks (`bindkey '^I' autosuggest-accept`, `ZSH_COLORIZE_TOOL`, `ZSH_COLORIZE_STYLE`) move into the OMZ postlude. The brew-installed `zsh-autosuggestions` / `zsh-syntax-highlighting` sourcing inside `omz.sh` is replaced by antidote's own clones. |
| `config/env.sh`                                   | Renamed + modified     | → `shell/10_env.plugin.zsh`. Strip hardcoded `/Users/marcbeinder/...` paths (replace with `$HOME`). The Herd cert path / `NODE_EXTRA_CA_CERTS` move to `dotfiles-private/.config/env.sh`. |
| `config/color.sh`                                 | Renamed                | → `shell/20_color.plugin.zsh`. No logic change.                                                                        |
| `config/alias.sh`                                 | Renamed                | → `shell/30_alias.plugin.zsh`. No logic change.                                                                        |
| `config/func.sh`                                  | Renamed + modified     | → `shell/40_func.plugin.zsh`. Add `source "$DF_ROOT_DIRECTORY/framework/logging_functions.sh"` at the top so `log_error` (used internally) is available without the autoloader. |
| `config/mac.sh`                                   | Renamed + modified     | → `shell/70_mac.plugin.zsh`. Add `is_mac || return 0` at top.                                                          |
| `config/tmux.sh`                                  | Renamed + modified     | → `shell/95_tmux.plugin.zsh`. Add `is_mac || return 0` at top.                                                         |
| `tools/aws.sh`                                    | Renamed                | → `shell/50_aws.plugin.zsh`. No logic change.                                                                          |
| `tools/docker.sh`                                 | Renamed                | → `shell/60_docker.plugin.zsh`. No logic change.                                                                       |
| `tools/mac_cleanup_checker.sh`                    | Renamed + modified     | → `shell/80_mac_cleanup_checker.plugin.zsh`. Add `is_mac || return 0` at top.                                          |
| `tools/nano.sh`                                   | Renamed + modified     | → `shell/85_nano.plugin.zsh`. Add `is_mac || return 0` at top.                                                         |
| `tools/stripe.sh`                                 | Renamed + modified     | → `shell/90_stripe.plugin.zsh`. Add `is_mac || return 0` at top.                                                       |
| `tools/mac_cleanup.sh` (732 lines, vendored fork) | Unchanged              | Stays vendored. Invoked by `mac_cleanup()` in `shell/40_func.plugin.zsh` via `bash $DF_ROOT_DIRECTORY/tools/mac_cleanup.sh`. Not in autoloader chain; no rename. |
| `tools/copy_jetbrains_keymaps.sh`                 | Modified               | Replace the `source "$DF_ROOT_DIRECTORY/framework/__df_autoloader.sh"` block (lines 7-15) with `source "$DF_ROOT_DIRECTORY/framework/logging_functions.sh"`. Preserves access to `log_info`/`log_error`/`log_success` without the autoloader. |
| `tools/agent_symlink.sh`                          | Unchanged              | Defines its own `log_info`/`log_error`; no framework dep.                                                              |
| `tools/remap_capslock.sh`, `tools/tmux.conf`      | Unchanged              | Not on autoloader chain.                                                                                               |
| `dotfiles-private/.config/env.sh`                 | Modified (sibling repo) | Append `export NODE_EXTRA_CA_CERTS="$HOME/Library/Application Support/Herd/config/valet/CA/LaravelValetCASelfSigned.pem"`. Commit and push in the sibling repo separately from the public repo PR; document the dependency in the public PR description so the cert path is not silently dropped during the deploy. |
| `README.md`                                       | Modified               | Update install instructions to reflect new bootstrap flow. Document `DF_ROOT_DIRECTORY` env-var override.              |
| `.gitignore`                                      | Modified               | Add `.DS_Store`, `.idea/`. Remove tracked instances in a separate commit within step 30.                               |

## Architecture

### 1. Two-stage bootstrap: shell stub → Lua provisioner

```
User runs:  bash install.sh                    (or)  pwsh install.ps1
              │                                         │
              ▼                                         ▼
       [Stage 1: stub]                            [Stage 1: stub]
       - Install Homebrew if missing              - Install Chocolatey if missing
       - brew install lua git                     - choco install lua git -y
       - DF_ROOT_DIRECTORY=<resolved>             - $DotfilesDirectory=<resolved>
       - exec lua provision/main.lua mac          - exec lua provision/main.lua windows
              │                                         │
              ▼                                         ▼
       [Stage 2: Lua provisioner — identical entrypoint, platform passed as arg]
       - Load provision/manifest.lua
       - For each tool entry matching platform: backend.install if not already_installed
       - For each script entry matching platform: scripts.run (always re-runs; relies on installer idempotency)
       - For each configurator entry matching platform: run module if not in state.configurators_run
       - For each migration not in state.migrations_run: run module, mark done
       - Write/update ~/.df_data/state.json
```

Stub scripts contain **no per-tool logic**. They cannot drift between platforms because they install the same three
things (package manager, Lua, Git) and then hand off.

#### DF_ROOT_DIRECTORY resolution (used by stubs and `.zshrc`)

Every entrypoint resolves `DF_ROOT_DIRECTORY` the same way: honor the existing environment variable if set; otherwise
fall back to `$HOME/Documents/GitHub/dotfiles`. This is the single rule used by `install.sh`, `install.ps1`,
`.zshrc`, `entrypoint.sh`, `framework/bash_loader.sh`, and the Lua provisioner.

```sh
# bash / zsh
: "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
export DF_ROOT_DIRECTORY
```

```powershell
# PowerShell
if (-not $env:DF_ROOT_DIRECTORY) {
    $env:DF_ROOT_DIRECTORY = Join-Path $env:USERPROFILE "Documents\GitHub\dotfiles"
}
$DotfilesDirectory = $env:DF_ROOT_DIRECTORY
```

```lua
-- provision/lib/platform.lua
function M.dotfiles_root()
  return os.getenv("DF_ROOT_DIRECTORY") or (os.getenv("HOME") .. "/Documents/GitHub/dotfiles")
end
```

### 2. Manifest schema

`provision/manifest.lua` returns a single table:

```lua
return {
  tools = {
    -- Basic per-platform IDs:
    { name = "1password",
      mac  = { backend = "cask",  id = "1password", app = "/Applications/1Password.app" },
      win  = { backend = "choco", id = "1password" } },
    { name = "gh",
      mac  = { backend = "brew",  id = "gh" },
      win  = { backend = "choco", id = "gh" } },

    -- Different backend IDs per platform (chrome cask vs choco):
    { name = "chrome",
      mac  = { backend = "cask",  id = "google-chrome", app = "/Applications/Google Chrome.app" },
      win  = { backend = "choco", id = "googlechrome" } },

    -- Brew tap support (terraform):
    { name = "terraform",
      mac  = { backend = "brew",  id = "hashicorp/tap/terraform", tap = "hashicorp/tap" },
      win  = { backend = "choco", id = "terraform" } },

    -- Mac-only tool (no `win` key):
    { name = "trivy",
      mac  = { backend = "brew",  id = "trivy" } },

    -- antidote (mac-only; Git Bash on Windows uses bash_loader.sh, not antidote):
    { name = "antidote",
      mac  = { backend = "brew",  id = "antidote" } },

    -- ...remaining tools, one per line per the install.sh / install.ps1 master lists in step 9.
  },

  scripts = {                                                        -- external installers (curl | bash style)
    { name = "opencode",
      mac  = { kind = "curl", url = "https://opencode.ai/install", pipe_to = "bash" },
      win  = { kind = "curl", url = "https://opencode.ai/install", pipe_to = "bash" } },
    { name = "bun",
      mac  = { kind = "curl", url = "https://bun.com/install",     pipe_to = "bash" } },                  -- mac-only
    { name = "syft",
      mac  = { kind = "curl", url = "https://get.anchore.io/syft",
               pipe_to = "sudo sh -s -- -b /usr/local/bin" } },                                            -- mac-only
  },

  configurators = {                                                  -- one-shot config writes; idempotent
    { name = "iterm",            module = "configurators.iterm",            platforms = { "mac" } },
    { name = "ghostty",          module = "configurators.ghostty",          platforms = { "mac" } },
    { name = "capslock",         module = "configurators.capslock",         platforms = { "mac" } },
    { name = "stripe_completion",module = "configurators.stripe_completion",platforms = { "mac", "win" } },
  },

  migrations = {                                                     -- ordered, run-once
    "migrations.20250830_124338_setup_df_data_directory",
    "migrations.20250830_124630_move_sys_cleanup_marker",
    "migrations.20251201_000000_import_legacy_migration_history",
  },
}
```

Schema notes:

- A new tool = one line in `tools`. Mac-only tools omit `win`. The provisioner iterates and dispatches.
- `tap` (optional, brew only): when set, `backend.brew.install` runs `brew tap <tap>` before the install. The `id`
  field is used verbatim, so for tap-served formulas it should be the fully qualified `<tap>/<formula>` form.
- `app` (optional, cask only): an absolute `.app` bundle path used as a pre-install existence check; the existing
  `install_tool` behavior in `install.sh:15` is preserved.
- `kind = "curl"` is the only script kind defined now. `pipe_to` is the shell command that receives the downloaded
  payload on stdin. `scripts` entries have no version, no checksum, and no per-entry state — they always re-run on
  every provision and rely on the upstream installer's own idempotency (`bun`, `opencode`, and `syft` installers are
  all designed to be re-runnable).
- Configurators have no `version` field. Each runs at most once per machine (tracked by name in
  `state.configurators_run`); if the implementation of a configurator needs to be re-applied to an already-provisioned
  machine, the user removes the relevant key from `~/.df_data/state.json` by hand. Document this in
  `provision/README.md`.

### 3. Idempotency state

`~/.df_data/state.json` shape:

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

Source-of-truth rules:

- **Tools**: provisioner queries the live backend (`brew list`, `brew list --cask`, `choco list <id> --exact
  --limit-output`) on each run; `state.tools_installed` is an optimization, not the source of truth. Removing a tool
  out-of-band re-installs it next provision.
- **Configurators**: `state.configurators_run` *is* the source of truth (timestamp only — no version field). One-shot
  semantics; never re-run automatically once present.
- **Migrations**: `state.migrations_run` *is* the source of truth. Public migrations key on bare name
  (`20250830_124338_setup_df_data_directory`); private-repo migrations key with a `private:` prefix
  (`private:<name>`). Both live in the same map.
- **Scripts**: not tracked in `state.json`. Re-runs every provision (upstream installers handle their own
  short-circuit logic).

The existing `migrations/.migration_history` flat file is imported into `state.migrations_run` by migration
`20251201_000000_import_legacy_migration_history.lua` (step 12). The legacy file is left in place as an audit trail.

### 4. Shell startup: zsh path (antidote)

`.zshrc`:

```sh
# DF_ROOT_DIRECTORY: env-var-with-fallback (matches install.sh / install.ps1)
: "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
export DF_ROOT_DIRECTORY
export DF_DATA_DIR="${DF_DATA_DIR:-$HOME/.df_data}"

# OMZ prelude — must run *before* antidote loads ohmyzsh/ohmyzsh because OMZ reads these
# variables when oh-my-zsh.sh is sourced.
export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="robbyrussell"
export ZSH_CUSTOM="$DF_ROOT_DIRECTORY/ohmyzsh/custom"
COMPLETION_WAITING_DOTS="true"
zstyle ':omz:update' mode auto

# antidote bootstrap (installed by provisioner as `brew install antidote`)
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load "$DF_ROOT_DIRECTORY/zsh_plugins.txt"

# OMZ postlude — runs *after* antidote has loaded OMZ + autosuggestions + syntax-highlighting,
# so the keybinding can attach to the autosuggest widget.
bindkey '^I' autosuggest-accept
ZSH_COLORIZE_TOOL=chroma
ZSH_COLORIZE_STYLE="colorful"

# Conditionally load private dotfiles
[ -f "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh" ] && \
  source "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh"
```

`zsh_plugins.txt`:

```
ohmyzsh/ohmyzsh                                  # OMZ first
zsh-users/zsh-autosuggestions                    # antidote clones into its cache
zsh-users/zsh-syntax-highlighting                # antidote clones into its cache
$DF_ROOT_DIRECTORY path:shell                    # local plugin (entry script: shell/shell.plugin.zsh)
```

Local-plugin entry script — `shell/shell.plugin.zsh`:

```sh
# antidote loads this single file for the local plugin. It sources every numbered
# .plugin.zsh sibling in lexical order. The same loop is used by framework/bash_loader.sh
# so zsh and bash get identical load order.
_dir=${0:A:h}
for f in "$_dir"/[0-9]*_*.plugin.zsh; do
  source "$f"
done
unset _dir f
```

Sourcing order matches the current `autoloader/mac.sh` order verbatim. The `config/` and `tools/` split is collapsed
into one `shell/` directory so a single lexical sort yields the correct interleaved order:

| Original (autoloader/mac.sh order) | New filename                                |
|------------------------------------|---------------------------------------------|
| `config/omz.sh`                    | *(deleted — see §Affected components)*      |
| `config/env.sh`                    | `shell/10_env.plugin.zsh`                   |
| `config/color.sh`                  | `shell/20_color.plugin.zsh`                 |
| `config/alias.sh`                  | `shell/30_alias.plugin.zsh`                 |
| `config/func.sh`                   | `shell/40_func.plugin.zsh`                  |
| `tools/aws.sh`                     | `shell/50_aws.plugin.zsh`                   |
| `tools/docker.sh`                  | `shell/60_docker.plugin.zsh`                |
| `config/mac.sh`                    | `shell/70_mac.plugin.zsh`                   |
| `tools/mac_cleanup_checker.sh`     | `shell/80_mac_cleanup_checker.plugin.zsh`   |
| `tools/nano.sh`                    | `shell/85_nano.plugin.zsh`                  |
| `tools/stripe.sh`                  | `shell/90_stripe.plugin.zsh`                |
| `config/tmux.sh`                   | `shell/95_tmux.plugin.zsh`                  |

The `.plugin.zsh` extension is required for antidote to recognize the local plugin's entry script; the other files
in `shell/` use the same extension only for visual consistency. The contents are unchanged bash-compatible POSIX
shell (no zsh-only syntax introduced), so `framework/bash_loader.sh` sources them with no per-file transformation.

Files Windows does not currently load (per `autoloader/windows.sh`: only `env`, `color`, `alias`, `func`, `aws`,
`docker`) must short-circuit on non-mac to preserve current Windows behavior. Each affected file gets a guard at the
very top:

| File                                            | Guard line                                    |
|-------------------------------------------------|-----------------------------------------------|
| `shell/70_mac.plugin.zsh`                       | `is_mac || return 0`                          |
| `shell/80_mac_cleanup_checker.plugin.zsh`       | `is_mac || return 0`                          |
| `shell/85_nano.plugin.zsh`                      | `is_mac || return 0`                          |
| `shell/90_stripe.plugin.zsh`                    | `is_mac || return 0`                          |
| `shell/95_tmux.plugin.zsh`                      | `is_mac || return 0`                          |

`is_mac`, `is_windows`, and `is_linux` are defined in `shell/40_func.plugin.zsh` (formerly `config/func.sh:216-224`),
which loads before any guarded file in lexical order. Verified by `grep -n 'is_mac\|is_windows\|is_linux'
config/func.sh` → lines 216, 220, 224.

### 5. Shell startup: bash fallback (Git Bash / MSYS / non-zsh)

`entrypoint.sh`:

```sh
if [ -n "$ZSH_VERSION" ]; then
  return 0   # .zshrc handles everything via antidote
fi
: "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
export DF_ROOT_DIRECTORY
source "$DF_ROOT_DIRECTORY/framework/bash_loader.sh"
```

`framework/bash_loader.sh` (~30 lines):

```sh
#!/usr/bin/env bash
# Minimal source-once guard + ordered sourcing for non-zsh shells.
# Mirrors the loop in shell/shell.plugin.zsh so bash and zsh source the same files
# in the same order.

__df_loaded=":"
__df_source_once() {
  case "$__df_loaded" in *":$1:"*) return 0;; esac
  [ -f "$1" ] || return 1
  # shellcheck disable=SC1090
  source "$1"
  __df_loaded="$__df_loaded$1:"
}

for f in "$DF_ROOT_DIRECTORY"/shell/[0-9]*_*.plugin.zsh; do
  __df_source_once "$f"
done

[ -f "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh" ] && \
  source "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh"
```

This file is the **entire** replacement for `framework/source_guards.sh` (139 lines), `framework/__df_autoloader.sh`
(50 lines), `autoloader/mac.sh` (35 lines), and `autoloader/windows.sh` (25 lines). Net deletion: ~219 lines.

Bash users (Git Bash on Windows) get the same set of files sourced in the same order as Zsh users. No antidote on
Windows because zsh on Windows is not the primary Windows shell. If a Windows user does run Zsh under MSYS2 / WSL,
antidote works there too because the `.zshrc` flow is OS-agnostic — only the provisioner needs to know the OS.

### 6. Configurators: macOS plist writes etc.

Lua configurators use `os.execute` for `defaults write` / `PlistBuddy` / `ln -s` / `mkdir -p`. They are thin wrappers
around the existing shell snippets in `install.sh`. Translating bash → Lua here is mechanical; the goal is centralizing
the call site, not rewriting the commands. Each configurator records completion in `state.configurators_run` (timestamp
only) and is skipped on subsequent provisions. There is no automatic re-run mechanism — to force a re-apply, the user
removes the entry from `state.json` manually (documented in `provision/README.md`).

`provision/configurators/capslock.lua` and any other configurator that delegates to a kept-as-shell tool (e.g.
`tools/remap_capslock.sh`) just `os.execute("bash " .. dotfiles_root .. "/tools/remap_capslock.sh --enable")`. The
script stays; Lua is the orchestrator.

### 6a. Failure handling

Provisioner accumulates failures rather than stopping. For each tool, script, or configurator that throws or returns
non-zero from `os.execute`:

- Log the failure via `log.error(name, msg)`.
- Record it in an in-memory `failures` list (not in `state.json`).
- Continue to the next entry.

At end of run, print a summary table (counts: installed, skipped-already-present, failed). If `#failures > 0`, exit
with code 1 so the calling shell stub propagates failure; otherwise exit 0. Re-running the provisioner retries failed
entries because they were never marked done in `state.json` (tools re-query the live backend; configurators are
absent from `state.configurators_run`; scripts always re-run anyway).

Migrations are the one exception: a migration failure stops further migration execution (a later migration may depend
on an earlier one's state). Tools, scripts, and configurators are independent and continue past failures.

### 6b. Lua runtime requirement

Target Lua 5.4 (the version Homebrew and Chocolatey install). Code must avoid features removed in 5.4 (`unpack` →
`table.unpack`, no implicit string→number coercion in arithmetic edge cases). LuaJIT compatibility is not required.
No third-party deps beyond the vendored `provision/lib/vendor/json.lua` (rxi/json.lua, MIT).

### 7. Migrations in Lua

`provision/lib/migrations.lua` exposes `run_pending(state)`. Migration modules are Lua files in `provision/migrations/`
returning a table `{ description = "...", up = function() ... end }`. The runner:

1. Reads ordered list from `manifest.migrations`.
2. Skips entries already in `state.migrations_run` (matched by bare name).
3. Calls `up()`. On success, stamps `state.migrations_run[name] = iso_timestamp()`.
4. On error, logs and stops (do not continue past a failed migration).

Migrations are not invoked at shell startup. They run only when the user runs `lua provision/main.lua mac --migrate` or
the full `bash install.sh`. The user must accept that adding a new migration requires re-running the provisioner;
this is documented in `README.md`.

#### Legacy history import

Migration `20251201_000000_import_legacy_migration_history.lua` runs once on the first provision after the rewrite
ships. It:

- Reads `$DF_ROOT_DIRECTORY/migrations/.migration_history` (line-per-name flat file, if present). For each line, sets
  `state.migrations_run[<line>] = "imported"`.
- If `$DF_PRIVATE_DIRECTORY/.migrations/.migration_history` is present (path discovered by checking
  `$HOME/Documents/GitHub/dotfiles-private/.migrations/.migration_history`), for each line sets
  `state.migrations_run["private:" .. <line>] = "imported"`.
- Does not delete either legacy file. Both remain as audit trails; the new runner ignores them.

The `private:` namespace prefix is purely a convention recorded in `state.migrations_run`. There is no separate map
key. Future private-repo migration runners (if any) must use the same prefix to interoperate.

### 8. Stripping hardcoded user paths

`dotfiles-private` layout (verified from `../dotfiles-private/`): uses `.config/env.sh`, `.config/alias.sh`,
`.config/func.sh`, `.tools/github_token.sh`. Already sourced today via `autoloader/mac.sh:30` → `dotfiles-private/
entrypoint.sh` → individual `source` calls. After this plan, the same load path remains (zsh: via the private
entrypoint sourced from `.zshrc`; bash: via `framework/bash_loader.sh`).

Per-file changes:

- `config/env.sh:11` (`HERD_PHP_83_INI_SCAN_DIR`) — currently `/Users/marcbeinder/Library/Application Support/Herd/
  config/php/83/`. The Herd install layout is the same for every user, just under a different `$HOME`. **Change to
  `$HOME/Library/Application Support/Herd/config/php/83/`. Keep in dotfiles (now `shell/10_env.plugin.zsh`).**
- `config/env.sh:55` (`_append_path_mac "/Users/marcbeinder/Library/Application Support/Herd/bin"`) — same reasoning;
  **change to `$HOME/...`. Keep in dotfiles (now `shell/10_env.plugin.zsh`).**
- `autoloader/mac.sh:26` (`NODE_EXTRA_CA_CERTS=".../Herd/config/valet/CA/LaravelValetCASelfSigned.pem"`) — this is a
  Marc-specific cert file generated by Marc's local Herd install. **Move to `dotfiles-private/.config/env.sh`**
  (append a single `export NODE_EXTRA_CA_CERTS="$HOME/Library/Application Support/Herd/config/valet/CA/
  LaravelValetCASelfSigned.pem"` line). The Herd path itself is generic, but exporting it depends on the user
  actually using Herd/Valet, which is workflow-specific — private repo is the right home. **The sibling-repo edit
  must be committed and pushed in a separate PR; the public-repo PR description must reference it as a
  prerequisite to avoid silently dropping the cert path after deploy.**
- `$DF_ROOT_DIRECTORY` previously set in `framework/__df_autoloader.sh:11` (already used `$HOME`). After this plan,
  this lives in `.zshrc`, `entrypoint.sh`, and `framework/bash_loader.sh`, all using the env-var-with-fallback rule
  from §1.

No other hardcoded `/Users/marcbeinder` paths exist in the public repo (verified by `grep -r '/Users/marcbeinder'
config/ tools/ framework/ autoloader/ install.sh`).

## Implementation steps

1. **Capture pre-change behavior snapshot.** Before any file rename or deletion, capture a baseline that will be used
   as the regression oracle in step 18 and steps 32-33:

   ```sh
   # In zsh, on the development Mac (this captures the full mac autoloader chain):
   {
     alias
     typeset -f | sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\) *() *{.*/\1/p' | sort -u
     echo "$PATH" | tr ':' '\n' | sort -u
     env | grep -E '^(DF_|HERD_|JAVA_|ANDROID_|XDEBUG_|HOMEBREW_|ZSH_|NODE_EXTRA_CA_CERTS|ANDROID_SDK_ROOT)=' | sort
   } > /tmp/dotfiles-baseline-zsh.txt
   ```

   ```sh
   # In bash (Git Bash) on a Windows machine — this captures the windows autoloader chain:
   { alias; typeset -f | sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\) *() *{.*/\1/p' | sort -u
     echo "$PATH" | tr ':' '\n' | sort -u
     env | grep -E '^(DF_|JAVA_|ANDROID_|HOMEBREW_)=' | sort
   } > /tmp/dotfiles-baseline-bash.txt
   ```

   Save both files outside the repo. The Mac zsh baseline is the oracle for step 18; the Windows bash baseline is the
   oracle for step 33.

2. **Create provision scaffolding.**
   - Create `provision/` directory with subdirs `lib/`, `lib/vendor/`, `configurators/`, `migrations/`.
   - Create empty `provision/main.lua` and `provision/manifest.lua`.
   - Vendor `rxi/json.lua` at `provision/lib/vendor/json.lua` — pin to the latest tagged release at vendoring time;
     write the upstream commit SHA into a new `provision/lib/vendor/README.md`.

3. **Write `provision/lib/platform.lua`.**
   - Detect platform: read first CLI arg of `main.lua` (`mac` or `win`/`windows`), validate against allowlist.
   - Expose helpers: `is_mac()`, `is_windows()`, `home()`, `dotfiles_root()` (env-var-with-fallback per §1),
     `data_dir()`.

4. **Write `provision/lib/log.lua`.**
   - Functions: `info`, `warn`, `error`, `ok`, `step`.
   - Use ANSI colors if `io.stdout:isatty()` returns true and `$NO_COLOR` unset.

5. **Write `provision/lib/state.lua`.**
   - Load/save `~/.df_data/state.json` using the vendored `provision/lib/vendor/json.lua`.
   - API: `state.load()`, `state.save(s)`, `state.mark_done(s, category, name)`, `state.has_run(s, category, name)`.
   - Create `~/.df_data/` if missing.

6. **Write `provision/lib/backend.lua`.**
   - Backends: `brew`, `cask`, `choco`.
   - Each implements `is_installed(id, app_path?)` and `install(id, opts)`.
   - `brew.is_installed` runs `brew list --formula 2>/dev/null | grep -qx <id>` (and `brew list --cask` for casks).
   - `choco.is_installed` runs `choco list <id> --exact --limit-output` (Choco v2 syntax — fixes the broken
     `--local-only` flag in the current `install.ps1`).
   - `brew.install` calls `brew tap <tap>` first when `opts.tap` is set, then `brew install <id>`.

7. **Write `provision/lib/scripts.lua`.**
   - One function: `run(entry)`. Given `{ kind="curl", url=..., pipe_to=... }`, execute
     `os.execute("curl -fsSL " .. url .. " | " .. pipe_to)`.
   - No state lookup, no state write. Always runs.

8. **Write `provision/lib/migrations.lua`.**
   - Discover modules by name from `manifest.migrations`, `require` them, run `up()` if not in
     `state.migrations_run`.

9. **Write `provision/main.lua`.**
   - `package.path` extended to include `provision/?.lua;provision/?/init.lua`.
   - Args: `<platform> [--tools-only|--scripts-only|--configurators-only|--migrate]`.
   - Default: run tools, then scripts, then configurators, then migrations.
   - Print summary at end (counts of installed / skipped / failed).

10. **Write `provision/manifest.lua`.**
    - Translate every `install_tool` call from `install.sh:148-175` and every `Install-ChocoTool` call from
      `install.ps1:102-116` into a single merged `tools` table. Use the `install.sh` list as the master superset.
      Mac-only tools (not in `install.ps1`): `bash`, `chroma`, `cliclick`, `font-jetbrains-mono`, `gh`,
      `git-filter-repo`, `herd`, `pygments`, `raycast`, `shottr`, `stripe-cli`, `trivy`, `ghostty`.
    - Add Zsh as a tool for both platforms (`{ name = "zsh", mac = { backend = "brew", id = "zsh" },
      win = { backend = "choco", id = "zsh" } }`). The current `install.sh:115-121` and `install.ps1:93-99`
      install zsh imperatively; moving it into the manifest eliminates the stub-level branch.
    - Add `antidote` as a mac-only brew install (`{ name = "antidote", mac = { backend = "brew", id = "antidote" } }`).
      Drop brew-installed `zsh-autosuggestions` and `zsh-syntax-highlighting` from the manifest entirely — antidote
      clones them itself per `zsh_plugins.txt` and the brew copies are no longer sourced (see §Affected components
      row for `config/omz.sh`).
    - Use the `tap` field for `terraform` (`tap = "hashicorp/tap"`, id = `hashicorp/tap/terraform`).
    - Use per-platform `id` for `chrome` (`google-chrome` cask, `googlechrome` choco).
    - Translate the three `curl | bash`-style installers (OpenCode, Bun, Syft) into `scripts`. OpenCode is mac+win;
      Bun and Syft are mac-only.
    - Add a new `ohmyzsh` script entry for both platforms (current `install.sh:123-131` installer):

      ```lua
      { name = "ohmyzsh",
        mac = { kind = "curl",
                url = "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh",
                pipe_to = "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh" },
        win = { kind = "curl",
                url = "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh",
                pipe_to = "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh" } },
      ```

      The `RUNZSH=no CHSH=no KEEP_ZSHRC=yes` env vars match the official non-interactive install recipe; without
      them the OMZ installer launches a new zsh shell, prompts to change the user's default shell, and overwrites
      `.zshrc` — none of which are safe under the provisioner. The provisioner's scripts runner relies on the
      upstream installer's own idempotency: `$HOME/.oh-my-zsh` existence is the OMZ installer's short-circuit.
    - List the four configurators in `configurators` with the platforms each applies to.
    - List the two existing migrations plus the new legacy-history-import migration in `migrations`.

11. **Port `configure_iterm`, `configure_ghostty`, `remap_capslock_to_escape`, and the inline stripe-completion block
    from `install.sh` into Lua modules under `provision/configurators/`.**
    - `iterm.lua`: replicates `install.sh:25-45` via `os.execute` calls.
    - `ghostty.lua`: replicates `install.sh:47-66` via `os.execute` calls.
    - `capslock.lua`: `os.execute("bash " .. root .. "/tools/remap_capslock.sh --enable")`.
    - `stripe_completion.lua`: replicates `install.sh:196-204` via `os.execute` calls.

12. **Port the two existing shell migrations to Lua under `provision/migrations/`.**
    - Read each shell migration; translate its `mv`/`mkdir`/`rm` calls to Lua via `os.execute` (avoid adding `lfs`
      dependency — `os.execute` is sufficient and matches the shell migration style).
    - Test each migration's idempotency by running provisioner twice in a row and confirming no errors.

13. **Add `provision/migrations/20251201_000000_import_legacy_migration_history.lua`** as described in §7.

14. **Rewrite `install.sh` as ~40-line bootstrap.** Skeleton:

    ```sh
    #!/usr/bin/env bash
    set -eu

    DOTFILES_REPO="https://github.com/onairmarc/dotfiles.git"
    : "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
    export DF_ROOT_DIRECTORY

    if ! command -v brew >/dev/null 2>&1; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    brew update
    for pkg in lua git; do
      command -v "$pkg" >/dev/null 2>&1 || brew install "$pkg"
    done

    if [ ! -d "$DF_ROOT_DIRECTORY" ]; then
      git clone "$DOTFILES_REPO" "$DF_ROOT_DIRECTORY"
    fi

    cd "$DF_ROOT_DIRECTORY"
    exec lua provision/main.lua mac "$@"
    ```

    Delete every `install_tool` line, `configure_*` function, and inline curl block — they all live in Lua now.
    Zsh and Oh My Zsh installs (currently `install.sh:115-131`) also move to the manifest (step 10) and are no
    longer part of the stub.

15. **Rewrite `install.ps1` as ~40-line bootstrap.** Skeleton:

    ```powershell
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    $DotfilesRepo = "https://github.com/onairmarc/dotfiles.git"
    if (-not $env:DF_ROOT_DIRECTORY) {
        $env:DF_ROOT_DIRECTORY = Join-Path $env:USERPROFILE "Documents\GitHub\dotfiles"
    }
    $DotfilesDirectory = $env:DF_ROOT_DIRECTORY

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        # ... existing Chocolatey bootstrap from install.ps1:49-71 verbatim ...
    }

    foreach ($pkg in @("lua", "git")) {
        if (-not (Get-Command $pkg -ErrorAction SilentlyContinue)) {
            choco install $pkg -y
        }
    }

    if (-not (Test-Path $DotfilesDirectory)) {
        git clone $DotfilesRepo $DotfilesDirectory
    }

    Set-Location $DotfilesDirectory
    lua "$DotfilesDirectory\provision\main.lua" windows @args
    ```

    Delete every `Install-ChocoTool` line. Zsh install (currently `install.ps1:93-99`) and the OpenCode script
    (currently `install.ps1:118-129`) also move to the manifest (step 10) and are no longer part of the stub.

16. **Create `zsh_plugins.txt`** in repo root with the four lines from §4.

17. **Create `shell/shell.plugin.zsh`** as the antidote entry script per §4 (the local-plugin loop).

18. **Rewrite `.zshrc`** to the form in §4 (env-var-with-fallback + OMZ prelude + antidote bootstrap + OMZ postlude
    + private dotfiles). Validate: open a new shell, capture the same outputs as step 1 into a fresh
    `/tmp/dotfiles-after-zsh.txt`, and run `diff -u /tmp/dotfiles-baseline-zsh.txt /tmp/dotfiles-after-zsh.txt`.
    The diff must be empty (after ignoring order differences via `sort`, already applied in step 1).

19. **Rewrite `entrypoint.sh`** to the form in §5 (zsh → return; bash → resolve `DF_ROOT_DIRECTORY` then source
    `framework/bash_loader.sh`).

20. **Write `framework/bash_loader.sh`** as in §5.

21. **Rename `config/*.sh` and `tools/*.sh` files into `shell/`** with `.plugin.zsh` extension per the table in §4.
    Use `git mv` so history is preserved. Verify each rename touches exactly one file. After all renames, run
    `ls shell/ | sort` and confirm the lexical order matches the §4 table top-to-bottom.

22. **Delete `config/omz.sh`** (the OMZ-specific prelude/postlude logic now lives in `.zshrc` per §4). Then delete
    the now-empty `config/` and `tools/` parent directories if nothing else remains in them. (`tools/` retains
    `mac_cleanup.sh`, `copy_jetbrains_keymaps.sh`, `agent_symlink.sh`, `remap_capslock.sh`, `tmux.conf` — so it
    stays. `config/` becomes empty after the renames in step 21 and the deletion in this step — delete the directory.)

23. **Add internal `is_mac || return 0` guards** to every file Windows does not currently load, per the table in §4.
    Verify `is_mac` is in scope at each guard site: `grep -n 'is_mac\|is_windows\|is_linux' shell/40_func.plugin.zsh`
    must show the function definitions (formerly at `config/func.sh:216, 220, 224`).

24. **Update `shell/40_func.plugin.zsh`** to source `framework/logging_functions.sh` at its top:

    ```sh
    source "$DF_ROOT_DIRECTORY/framework/logging_functions.sh"
    ```

    This replaces the autoloader-mediated load. `log_error` (used at `config/func.sh:24, 77, 90, 263`) keeps working.

25. **Update `tools/copy_jetbrains_keymaps.sh:6-15`** to drop the autoloader dependency:

    ```sh
    # Resolve repo root if not already set.
    if [[ -z "${DF_ROOT_DIRECTORY:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        export DF_ROOT_DIRECTORY="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi

    source "$DF_ROOT_DIRECTORY/framework/logging_functions.sh"
    ```

    All references to `log_info`/`log_error`/`log_success` further down the file keep working.

26. **Delete framework + autoloader + startup files no longer needed.**
    Confirm with the user before deleting (per `.agents/AGENTS.md` file-operation rules). Targets:
    - `framework/__df_autoloader.sh`
    - `framework/source_guards.sh`
    - `framework/migration_optimizer.sh`
    - `framework/migrations/migrate.sh`
    - `framework/migrations/migration_helpers.sh`
    - `framework/migrations/` (directory, once empty)
    - `framework/brew_cache.sh`
    - `autoloader/mac.sh`
    - `autoloader/windows.sh`
    - `autoloader/` (directory, once empty)
    - `startup/mac.sh`
    - `startup/` (directory, once empty)

    `framework/logging_functions.sh` is NOT deleted (still sourced by `shell/40_func.plugin.zsh` and
    `tools/copy_jetbrains_keymaps.sh`).

27. **Keep `framework/logging_functions.sh` unchanged.** All seven `log_*` functions (`log_info`, `log_success`,
    `log_warning`, `log_error`, `log_debug`, `log_note`, `log_plain`) are retained. Strict scoping would let
    us trim to three (`log_info`, `log_error`, `log_success` — the ones grep finds today) but the file is 40
    lines and dotfiles-private may call any of them. Keep as-is to avoid the audit and the regression risk.

28. **Keep `tools/mac_cleanup.sh` vendored.** Out of scope. Not in the autoloader chain. Invoked by
    `mac_cleanup()` in `shell/40_func.plugin.zsh` via `bash $DF_ROOT_DIRECTORY/tools/mac_cleanup.sh`. Leave
    untouched.

29. **Strip hardcoded user paths from `shell/10_env.plugin.zsh`** (formerly `config/env.sh`).
    - Replace `/Users/marcbeinder/Library/Application Support/Herd/config/php/83/` (line 11 in the original) with
      `$HOME/Library/Application Support/Herd/config/php/83/`.
    - Replace `/Users/marcbeinder/Library/Application Support/Herd/bin` (line 55 in the original) with
      `$HOME/Library/Application Support/Herd/bin`.
    - The `NODE_EXTRA_CA_CERTS` export from `autoloader/mac.sh:26` is removed when `autoloader/mac.sh` is deleted
      in step 26; no separate edit needed.
    - Append to `../dotfiles-private/.config/env.sh`:

      ```sh
      export NODE_EXTRA_CA_CERTS="$HOME/Library/Application Support/Herd/config/valet/CA/LaravelValetCASelfSigned.pem"
      ```

      Use `Edit` on the sibling repo file. Commit and push that change in the dotfiles-private repo separately;
      reference the PR in the public-repo PR description so the dependency is explicit.

30. **Update `.gitignore`** to add `.DS_Store` and `.idea/`. In a separate commit, `git rm --cached` tracked
    instances.

31. **Update `README.md`** with new install instructions: `bash install.sh` (Mac) / `pwsh install.ps1` (Windows).
    Note that adding a tool = edit `provision/manifest.lua`. Note Lua is now a hard runtime dep for provisioning
    (not for shell startup). Document the `DF_ROOT_DIRECTORY` env-var override (with the `$HOME/Documents/GitHub/
    dotfiles` fallback). Note that `DF_DEBUG_TIMING` is now a no-op (no custom timing harness in the new
    architecture).

32. **Manual end-to-end test on a clean macOS VM (or fresh user account):**
    - Run `bash install.sh` from clone.
    - Confirm brew, git, lua, zsh, antidote installed (`command -v brew git lua zsh antidote`).
    - Confirm every manifest brew tool present (`brew list --formula` and `brew list --cask`).
    - Confirm every PATH-installing script entry succeeded by spot-checking each binary (`command -v bun opencode
      syft`). Confirm the ohmyzsh script entry succeeded by `[ -d "$HOME/.oh-my-zsh" ]`.
    - Open new Terminal/iTerm shell, confirm every existing alias and function works by diffing fresh captures
      against `/tmp/dotfiles-baseline-zsh.txt` from step 1.
    - Run twice; confirm second run reports all idempotent and exits cleanly.

33. **Manual end-to-end test on a clean Windows VM (or fresh user account):**
    - Run `pwsh install.ps1` from clone.
    - Confirm choco, git, lua, zsh installed (`Get-Command choco, git, lua, zsh`).
    - Confirm every manifest Windows tool present (`choco list`).
    - Confirm OpenCode script ran (`command -v opencode` from Git Bash). Confirm ohmyzsh installed
      (`[ -d "$HOME/.oh-my-zsh" ]` from Git Bash).
    - Open Git Bash, confirm `framework/bash_loader.sh` sources `shell/*.plugin.zsh` and every alias/function works
      by diffing fresh captures against `/tmp/dotfiles-baseline-bash.txt` from step 1.
    - Run twice; confirm idempotent.

34. **Capture before/after metrics for README.md:**
    - Line count: framework + autoloader + startup + install.sh + install.ps1 (before vs after).
    - Tool-add cost: lines changed to add a tool (before: 2 scripts × ~1 line = 2 + drift risk; after: 1 manifest
      line).

## Configuration

No new user-facing configuration keys. The Lua provisioner accepts CLI flags (`--tools-only`, `--scripts-only`,
`--configurators-only`, `--migrate`) but these are operator flags, not user-tunable behavior.

`~/.df_data/state.json` is internal state, not user config — users do not edit it (except to force a configurator
re-run by removing its key; see §6).

Existing env vars (`DF_ROOT_DIRECTORY`, `DF_DATA_DIR`, `DF_DEBUG_TIMING`) are preserved. `DF_ROOT_DIRECTORY` now
honors a pre-set value (fallback to `$HOME/Documents/GitHub/dotfiles`); `DF_DEBUG_TIMING` becomes a no-op in the
new architecture (no custom timing harness); document both in README.md.

## Migration

No database migrations. State migration only: legacy `migrations/.migration_history` flat-file (plus the private-repo
equivalent if present) → `~/.df_data/state.json` (JSON), handled by the new Lua migration in step 13. The legacy
files are left in place as audit trails; the new runner ignores them.

This migration is included in the implementation steps and runs automatically on the first provisioner invocation
after the rewrite ships.

## Tests

Dotfiles repo has no test framework today. Adding one (busted, ShellSpec) is out of scope per the "simplicity over
completeness" principle. Verification is manual end-to-end on clean VMs (steps 32-33) plus the byte-identical UX
verification in step 18 (alias / function / PATH diff against pre-change snapshot from step 1).

For each logical unit that contains logic, the verification approach:

| Unit                                    | Approach                                                                                          |
|-----------------------------------------|---------------------------------------------------------------------------------------------------|
| `provision/lib/state.lua`               | Manual: provision twice, confirm second run skips already-done items per `state.json`.            |
| `provision/lib/backend.lua` (brew/cask) | Manual: install one tool fresh, re-run, confirm "already installed" branch.                       |
| `provision/lib/backend.lua` (choco)     | Manual on Windows VM (step 33).                                                                   |
| `provision/lib/scripts.lua`             | Manual: provision twice, confirm scripts re-run both times without error.                         |
| `provision/lib/migrations.lua`          | Manual: run provisioner, confirm all three listed migrations execute once. Re-run, confirm none.  |
| Each `provision/configurators/*.lua`    | Manual: run, inspect the resulting plist/symlink/config-file. Re-run, confirm no change/error.    |
| Each `provision/migrations/*.lua`       | Manual: run, confirm intended state achieved. Re-run, confirm idempotent.                         |
| `framework/bash_loader.sh`              | Manual: launch bash (Git Bash on Windows), diff against `/tmp/dotfiles-baseline-bash.txt`.        |
| `.zshrc` + `zsh_plugins.txt`            | Manual: launch zsh on Mac, diff against `/tmp/dotfiles-baseline-zsh.txt`.                         |

Post-change comparison must produce an empty diff against the relevant baseline (allowing for ordering differences,
which `sort` handled when the baselines were captured).

## Documentation updates

- `README.md` — new install flow, manifest-edit instruction, note on Lua dependency, `DF_ROOT_DIRECTORY` env-var
  override, `DF_DEBUG_TIMING` no-op, before/after metrics from step 34.
- `.agents/AGENTS.md` — no changes (file-operation and language rules unchanged; no new architectural conventions
  introduced beyond what this plan documents).
- New `provision/README.md` — short developer doc explaining manifest schema, how to add a tool/script/configurator/
  migration, and how to force a configurator re-run by editing `state.json`. Single page, no sub-pages.
- New `provision/lib/vendor/README.md` — records `rxi/json.lua` upstream URL, license, and pinned commit hash.
- No user-facing CLI behavior changes, so no CLAUDE.md update needed.
