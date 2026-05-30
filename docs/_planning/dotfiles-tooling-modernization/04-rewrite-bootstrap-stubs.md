# Rewrite install.sh + install.ps1 as Lua-handoff stubs

## Dependencies

**Blocked by:** 03-populate-manifest-and-configurators.md
**Blocks:** 06-strip-paths-docs-gitignore.md, 07-vm-end-to-end-tests.md

---

## Context

The Lua provisioner (sub-plan 02) and its manifest + configurators + migrations (sub-plan 03) are now in place
and verified to run end-to-end on the development machine. This sub-plan replaces the existing 200+ line
`install.sh` and 130+ line `install.ps1` with thin ~40-line bootstrap stubs that install the package manager,
Git, and Lua, clone the repo if absent, then `exec` the Lua provisioner.

All per-tool logic, configurators, and the OMZ install have already moved to the manifest. After this sub-plan
the stub scripts contain no per-tool branches and cannot drift between platforms.

The shell loader (autoloader, `.zshrc`, `framework/`) is NOT touched here. The current shell loader keeps
working unchanged until sub-plan 05 migrates it.

### DF_ROOT_DIRECTORY resolution (shared rule)

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

---

## Steps

1. **Rewrite `install.sh` as ~40-line bootstrap.** Skeleton:

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

   Delete every `install_tool` line, every `configure_*` function, and every inline curl block — they all live
   in Lua now. Zsh and Oh My Zsh installs (currently `install.sh:115-131`) have already moved to the manifest
   (sub-plan 03) and are no longer part of the stub. The `source "./framework/__df_autoloader.sh"` line at the
   top of the current `install.sh` is also removed (the stub no longer needs the autoloader's helpers).

2. **Rewrite `install.ps1` as ~40-line bootstrap.** Skeleton:

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
   (currently `install.ps1:118-129`) have already moved to the manifest (sub-plan 03) and are no longer part
   of the stub.

---

## Acceptance Criteria

- `install.sh` is ≤ ~50 lines (target ~40) and contains no `install_tool` invocations, no `configure_*`
  functions, no inline `curl ... | bash` blocks, no zsh / OMZ install logic, and no `source` of any framework
  file.
- `install.ps1` is ≤ ~50 lines (target ~40) and contains no `Install-ChocoTool` invocations, no zsh install
  logic, and no OpenCode install logic.
- Both stubs read `DF_ROOT_DIRECTORY` via the env-var-with-fallback rule from Context.
- Both stubs clone the repo if `DF_ROOT_DIRECTORY` does not exist.
- Running `bash install.sh` on the development Mac (where the repo is already cloned and the dependencies are
  already installed) completes with exit code 0, hands off to `lua provision/main.lua mac`, and the provisioner
  prints its summary with no failures.
- A second run of `bash install.sh` is idempotent — brew install steps skip, clone skips, provisioner reports
  every tool / configurator / migration as already done.
- `pwsh install.ps1` validation in production happens during the Windows VM end-to-end test in sub-plan 07;
  for this sub-plan a dry-read of the file by the developer is sufficient confirmation.
