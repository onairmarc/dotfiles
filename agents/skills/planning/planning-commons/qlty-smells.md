# Qlty code-smell reduction

Use this workflow only when the repository already has both prerequisites:

1. `qlty` is available on `PATH` (`command -v qlty`).
2. `.qlty/qlty.toml` exists at the repository root.

When either prerequisite is missing, record that Qlty is unavailable for this run and continue without it. Do not install Qlty, run `qlty init`, create or edit
`.qlty/qlty.toml`, or change Qlty settings. Configuration belongs to the project, not to this workflow.

## Scan and use the results

When Qlty is available, run `qlty smells --all` from the repository root before planning or reviewing implementation work. Treat its findings as a baseline:

- Capture the reported smell types and locations relevant to the code the work will change.
- Add narrowly scoped remediation to the plan when it can reduce an existing smell in that affected code without changing the feature's behavior or expanding into unrelated
  cleanup.
- Do not add Qlty remediation for generated, vendored, test-only, or unrelated code unless the requested work already includes it.
- Keep the original command output or a precise summary in the working context. Do not copy transient CLI output into durable product documentation.

## Verification

After each behavioral slice that changed code reported by the baseline, run `qlty smells --all <affected paths>` in addition to the repository-native tests. Before final
completion, run `qlty smells --all` from the repository root again.

Compare the final findings with the baseline. The implementation must not add a smell in changed code and must remove every baseline smell the plan assigned to that
slice. Fix eligible findings during the current work, then rerun the affected scan. If an existing smell remains outside the changed scope, record it as unchanged rather
than adding unrelated work.

Use only `qlty smells`; do not substitute `qlty check`, `qlty fmt`, or another Qlty command.
