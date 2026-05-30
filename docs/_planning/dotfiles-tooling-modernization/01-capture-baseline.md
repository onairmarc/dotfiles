# Capture pre-change behavior snapshot

## Dependencies

**Blocked by:** none
**Blocks:** 05-migrate-shell-loader.md

---

## Context

The Dotfiles Tooling Modernization plan replaces the existing `__df_source_once` autoloader with antidote (on
zsh) plus a thin `bash_loader.sh` (on bash). Every alias, function, env var, and prompt currently produced by
the running shell must keep working byte-identically after the migration.

This sub-plan captures the **regression oracle** that all later verification steps diff against. It runs first
and only writes files outside the repo. No code changes happen here.

The Mac zsh baseline is the oracle for the shell-loader-migration test gate (`05-migrate-shell-loader.md`). The
Windows bash baseline is the oracle for the Windows VM end-to-end test (`07-vm-end-to-end-tests.md`).

This step must run **before any file rename or deletion** in the repo. If the snapshot is taken after the new
shell loader has already changed the environment, the diff loses its meaning.

---

## Steps

1. **Capture pre-change behavior snapshot.** Before any file rename or deletion, capture two baselines:

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

   Save both files **outside the repo** (e.g. `/tmp/` as shown, or any path that won't be touched by later
   sub-plans). Both files must persist until sub-plan 07 (`07-vm-end-to-end-tests.md`) completes.

---

## Acceptance Criteria

- `/tmp/dotfiles-baseline-zsh.txt` exists, is non-empty, and was created from a zsh session on the development Mac
  with the current (pre-migration) autoloader chain active.
- `/tmp/dotfiles-baseline-bash.txt` exists, is non-empty, and was created from a Git Bash session on a Windows
  machine with the current (pre-migration) autoloader chain active.
- Both files contain the `alias`, function name list, `$PATH` entries, and the filtered environment variable
  block produced by the commands above.
- No files inside the repo were modified, renamed, or deleted by this sub-plan.
