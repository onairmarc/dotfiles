# Migrate shell loader to antidote + shell/ + bash_loader

## Dependencies

**Blocked by:** 01-capture-baseline.md
**Blocks:** 06-strip-paths-docs-gitignore.md

---

## Context

This sub-plan replaces the custom `__df_source_once` autoloader with antidote (on zsh) plus a thin
`framework/bash_loader.sh` (on bash). Every alias, function, env var, and prompt currently produced by the
shell must keep working byte-identically after the migration — the regression oracle is the baseline captured
in sub-plan 01.

The Lua provisioner work in sub-plans 02-04 is independent of this work; either ordering is correct, but this
sub-plan's blocked_by includes only 01 to express the true minimum dependency. The execution order is still
sequential per the project's plan-execute convention.

### Why full antidote integration

The current `__df_source_once` autoloader hand-rolls source-once semantics, a brew-prefix cache, and a startup
timing harness. antidote does the same with less code. This sub-plan:

- Loads upstream plugins via antidote: `ohmyzsh/ohmyzsh`, `zsh-users/zsh-autosuggestions`,
  `zsh-users/zsh-syntax-highlighting`.
- Loads the local `shell/` directory as a single antidote plugin whose entry script (`shell/shell.plugin.zsh`)
  sources every numbered `.plugin.zsh` sibling in lexical order.
- Replaces the OMZ-specific config that used to live in `config/omz.sh` (`ZSH_THEME`, `ZSH_CUSTOM`,
  `zstyle ':omz:update'`, bindkey, colorize style) with OMZ prelude / postlude blocks in `.zshrc`.
- Provides a 30-line `framework/bash_loader.sh` that runs the same loop for non-zsh shells (Git Bash on
  Windows), so both shells source the same files in the same order.

### File-rename map (single `shell/` directory)

The `config/` and `tools/` split is collapsed so a single lexical sort yields the current interleaved load
order:

| Original (autoloader/mac.sh order) | New filename                                |
|------------------------------------|---------------------------------------------|
| `config/omz.sh`                    | *(deleted — OMZ logic moves to .zshrc)*     |
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

The `.plugin.zsh` extension is required for antidote to recognize the local plugin's entry script; the other
files use the same extension for visual consistency. Contents remain bash-compatible POSIX shell (no zsh-only
syntax introduced), so `framework/bash_loader.sh` sources them with no per-file transformation.

### is_mac guards (Windows-skipped files)

Files Windows does not currently load (per `autoloader/windows.sh`: only `env`, `color`, `alias`, `func`, `aws`,
`docker`) must short-circuit on non-mac to preserve current Windows behavior. Each affected file gets a guard
at the very top:

| File                                            | Guard line                                    |
|-------------------------------------------------|-----------------------------------------------|
| `shell/70_mac.plugin.zsh`                       | `is_mac || return 0`                          |
| `shell/80_mac_cleanup_checker.plugin.zsh`       | `is_mac || return 0`                          |
| `shell/85_nano.plugin.zsh`                      | `is_mac || return 0`                          |
| `shell/90_stripe.plugin.zsh`                    | `is_mac || return 0`                          |
| `shell/95_tmux.plugin.zsh`                      | `is_mac || return 0`                          |

`is_mac`, `is_windows`, and `is_linux` are defined in `shell/40_func.plugin.zsh` (formerly `config/func.sh:216,
220, 224`), which loads before any guarded file in lexical order.

---

## Steps

1. **Create `zsh_plugins.txt`** in repo root with these four lines:

   ```
   ohmyzsh/ohmyzsh                                  # OMZ first
   zsh-users/zsh-autosuggestions                    # antidote clones into its cache
   zsh-users/zsh-syntax-highlighting                # antidote clones into its cache
   $DF_ROOT_DIRECTORY path:shell                    # local plugin (entry script: shell/shell.plugin.zsh)
   ```

2. **Create `shell/shell.plugin.zsh`** as the antidote entry script for the local plugin:

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

3. **Rewrite `.zshrc`** to this form:

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

4. **Rewrite `entrypoint.sh`** to this form (zsh short-circuits; bash continues to the loader):

   ```sh
   if [ -n "$ZSH_VERSION" ]; then
     return 0   # .zshrc handles everything via antidote
   fi
   : "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
   export DF_ROOT_DIRECTORY
   source "$DF_ROOT_DIRECTORY/framework/bash_loader.sh"
   ```

5. **Write `framework/bash_loader.sh`**:

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

6. **Rename `config/*.sh` and `tools/*.sh` files into `shell/`** with `.plugin.zsh` extension per the
   rename-map table in Context. Use `git mv` so history is preserved. Verify each rename touches exactly one
   file. After all renames, run `ls shell/ | sort` and confirm the lexical order matches the table
   top-to-bottom.

7. **Delete `config/omz.sh`** (the OMZ-specific prelude/postlude logic now lives in `.zshrc`). Then delete the
   now-empty `config/` parent directory. `tools/` retains `mac_cleanup.sh`, `copy_jetbrains_keymaps.sh`,
   `agent_symlink.sh`, `remap_capslock.sh`, `tmux.conf` — keep it.

8. **Add internal `is_mac || return 0` guards** to every file Windows does not currently load, per the table
   in Context. Verify `is_mac` is in scope at each guard site: `grep -n 'is_mac\|is_windows\|is_linux'
   shell/40_func.plugin.zsh` must show the function definitions.

9. **Update `shell/40_func.plugin.zsh`** to source `framework/logging_functions.sh` at its top:

   ```sh
   source "$DF_ROOT_DIRECTORY/framework/logging_functions.sh"
   ```

   This replaces the autoloader-mediated load. `log_error` (used at `config/func.sh:24, 77, 90, 263` in the
   pre-rename file) keeps working.

10. **Update `tools/copy_jetbrains_keymaps.sh` lines 6-15** to drop the autoloader dependency:

    ```sh
    # Resolve repo root if not already set.
    if [[ -z "${DF_ROOT_DIRECTORY:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        export DF_ROOT_DIRECTORY="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi

    source "$DF_ROOT_DIRECTORY/framework/logging_functions.sh"
    ```

    All references to `log_info` / `log_error` / `log_success` further down the file keep working.

11. **Delete framework + autoloader + startup files no longer needed.** Confirm with the user before deleting
    (per `.agents/AGENTS.md` file-operation rules). Targets:
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

    `framework/logging_functions.sh` is **NOT** deleted (still sourced by `shell/40_func.plugin.zsh` and
    `tools/copy_jetbrains_keymaps.sh`). All seven `log_*` functions (`log_info`, `log_success`, `log_warning`,
    `log_error`, `log_debug`, `log_note`, `log_plain`) are retained verbatim — `dotfiles-private` may call any
    of them, so trim is skipped.

    `tools/mac_cleanup.sh` is **NOT** modified or renamed. It is invoked by `mac_cleanup()` in
    `shell/40_func.plugin.zsh` via `bash $DF_ROOT_DIRECTORY/tools/mac_cleanup.sh`. Leave untouched.

---

## Acceptance Criteria

- `zsh_plugins.txt` exists in repo root with the four lines from step 1.
- `shell/shell.plugin.zsh` exists with the entry-script loop from step 2.
- `shell/` contains exactly the eleven `[0-9]*_*.plugin.zsh` files from the rename-map table, with `git log
  --follow` showing history continuity for each one.
- `config/` directory no longer exists. `tools/` directory still exists with `mac_cleanup.sh`,
  `copy_jetbrains_keymaps.sh`, `agent_symlink.sh`, `remap_capslock.sh`, `tmux.conf` only.
- `framework/` contains only `logging_functions.sh` (verbatim) and the new `bash_loader.sh`. All other files in
  `framework/` are deleted, and `framework/migrations/` directory is gone.
- `autoloader/` and `startup/` directories no longer exist.
- `.zshrc`, `entrypoint.sh`, `framework/bash_loader.sh`, `tools/copy_jetbrains_keymaps.sh`, and
  `shell/40_func.plugin.zsh` match the bodies shown in steps 3, 4, 5, 10, 9 respectively.
- The five guarded files from the is_mac-guard table in Context each begin with `is_mac || return 0`.
- **Regression check (mandatory)**: open a new zsh shell on the development Mac, capture the same outputs as
  the baseline script in sub-plan 01 into `/tmp/dotfiles-after-zsh.txt`, then run
  `diff -u /tmp/dotfiles-baseline-zsh.txt /tmp/dotfiles-after-zsh.txt`. The diff must be empty.
- `bash install.sh` (still the new stub from sub-plan 04, repo already cloned) continues to exit 0 — the
  provisioner is unaffected by shell-loader changes.
