# Marc Beinder's Dotfiles

Personal development environment configuration for macOS and Windows — terminal, JetBrains settings,
provisioning, and shell plugins.

---

## Quick Install

**macOS**
```sh
bash install.sh
```

**Windows (PowerShell, run as Administrator)**
```powershell
pwsh install.ps1
```

Both scripts:
1. Install Homebrew (macOS) or Chocolatey (Windows) if missing.
2. Install Lua 5.4 and Git if missing.
3. Clone this repository to `$DF_ROOT_DIRECTORY` if not already present.
4. Hand off to `lua provision/main.lua <platform>` which runs the full provisioner.

---

## How It Works

### Shell Loader

The shell loader (`shell/shell.plugin.zsh`) sources every `shell/*.plugin.zsh` file in numeric order.
Zsh is the primary shell on macOS; bash is supported on Windows via `framework/bash_loader.sh`.

### Provisioner

All tool installation and configuration is driven by the Lua provisioner in `provision/`. The entry
point is `provision/main.lua`, which reads `provision/manifest.lua` and executes each entry:

- **Tools** — installed via Homebrew (macOS) or Chocolatey (Windows).
- **Configurators** — one-time setup scripts in `provision/configurators/`.
- **Migrations** — idempotent data-migration scripts in `provision/migrations/`.

### Adding a Tool

Add one entry to `provision/manifest.lua`:

```lua
{ name = "mytool",
  mac = { backend = "brew", id = "mytool" },
  win = { backend = "choco", id = "mytool" } },
```

No script edits are needed anywhere else.

---

## Environment Variables

### `DF_ROOT_DIRECTORY`

Controls where install scripts clone and where the provisioner looks for the repo.

```sh
export DF_ROOT_DIRECTORY=/path/to/your/dotfiles
bash install.sh
```

If unset, the default fallback is `$HOME/Documents/GitHub/dotfiles` (macOS/Linux) or
`%USERPROFILE%\Documents\GitHub\dotfiles` (Windows).

### `DF_DEBUG_TIMING`

This variable is a **no-op** in the current architecture. The legacy timing harness was removed as part
of the Lua modernization. There is no custom timing instrumentation in the new provisioner.

---

## Operational Notes

### Force a Configurator to Re-run

Configurators record their completion in `~/.df_data/state.json`. To force one to run again, remove
its key from that file:

```sh
# Example: force the ghostty configurator to re-run
# Open ~/.df_data/state.json and delete the "ghostty" key, then re-run:
lua provision/main.lua mac
```

Or you can delete the key with `jq`:

```sh
jq 'del(.configurators.ghostty)' ~/.df_data/state.json > /tmp/state.json && mv /tmp/state.json ~/.df_data/state.json
lua provision/main.lua mac
```

### Runtime Dependencies

| Dependency | Required for               | Notes                                   |
|------------|----------------------------|-----------------------------------------|
| Lua 5.4    | Provisioning               | Not needed for shell startup            |
| Homebrew   | macOS tool installation    | Installed automatically by `install.sh` |
| Chocolatey | Windows tool installation  | Installed automatically by `install.ps1`|
| zsh        | Shell plugins (macOS)      | Pre-installed on macOS                  |

> **Lua 5.4 is a hard runtime dependency for provisioning.** It is not required for shell startup — you
> can source the shell plugins without Lua installed.

---

## Private Configuration

User-specific and workflow-specific exports (API tokens, cert paths, etc.) live in the sibling private
repository at `~/Documents/GitHub/dotfiles-private/`. The shell loader sources
`~/.config/env.sh` / `~/.config/alias.sh` / `~/.config/func.sh` from that repo when present.

---

## Migration Impact

The Lua provisioner modernization consolidated the bash orchestration layer into a single Lua-driven
entry point. Key metrics:

### Line Counts

| Area | Before (shell/bash) | After (Lua) |
|------|---------------------|-------------|
| `framework/` (7 files) | 974 lines | removed |
| `autoloader/` (2 files) | 60 lines | removed |
| `startup/` (1 file) | 18 lines | removed |
| `install.sh` | 207 lines | 37 lines |
| `install.ps1` | 137 lines | 53 lines |
| `provision/` (Lua, excl. vendor) | — | 1,457 lines |
| **Total** | **1,396 lines** | **1,547 lines** |

The Lua total is higher because the provisioner is a proper library with state management, platform
abstraction, and per-platform backend routing — capabilities that were previously handled ad-hoc or
not at all. The install scripts themselves shrank by ~75%.

### Tool-Add Cost

| | Before | After |
|-|--------|-------|
| Add a tool | Edit `install.sh` (~1 line) + `install.ps1` (~1 line) = 2 edits across 2 files with drift risk | 1 line in `provision/manifest.lua` |
| Cross-platform consistency | Manual — easy to add Mac but forget Windows | Enforced by manifest structure |

---

## Oh-My-Zsh Plugins

The following OMZ plugins are loaded on macOS:

- colorize
- git
- terraform
- zsh-autosuggestions
- zsh-syntax-highlighting

`zsh-autosuggestions` uses the Tab key to accept suggestions (`bindkey '^I' autosuggest-accept`),
avoiding accidental command execution.

---

## JetBrains

Keymaps and code inspection profiles are stored in `JetBrains/`. The `copy_jetbrains_keymaps.sh` tool
copies them to the correct JetBrains IDE config directories.
