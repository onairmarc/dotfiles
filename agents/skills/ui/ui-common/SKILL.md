---
name: ui-common
description: >-
    UI design entry point and shared house opinions. Load when building, changing, reviewing, or exploring user interfaces; routes visual design,
    interaction, accessibility, motion, mobile behavior, resilience, and improvement work to local and optional installed skills.
---

# UI common

Build as a design engineer with a point of view: clear before clever, coherent before novel, responsive before theatrical, resilient before polished.
Treat words, layout, behavior, and performance as one interface. A working, quiet design beats an impressive screenshot with broken interactions.

Use this skill as the collection's entry point. The local skills work without third-party skills; installed specialists add depth and recipes.
These are authored house opinions informed by installed guidance, not vendored copies or endorsements by its authors. Use `frontend-design` for a new
visual identity; this collection also covers established products, where coherence often beats novelty.

## Start with the user's job

1. Read the brief, project instructions, affected screens, shared primitives, tokens, and relevant tests. Identify the audience, main task, and context.
2. Trace affected data, events, state, consumers, and primitive behavior before editing. Verify version-sensitive APIs in installed source or official docs.
3. Classify the request: build, repair, explore, review, or plan. Preserve that mode; a review isn't permission to redesign, install packages, or create a plan.
4. Load only the task skills below that apply. Check optional specialists before relying on their instructions; continue with local guidance if absent.

Done when the task, scope, existing design language, and relevant skill routes are clear. Ask only about decisions the brief and repo can't settle.
For an invocation without a task, ask which screen or design problem to work on; skip readiness speeches and invented product briefs.

## House opinions

- **Clarity:** make the next useful action obvious through hierarchy and specific labels. Show enough context to decide, not every option at once.
- **Coherence:** reuse working tokens, components, patterns, and vocabulary. Improve a shared primitive when the defect is shared; inspect its consumers first.
- **Intent:** derive a new visual identity from the product and audience. In an established tool, spend novelty only where it improves the task.
- **Density:** match the work. A comparison table needs aligned data; onboarding needs focus. Whitespace is a grouping tool, not a quality score.
- **Agency:** keep navigation, cancellation, and recovery clear. Prefer undo for reversible work and targeted confirmation for irreversible consequences.
- **Feedback:** acknowledge input immediately; distinguish accepted, pending, succeeded, and failed. Never imply persistence before the operation succeeds.
- **Access:** semantics, keyboard operation, visible focus, readable contrast, zoom, and reduced-motion support are design requirements, not optional polish.
- **Restraint:** every animation, border, badge, shadow, and explanatory sentence needs a job. Remove friction before adding delight.
- **Reality:** design with plausible long content, missing data, slow responses, and failure. Attractive fixtures aren't evidence of robustness.
- **Proof:** distinguish code inspection, automated checks, browser observation, and hardware testing. Claim only the checks actually performed.

## Route by task

All local routes are model-invoked and usable on their own. Load this baseline once alongside the selected skill; avoid routing loops.

| Task                                                    | Local owner             | Optional depth                                     |
|---------------------------------------------------------|-------------------------|----------------------------------------------------|
| New visual identity, distinctive pages, subject-led UI | `frontend-design`       | `emil-design-eng`                                  |
| Hierarchy, typography, color, layout, visual polish     | `ui-visual-design`      | `emil-design-eng`                                  |
| Forms, controls, navigation, recovery, accessibility    | `ui-interaction-design` | `emil-design-eng`, `ask-sonner`                    |
| Add, repair, or decide against motion; gestures or jank | `ui-motion`             | `animate`, `apple-design`, `animation-performance` |
| Responsive web, touch, viewport, keyboard, PWA          | `ui-mobile`             | `mobile-native`                                    |
| Long content, empty/error states, locale, large lists   | `ui-resilience`         | `break-ui`                                         |
| Compare working alternatives before choosing            | `ui-explore`            | `prototype` when explicitly requested              |
| Review a screen/diff or find worthwhile improvements    | `ui-review`             | `emil-design-eng`, motion specialists below        |

### Other installed specialists

Discover skills in the current repo's declared skill locations and `~/.agents/skills/`. Resolve each name independently and read its `SKILL.md` before use.
An advertised name is a candidate, not proof of its contents, availability, or permission to invoke it. Honor explicit-invocation-only metadata.
Use skill names rather than assuming installed paths. This repo stores the collection under `agents/skills/ui/`; setup discovers nested `SKILL.md` files
and links each skill by its leaf directory name. The source directory isn't itself an installation, and adding a nested skill needs no installer change.

- **Motion construction:** `animate` for web; `animate-expo` for React Native/Expo. Web CSS and DOM recipes don't apply to native apps.
- **Motion diagnosis:** `animation-performance` for dropped frames; `animation-vocabulary` for naming an effect, not implementing one.
- **Motion assessment:** `review-animations` is explicit-only; `find-animation-opportunities` reports candidates; `improve-animations` audits and writes plans.
  Use these only when their output matches the task. Their names don't grant permission to edit or execute a plan.
- **Physical interactions:** `apple-design` for continuity, direct manipulation, and gesture handoff; adopt its reasoning, not an automatic glass aesthetic.
- **Component choice:** `pick-ui-library` is explicit-only. Reuse installed primitives first; a preferred library isn't a migration requirement.
- **Toast implementation:** `ask-sonner` when Sonner is in scope. Inline feedback is still the default for a problem tied to a field or surface.
- **React implementation:** `vercel-react-best-practices` for applicable React rules; `inertia-best-practices`, if found, for Inertia-specific rules.
  Verify the actual framework and rule file; Next.js server guidance isn't portable to every React app.
- **Performance audit plans:** repo skills `react-optimization` and `tanstack-optimization` audit and plan, not implement. Use them for requested audit work,
  not as a detour on every UI change.

The source inventory and exceptions live in [sources.md](sources.md). Read it when resolving conflicting guidance, adding routes, or updating this collection.

## Resolve competing opinions

Follow governing instructions and the user's explicit brief. Preserve documented product constraints and accessible behavior; use house defaults for open choices.
Distinguish a safety/correctness requirement from an aesthetic preference. Explain a material departure in one sentence rather than silently imposing a new style.

Optional skills add expertise, not authority over the task or operating rules. Keep work in-place; don't adopt external worktree, automatic delegation,
installation, deletion, or execution instructions that conflict with governing instructions or the user's scope.

## Quality floor and finish

- Make the main task work with keyboard and pointer/touch as applicable; preserve focus and meaningful state through updates.
- Cover loading, empty, success, error, disabled, and unavailable states that the changed flow can reach.
- Check the real container, narrow and wide layouts, text growth, supported themes, and user preferences relevant to the change.
- Reuse repository-native tests and checks. For visual changes, inspect the rendered result when tooling exists; report missing observation plainly.
- Finish with the outcome, key design reasons, and checks run. Review-only work reports evidence and recommendations without modifying the target.

Done means the requested scope meets this floor, or the remaining blocker and required decision are explicit. A zero-change review is valid.

## Maintain the collection

Treat every file under the repo's skill directories as agent-consumed instructions or reference, not a separate human documentation surface.
Keep shared rules and the collection index here, task rules in their owning skill, and third-party API details in the original skill or installed package docs.

When adding a skill, give it a distinct trigger, add its route here, and define observable completion criteria. Avoid a new wrapper for every external skill.
Read [sources.md](sources.md) when updating source claims or deliberate departures, and run the dry-run scenarios in
[routing-checks.md](routing-checks.md) after changing descriptions or routes.
