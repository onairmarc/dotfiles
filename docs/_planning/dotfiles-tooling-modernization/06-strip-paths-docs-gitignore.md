# Strip hardcoded paths, sibling-repo coordination, gitignore, README, metrics

## Dependencies

**Blocked by:** 04-rewrite-bootstrap-stubs.md, 05-migrate-shell-loader.md
**Blocks:** 07-vm-end-to-end-tests.md

---

## Context

Sub-plans 02-04 produced a working Lua provisioner and stub-style install scripts. Sub-plan 05 migrated the
shell loader. This sub-plan finishes the long-tail work:

- Strip the three remaining hardcoded `/Users/marcbeinder/...` paths.
- Move the `NODE_EXTRA_CA_CERTS` cert export to the sibling private repo and coordinate the cross-repo PR.
- Add `.DS_Store` and `.idea/` to `.gitignore` and untrack any committed instances.
- Update `README.md` to document the new install flow and the `DF_ROOT_DIRECTORY` env-var override.
- Capture before/after line-count + tool-add-cost metrics for the README.

After this sub-plan, the public repo is feature-complete for the modernization and ready for clean-VM
verification in sub-plan 07.

### dotfiles-private layout (reference)

`dotfiles-private` (sibling repo at `$HOME/Documents/GitHub/dotfiles-private/`) uses `.config/env.sh`,
`.config/alias.sh`, `.config/func.sh`, `.tools/github_token.sh`. The private entrypoint is sourced by `.zshrc`
(zsh) and `framework/bash_loader.sh` (bash), both updated in sub-plan 05.

---

## Steps

1. **Strip hardcoded user paths from `shell/10_env.plugin.zsh`** (formerly `config/env.sh`).
   - Replace `/Users/marcbeinder/Library/Application Support/Herd/config/php/83/` (line 11 in the pre-rename
     file) with `$HOME/Library/Application Support/Herd/config/php/83/`.
   - Replace `/Users/marcbeinder/Library/Application Support/Herd/bin` (line 55 in the pre-rename file) with
     `$HOME/Library/Application Support/Herd/bin`.
   - The Herd install layout is identical for every user under their own `$HOME`, so these paths stay in the
     public repo (just made user-agnostic).
   - The `NODE_EXTRA_CA_CERTS` export from `autoloader/mac.sh:26` was already removed when `autoloader/mac.sh`
     was deleted in sub-plan 05; no separate edit needed in the public repo.

2. **Append the moved cert export to `../dotfiles-private/.config/env.sh`.**
   - Edit the sibling repo file with the `Edit` tool:

     ```sh
     export NODE_EXTRA_CA_CERTS="$HOME/Library/Application Support/Herd/config/valet/CA/LaravelValetCASelfSigned.pem"
     ```

   - Commit and push the change in the dotfiles-private repo as a **separate PR**. Reference that PR in the
     public-repo PR description so reviewers know the cert path will not silently drop after deploy.
   - The Herd path itself is generic, but exporting it depends on the user actually using Herd/Valet, which is
     workflow-specific — private repo is the right home.

3. **Update `.gitignore`** to add the following entries (alphabetized within their group):

   ```
   .DS_Store
   .idea/
   ```

   In a **separate commit**, run `git rm --cached` on any tracked instances of these patterns (e.g. `git ls-files
   | grep -E '(\.DS_Store|\.idea/)' | xargs -r git rm --cached`).

4. **Update `README.md`** with the new install instructions and operational notes:
   - New install commands: `bash install.sh` (Mac) and `pwsh install.ps1` (Windows). Both bootstrap, then hand
     off to `lua provision/main.lua`.
   - Adding a tool = one line in `provision/manifest.lua`. No script edits.
   - Lua 5.4 is now a hard runtime dependency for **provisioning** (not for shell startup).
   - `DF_ROOT_DIRECTORY` env-var override: if set, the bootstrap and shell loader honor it; otherwise the
     fallback is `$HOME/Documents/GitHub/dotfiles`.
   - `DF_DEBUG_TIMING` is now a **no-op** (no custom timing harness in the new architecture).
   - To force a configurator to re-run, the user removes the relevant key from `~/.df_data/state.json` by hand.

5. **Capture before/after metrics for the README "Migration impact" section.**
   - Line count: total of `framework/` + `autoloader/` + `startup/` + `install.sh` + `install.ps1` before and
     after. Compute "before" from `git show <pre-migration-commit>:<file>` and `wc -l`. Compute "after" from
     the working tree.
   - Tool-add cost: lines changed to add a tool. Before: 2 scripts × ~1 line = 2 + drift risk. After: 1 manifest
     line.
   - Drop both numbers into a short "Migration impact" block in `README.md` (the Documentation-updates section
     of the master plan refers to this).

---

## Acceptance Criteria

- `shell/10_env.plugin.zsh` contains no `/Users/marcbeinder` substring (`grep -F '/Users/marcbeinder'
  shell/10_env.plugin.zsh` is empty). `grep -rF '/Users/marcbeinder' .` returns only matches under
  `docs/_planning/` (historical planning text, expected) and possibly inside `tools/mac_cleanup.sh` if it
  vendored such paths (vendored fork; out of scope).
- `../dotfiles-private/.config/env.sh` ends with the new `NODE_EXTRA_CA_CERTS` export line. A separate PR has
  been opened against the dotfiles-private repo and its URL is recorded in the public-repo PR description.
- `.gitignore` contains `.DS_Store` and `.idea/`. `git ls-files | grep -E '(\.DS_Store|\.idea/)'` is empty.
  The untrack commit is separate from the .gitignore edit commit.
- `README.md` documents: new install flow, manifest-edit instruction, Lua dependency, `DF_ROOT_DIRECTORY`
  override (with fallback), `DF_DEBUG_TIMING` no-op, configurator force-rerun procedure, and a "Migration
  impact" block with before/after line counts and the tool-add cost comparison.
- The shell-loader regression check from sub-plan 05 still passes: open a new zsh shell, capture the same
  outputs, `diff -u /tmp/dotfiles-baseline-zsh.txt /tmp/dotfiles-after-zsh.txt` is still empty.
- `bash install.sh` (re-run on the dev Mac, no clone needed) still completes 0 with the provisioner reporting
  all-idempotent.
