# Plan-file deletion authority

Plan files and plan directories are transient scaffolding, but the agent implementing sub-plans preserves them throughout implementation. Do not delete, move, rename,
stage for deletion, or restore a plan file or sub-plan file before every sub-plan succeeds.

Only the agent running `plan-execute` may delete the consumed plan directory. It does so only after every sub-plan succeeds and the repository's planning-lifecycle
policy permits deletion.

Plan splitters write and update sub-plan artifacts, but do not delete existing plan artifacts.
