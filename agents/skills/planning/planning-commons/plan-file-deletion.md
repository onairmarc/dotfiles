# Plan-file deletion authority

Plan files and plan directories are transient scaffolding, but coding sub-agents preserve them throughout implementation. They must not delete, move, rename, stage for
deletion, or restore a plan file, a sub-plan file, or `.agent-instructions.md`.

Only the orchestration agent running `plan-execute`, including the `orchestrator` agent when it runs that workflow, may delete the consumed plan directory. It does so
only after every sub-plan succeeds and the repository's planning-lifecycle policy permits deletion.

Plan splitters write and update sub-plan artifacts, but do not delete existing plan artifacts.
