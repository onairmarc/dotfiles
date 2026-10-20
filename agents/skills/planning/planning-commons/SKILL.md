---
name: planning-commons
description: >-
  Required entry point for planning workflows. Read before feature-planning, northstar, pm-review, plan-review, plan-resync, plan-split, or plan-execute;
  selects shared references for paths, questions, plan formats, task tracking, delivery, fragility, Qlty, and UI design by scope and workflow stage.
---

# Planning commons

This index owns shared-reference selection for `feature-planning`, `northstar`, `pm-review`, `plan-review`, `plan-resync`, `plan-split`, and `plan-execute`.
The calling skill owns its workflow and output; each selected reference owns its rules. Point-of-use references in a workflow identify the relevant procedure,
not a second loading policy.
Resolve named skills in the repo's declared skill locations, then `~/.agents/skills/`; use the discovered directory for their reference files.

## Required loading protocol

1. Read this index before the calling skill's first operational step, including pre-flight and task-list setup. Identify the calling workflow and known scope.
2. Evaluate every condition below. Read each required reference in full before the stage that uses it; don't load references whose conditions don't apply.
   When scope is still unknown, defer scope-dependent selection until the idea, plan, or changes have been read, before drafting or evaluating them.
3. Recheck applicability when discovery, a user decision, or plan reconciliation changes scope. Load newly applicable references before continuing.
4. Load each reference once per context unless it changes or must be read fresh for verification. A reference such as `delivery-constraints` isn't a new workflow;
   it doesn't restart this index. Follow links needed to interpret the selected contract without recursively loading unrelated guidance.

Complete selection when every applicable concern has an owner and its reference is loaded before use. Record only meaningful skips or unavailable prerequisites;
don't add a reference-selection report to every response. Preserve the calling skill's permission boundaries: loading guidance doesn't authorize another audit,
prototype, plan, code edit, dependency install, or execution outside that workflow.

## Shared reference conditions

### Paths and standards

Read [paths.md](paths.md) before resolving planning, product-docs, discovery-brief, or northstar locations, or discovering project standards.
Applies to the location/standards steps in `feature-planning`, `northstar`, `pm-review`, `plan-review`, and `plan-resync`; also applies to `plan-split`
or `plan-execute` if they must resolve those locations or discover standards rather than consume the selected plan directory and supplied context.

### Questions and review severity

Read [review-loop.md](review-loop.md) before asking requirements or review questions with `question`, iterating an artifact against lenses, or classifying
BLOCK/WARN findings. Applies to any of the seven workflows when that branch is reached, including execution failure questions.
Keep a workflow's own severity scale when it defines one, such as PM business severity; use this reference for shared question and iteration rules.

### Plan and sub-plan format

Read [plan-format.md](plan-format.md) before `feature-planning` drafts a plan, `plan-review` evaluates its structure, `plan-resync` reconciles it,
`plan-split` extracts sub-plans, or `plan-execute` parses them. It owns artifact structure, dependency headers, and required copied blocks.
It doesn't apply to a northstar or PM discovery brief, which have their own formats.

### Plan-file deletion authority

Read [plan-file-deletion.md](plan-file-deletion.md) before `plan-split` writes sub-plans or `plan-execute` writes shared agent instructions or executes a plan set.
Also read it when creating, reviewing, or resyncing plan lifecycle/deletion instructions. Preserve its ownership rule in the required artifact blocks.

### Task tracking

Read [task-tracking.md](task-tracking.md) at startup for `plan-review`, `plan-resync`, `plan-split`, and `plan-execute`.
Seed the starter named for the calling skill before Step 0 and keep it current. `feature-planning`, `northstar`, and `pm-review` have no starter here.

### Delivery constraints

Read the `delivery-constraints` skill before creating, reviewing, resyncing, splitting, or executing an implementation plan.
Applies to `feature-planning`, `plan-review`, `plan-resync`, `plan-split`, and `plan-execute`, not vision-only or PM discovery/review work.
Preserve the constraints in emitted artifacts and execution instructions as required by the plan format and calling workflow.

### Proven failure-path contracts

When an implementation plan changes executable behavior or carries fragility findings, read the following contracts under the discovered
`fragility-commons` skill directory before designing, reviewing, extracting, or dispatching that work:

- `feature-planning` and `plan-resync`: `planning-contract.md` and `review-contract.md`.
- `plan-review`: `review-contract.md`.
- `plan-split` and `plan-execute`: `subplan-contract.md` and `verification-contract.md`.

The calling workflow still owns audit invocation, gate order, and remediation. For non-executable work, preserve any final gates the calling workflow requires;
don't invent a failure-path finding to justify them. `northstar` and `pm-review` describe product expectations, not code-level fragility proof.

### Configured Qlty code smells

Read [qlty-smells.md](qlty-smells.md) before the readiness check for planning, reviewing, resyncing, splitting, or executing code changes.
Applies to the five implementation-plan workflows, not vision-only or PM work. Reading the reference determines prerequisites; running Qlty requires both
an installed CLI and repository configuration. Follow the workflow's scan timing and preserve assigned checks when splitting. Never install/configure Qlty.

### UI design

Load `ui-common` when the idea, plan, remaining work, or reviewed changes affect a user interface: screens, controls, navigation, layout, copy, visible states,
accessibility, motion, or responsive behavior. Include backend changes when they alter a UI's observable state, feedback, or recovery contract.
Load it after scope is known and before making UI decisions or evaluating UI completeness; use its routes to select only relevant UI specialists.
Skip it for work with no interface impact; `northstar` uses the narrower principle-authoring condition below. UI preferences don't override approved intent,
product constraints, or the calling workflow's mode.

- `feature-planning`: turn applicable guidance into concrete design decisions, reachable states, acceptance criteria, and verification in the affected slices.
- `plan-review`: check those decisions and checks for gaps; repair the plan, not application code. Don't claim rendered quality from plan text alone.
- `plan-resync`: verify UI drift against approved intent and current components. Preserve outcomes; ask before changing the design's scope or goals.
- `plan-split`: copy each slice's UI decisions, state contracts, and checks into its sub-plan. Preserve shared tokens and component choices where needed.
- `plan-execute`: include `ui-common` and relevant routes in applicable guardrails for UI-changing sub-plans; bind coding agents to the concrete requirements.
  Verify reported UI checks against acceptance criteria; distinguish automated, browser, and hardware proof, and report unavailable checks honestly.
- `pm-review`: use it for persona workflows, feedback, recovery, accessibility, and completeness in both discovery and review; keep product severity and scope.
- `northstar`: load it only when defining or reviewing product-specific interface/experience principles. Record confirmed, actionable principles, not component
  recipes or an automatic aesthetic direction. A product having a UI isn't enough to load every UI specialist.

## Self-contained artifacts

These references guide the agent; emitted artifacts must not depend on access to this index or its reference files. Reproduce required blocks and concrete
applicable decisions, contracts, acceptance criteria, and verification steps in the artifact. “Follow `ui-common`” isn't a substitute for specifying the UI.
Execution instructions may additionally name guardrail skills, but those pointers supplement rather than replace the sub-plan's requirements.
