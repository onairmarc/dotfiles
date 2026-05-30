# Populate manifest, configurators, migrations

## Dependencies

**Blocked by:** 02-build-provisioner-library.md
**Blocks:** 04-rewrite-bootstrap-stubs.md

---

## Context

The Lua provisioner runtime (entrypoint + library modules + empty manifest) was built in sub-plan 02. This
sub-plan populates the manifest with every tool / script / configurator / migration translated from the existing
`install.sh` and `install.ps1`, then ports the four shell configurators (iTerm, Ghostty, capslock, stripe
completion) and three migrations (two existing + one new legacy-history importer) to Lua.

After this sub-plan, `lua provision/main.lua mac` runs the full pipeline end-to-end on the development machine
and is idempotent on a second invocation. The old `install.sh` is still in place at this point (untouched); the
shell loader is also untouched.

### Manifest schema reference (the runtime built in sub-plan 02 expects this shape)

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
  },

  scripts = {
    { name = "opencode",
      mac  = { kind = "curl", url = "https://opencode.ai/install", pipe_to = "bash" },
      win  = { kind = "curl", url = "https://opencode.ai/install", pipe_to = "bash" } },
    { name = "bun",
      mac  = { kind = "curl", url = "https://bun.com/install",     pipe_to = "bash" } },                  -- mac-only
    { name = "syft",
      mac  = { kind = "curl", url = "https://get.anchore.io/syft",
               pipe_to = "sudo sh -s -- -b /usr/local/bin" } },                                            -- mac-only
  },

  configurators = {
    { name = "iterm",            module = "configurators.iterm",            platforms = { "mac" } },
    { name = "ghostty",          module = "configurators.ghostty",          platforms = { "mac" } },
    { name = "capslock",         module = "configurators.capslock",         platforms = { "mac" } },
    { name = "stripe_completion",module = "configurators.stripe_completion",platforms = { "mac", "win" } },
  },

  migrations = {
    "migrations.20250830_124338_setup_df_data_directory",
    "migrations.20250830_124630_move_sys_cleanup_marker",
    "migrations.20251201_000000_import_legacy_migration_history",
  },
}
```

Schema notes:

- `tap` (optional, brew only): when set, `backend.brew.install` runs `brew tap <tap>` before the install. The `id`
  field is used verbatim, so for tap-served formulas it should be the fully qualified `<tap>/<formula>` form.
- `app` (optional, cask only): an absolute `.app` bundle path used as a pre-install existence check; mirrors
  current `install_tool` behavior in `install.sh:15`.
- `kind = "curl"` is the only script kind. `pipe_to` is the shell command that receives the downloaded payload
  on stdin. Scripts have no version, no checksum, and no per-entry state — they always re-run on every provision
  and rely on the upstream installer's own idempotency.
- Configurators have no `version` field. Each runs at most once per machine (tracked by name in
  `state.configurators_run`). To force re-apply, the user removes the relevant key from `~/.df_data/state.json`
  by hand.

---

## Steps

1. **Write `provision/manifest.lua`.**
   - Translate every `install_tool` call from `install.sh:148-175` and every `Install-ChocoTool` call from
     `install.ps1:102-116` into a single merged `tools` table. Use the `install.sh` list as the master superset.
     Mac-only tools (not in `install.ps1`): `bash`, `chroma`, `cliclick`, `font-jetbrains-mono`, `gh`,
     `git-filter-repo`, `herd`, `pygments`, `raycast`, `shottr`, `stripe-cli`, `trivy`, `ghostty`.
   - Add Zsh as a tool for both platforms (`{ name = "zsh", mac = { backend = "brew", id = "zsh" },
     win = { backend = "choco", id = "zsh" } }`). The current `install.sh:115-121` and `install.ps1:93-99`
     install zsh imperatively; moving it into the manifest eliminates the stub-level branch.
   - Add `antidote` as a mac-only brew install (`{ name = "antidote", mac = { backend = "brew", id = "antidote" } }`).
   - Drop brew-installed `zsh-autosuggestions` and `zsh-syntax-highlighting` from the manifest entirely —
     antidote will clone them itself per `zsh_plugins.txt` (sub-plan 05); the brew copies become unsourced.
   - Use the `tap` field for `terraform` (`tap = "hashicorp/tap"`, id = `hashicorp/tap/terraform`).
   - Use per-platform `id` for `chrome` (`google-chrome` cask, `googlechrome` choco).
   - Translate the three `curl | bash`-style installers (OpenCode, Bun, Syft) into `scripts`. OpenCode is
     mac+win; Bun and Syft are mac-only.
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
     `.zshrc`. Idempotency: `$HOME/.oh-my-zsh` existence is the OMZ installer's own short-circuit.
   - List the four configurators in `configurators` with the platforms each applies to.
   - List the two existing migrations plus the new legacy-history-import migration in `migrations`.

2. **Port `configure_iterm`, `configure_ghostty`, `remap_capslock_to_escape`, and the inline stripe-completion
   block from `install.sh` into Lua modules under `provision/configurators/`.**
   - `iterm.lua`: replicates `install.sh:25-45` via `os.execute` calls (`defaults write`, `PlistBuddy`).
   - `ghostty.lua`: replicates `install.sh:47-66` via `os.execute` calls (`mkdir`, `mv`, `ln -s`).
   - `capslock.lua`: `os.execute("bash " .. root .. "/tools/remap_capslock.sh --enable")` (delegates to kept
     shell tool).
   - `stripe_completion.lua`: replicates `install.sh:196-204` via `os.execute` calls.
   - Each configurator records completion in `state.configurators_run` (timestamp only) and is skipped on
     subsequent provisions.

3. **Port the two existing shell migrations to Lua under `provision/migrations/`.**
   - File names: `20250830_124338_setup_df_data_directory.lua` and `20250830_124630_move_sys_cleanup_marker.lua`.
   - Read each shell migration; translate its `mv` / `mkdir` / `rm` calls to Lua via `os.execute` (avoid adding
     `lfs` dependency).
   - Each module returns `{ description = "...", up = function() ... end }`.
   - Test each migration's idempotency by running provisioner twice in a row and confirming no errors.

4. **Add `provision/migrations/20251201_000000_import_legacy_migration_history.lua`.**
   - Reads `$DF_ROOT_DIRECTORY/migrations/.migration_history` (line-per-name flat file, if present). For each
     line, sets `state.migrations_run[<line>] = "imported"`.
   - If `$HOME/Documents/GitHub/dotfiles-private/.migrations/.migration_history` is present, for each line sets
     `state.migrations_run["private:" .. <line>] = "imported"`.
   - Does NOT delete either legacy file. Both remain as audit trails; the new runner ignores them.
   - The `private:` namespace prefix is a recorded convention in `state.migrations_run`; there is no separate
     map key.

---

## Acceptance Criteria

- `provision/manifest.lua` contains every tool from `install.sh:148-175` and `install.ps1:102-116`, plus `zsh`,
  `antidote` (mac-only), and the new `ohmyzsh` script entry; no brew `zsh-autosuggestions` /
  `zsh-syntax-highlighting` entries remain.
- `provision/manifest.lua` lists all four configurators and all three migrations.
- All four `provision/configurators/*.lua` modules exist and replicate their `install.sh` counterparts.
- All three `provision/migrations/*.lua` modules exist; the two ported ones run idempotently.
- `lua provision/main.lua mac` on the development machine completes end-to-end with exit code 0, installs/
  skips every manifest tool, executes every script, runs every configurator once, runs every migration once,
  and writes the resulting `~/.df_data/state.json`.
- A second invocation of `lua provision/main.lua mac` is a no-op: every tool reports "already installed",
  every configurator reports skipped (timestamp present), every migration reports skipped, scripts re-run
  without error. Exit code 0. Summary counts show 0 failures.
- Removing any single key from `state.configurators_run` and re-running the provisioner re-runs only that
  configurator.
- `state.migrations_run` after the legacy-history-import migration contains every entry that was in
  `migrations/.migration_history` (bare-keyed) and every entry in
  `dotfiles-private/.migrations/.migration_history` (`private:`-keyed, if the file existed).
