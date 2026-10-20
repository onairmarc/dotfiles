---
name: ui-review
description: >-
  Review a UI screen, component, or diff for visual quality, usability, accessibility, resilience, motion, and worthwhile improvements.
  Use for design critique or UI improvement discovery; ranks evidence-backed defects separately from optional design opportunities.
---

# UI review

Load `ui-common` once. Evaluate the interface against its users and task, not a preferred aesthetic. A review may conclude that no change is needed.

## Review workflow

1. Establish scope and mode: review-only by default; implement repairs only when requested. Read the brief, design constraints, affected screen, shared
   primitives, data flow, state transitions, and tests. For a diff, read its surrounding behavior and consumers, not only changed lines.
2. Inspect the rendered UI if available. Reproduce the main task and the relevant failure states. Record the viewport, fixture, theme, and input method.
3. Load the local owner for each applicable lens below; use optional specialists only when their scope and invocation rules fit. Don't load every skill.
4. Confirm each finding against the actual implementation. Separate observed defects, source-supported risks, and preference-based alternatives.
5. Rank by consequence and reach. In fix mode, repair confirmed in-scope defects and verify them; in review-only mode, return actionable findings without edits.

Done when the applicable lenses have evidence or explicit coverage gaps, every reported defect has a concrete consequence and location, and suggestions
fit the user's scope. Stop rather than padding the review with speculative issues or decorative work.

## Lenses

- **Task and interaction:** `ui-interaction-design`—discovery, action labels, forms, keyboard/focus, feedback, cancellation, and recovery.
- **Visual hierarchy:** `ui-visual-design`—reading path, grouping, density, type, color, alignment, and fit with the established product.
- **Motion:** `ui-motion`—purpose, frequency, responsiveness, interruption, reduced motion, and measured performance. A static interface isn't inherently lacking.
- **Mobile:** `ui-mobile`—touch, viewport, scroll, keyboard, fixed UI, safe areas, and hardware coverage.
- **Resilience:** `ui-resilience`—content extremes, missing data, full states, locale, zoom, and collection bounds.

## Defects versus opportunities

Defects need evidence: unreadable information, unreachable actions, lost work, wrong state, broken comparison, inaccessible operation, or a demonstrable
performance problem. Cite `file:line`, the reproduction condition, consequence, smallest suitable correction, and how to verify it.
Treat an unprofiled performance concern as a risk to measure, not proof of dropped frames.

An opportunity needs an observed friction or missed communication: clearer grouping, a shorter flow, useful inline recovery, stronger wayfinding, or
motion that explains a relationship. State the benefit, cost, and why the current design isn't enough. Include only high-value candidates, normally at
most three for a screen. Reject changes that add novelty, latency, or maintenance without helping the task.

Use impact levels:

- **Blocking:** the main task, essential information, or an accessibility requirement fails.
- **Significant:** completion remains possible but the problem causes recurring confusion, avoidable work, or material visual instability.
- **Polish:** a confirmed local inconsistency with limited task impact.

## Output

Lead with the verdict and scope tested. Give a compact table when there are findings:

| Impact | Location and condition | Problem and consequence | Correction and proof |
|--------|------------------------|-------------------------|----------------------|

Then list worthwhile opportunities separately, if any, and state verification gaps. When implementing, summarize fixes and checks rather than leaving
already-fixed items framed as unresolved findings. Don't report deliberate tradeoffs as defects or confuse a taste preference with a release blocker.

If the user wants a roadmap, hand confirmed findings to the repo's planning workflow. If they want alternatives, use `ui-explore`. Neither handoff is
automatic permission to create plan files, execute work, or expand the review into a whole-product audit.
