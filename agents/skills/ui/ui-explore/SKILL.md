---
name: ui-explore
description: >-
  Compare working UI alternatives when a design decision needs to be seen or tried. Use for requested variants, visual exploration, or interaction
  prototypes; keeps experiments separate from shipping UI and waits for a choice before promotion.
---

# UI explore

Load `ui-common` once. Explore only when the request calls for alternatives or an unresolved decision needs a runnable answer; routine fixes don't need a picker.
The explicit-only external `prototype` skill can add a harness when the user requests it. Read the installed version before assuming its workflow.

## Workflow

1. Name the decision and success criterion: for example, “Which layout makes comparing three plans easiest at the real mobile width?”
2. Inspect the stack, content, tokens, available experiment surfaces, and relevant interaction paths. Preserve the current shipping flow.
3. Choose two or three distinct directions unless asked otherwise. Name the meaningful axis—density, hierarchy, layout, or interaction model.
   Color swaps and different copy alone don't answer a structural design question.
4. Build alternatives in an existing story/demo surface or a development-only route in the current working tree. Use realistic context, data, and working
   task-relevant controls. Clearly mark simulated operations; never wire experimental destructive controls to live data.
5. Compare at full usable size with the same data and viewport. A small accessible picker can switch instantly; it must not obscure or influence the design.
   Keep keyboard shortcuts out of text-entry controls and make selection state clear.
6. Verify every variant, show its tradeoff, recommend one based on the stated criterion, and stop for the user's choice. A prototype isn't permission to promote it.

Done when each variant is reachable, works for the decision being tested, and can be compared fairly; report where to try it and what remains simulated.

## Promotion

After selection, integrate only the chosen direction when authorized. Reuse production primitives and tests rather than importing the experiment harness.
Recheck the common quality floor and relevant resilience cases. Remove temporary artifacts only with the required deletion approval; retain useful fixtures or
stories when requested. Don't create a branch, worktree, dependency, or permanent comparison surface merely because an external recipe prescribes one.
