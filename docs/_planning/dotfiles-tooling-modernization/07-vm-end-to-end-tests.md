# Manual VM end-to-end tests (Mac + Windows)

## Dependencies

**Blocked by:** 04-rewrite-bootstrap-stubs.md, 06-strip-paths-docs-gitignore.md
**Blocks:** none

---

## Context

Sub-plans 02-06 produced the full Lua provisioner, the bootstrap stubs, the antidote + `shell/` + bash_loader
migration, the path-strip + sibling-repo coordination, and the README/gitignore updates. This sub-plan
verifies that **a fresh, clean machine** can install everything end-to-end and that a second invocation is
idempotent.

The development machine has accumulated state across the earlier sub-plans. Clean VMs (or fresh user accounts)
are the only honest way to confirm that:

- A user with no prior dotfiles state can run the stub and end up with the full environment.
- Every manifest entry installs cleanly from a cold start.
- The bash fallback loader on Windows produces the same alias / function / env-var surface that the baseline
  captured in sub-plan 01.

Both clean-VM tests use the baselines captured in sub-plan 01 (`/tmp/dotfiles-baseline-zsh.txt`,
`/tmp/dotfiles-baseline-bash.txt`) as the regression oracle. The baseline files must still exist on whichever
machine is running each test.

---

## Steps

1. **Manual end-to-end test on a clean macOS VM (or fresh user account):**
   - Run `bash install.sh` from clone.
   - Confirm brew, git, lua, zsh, antidote installed (`command -v brew git lua zsh antidote`).
   - Confirm every manifest brew tool present (`brew list --formula` and `brew list --cask`).
   - Confirm every PATH-installing script entry succeeded by spot-checking each binary (`command -v bun
     opencode syft`). Confirm the ohmyzsh script entry succeeded by `[ -d "$HOME/.oh-my-zsh" ]`.
   - Open new Terminal / iTerm shell, confirm every existing alias and function works by capturing fresh
     outputs (same script as sub-plan 01) into `/tmp/dotfiles-after-zsh.txt`, then run
     `diff -u /tmp/dotfiles-baseline-zsh.txt /tmp/dotfiles-after-zsh.txt`. Diff must be empty.
   - Run `bash install.sh` a second time; confirm provisioner reports every tool / configurator / migration as
     already done and exits 0.

2. **Manual end-to-end test on a clean Windows VM (or fresh user account):**
   - Run `pwsh install.ps1` from clone.
   - Confirm choco, git, lua, zsh installed (`Get-Command choco, git, lua, zsh`).
   - Confirm every manifest Windows tool present (`choco list`).
   - Confirm OpenCode script ran (`command -v opencode` from Git Bash). Confirm ohmyzsh installed
     (`[ -d "$HOME/.oh-my-zsh" ]` from Git Bash).
   - Open Git Bash, confirm `framework/bash_loader.sh` sources `shell/*.plugin.zsh` and every alias / function
     works by capturing fresh outputs (same script as sub-plan 01) into `/tmp/dotfiles-after-bash.txt`, then
     run `diff -u /tmp/dotfiles-baseline-bash.txt /tmp/dotfiles-after-bash.txt`. Diff must be empty.
   - Run `pwsh install.ps1` a second time; confirm idempotent (every tool / configurator / migration skipped,
     exit code 0).

---

## Acceptance Criteria

- A clean macOS VM (or fresh user account) provisioned solely via `bash install.sh` reaches a working state:
  brew, git, lua, zsh, antidote on `$PATH`; every manifest brew/cask tool present; every script entry
  successful (bun, opencode, syft, ohmyzsh); shell-startup diff against `/tmp/dotfiles-baseline-zsh.txt` is
  empty.
- A second run of `bash install.sh` on the same VM is idempotent (exit 0; provisioner summary shows zero
  installs and zero failures).
- A clean Windows VM (or fresh user account) provisioned solely via `pwsh install.ps1` reaches a working
  state: choco, git, lua, zsh on `Get-Command`; every manifest choco tool present; OpenCode + OMZ installed;
  Git Bash shell-startup diff against `/tmp/dotfiles-baseline-bash.txt` is empty.
- A second run of `pwsh install.ps1` on the same VM is idempotent (exit 0; provisioner summary shows zero
  installs and zero failures).
- Any deviation from these criteria (failure, non-empty diff, non-idempotent re-run) blocks shipping. Root-
  cause and fix in the relevant earlier sub-plan, then re-execute this sub-plan from scratch on a fresh VM /
  account.
