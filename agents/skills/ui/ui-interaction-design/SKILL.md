---
name: ui-interaction-design
description: >-
  Design UI behavior for controls, forms, navigation, overlays, feedback, and recovery. Use when adding interactions or fixing confusing flows,
  keyboard/focus failures, inaccessible controls, or unclear loading and error states.
---

# UI interaction design

Load `ui-common` once. Start with what the person can do and what happens next, not the component's appearance.

## Trace the flow

1. Read the trigger, state owner, event handlers, validation, async operation, resulting UI, and affected consumers. Inspect the existing primitive's behavior.
2. Map reachable states and transitions, including cancellation, repeated activation, failure, retry, and navigation away.
3. Reuse semantic HTML and established accessible primitives. Prefer the project's working control over a custom imitation or a new dependency.
4. Implement only the requested behavior; test both the main task and recovery with keyboard and pointer/touch as applicable.

Done when the user can discover, complete, cancel where appropriate, and recover from the flow without lost input, hidden focus, or false success.

## Controls and navigation

- Use links for navigation and buttons for actions. Keep native activation, open-in-new-tab, and form behavior unless the task calls for a tested alternative.
- Name actions by the outcome: “Save changes,” “Send invitation,” or “Delete project.” Keep that verb consistent through progress, result, and retry.
- Show immediate press feedback, but commit through the normal activation path. Pointer-down feedback isn't permission to fire destructive actions early.
- Keep keyboard focus visible and unobscured. Preserve a logical tab order; use the established widget pattern for arrows, Escape, and selection.
- Make icon-only controls accessible by name and visually understandable. Hover and tooltips may explain; they must not be the only route to an action.
- Every screen needs location and a way out. Preserve useful filters, scroll, and selection through navigation when that matches the task.

## Forms

- Give fields persistent labels, correct input types, useful autocomplete, and concise help before failure. A placeholder isn't a label.
- Validate when it helps the person act—often after blur or an attempted submission—rather than showing errors before they've had a chance to type.
- Place actionable errors by their fields, associate them programmatically, and add a summary/focus route for long forms when needed.
- Keep entered values on failure. Distinguish invalid input from network, permission, and server failures; don't expose internal exception text.
- Show pending work clearly and prevent accidental duplicate operations at the responsible layer. Don't clear the form or claim completion before success.
- A disabled action needs an understandable reason or a clear path to availability. Avoid mysterious disabled buttons as the only validation explanation.

## Overlays and feedback

- Pick the lightest suitable surface: inline content for local work, popover for anchored context, modal dialog for a task that must block the background.
- For modal dialogs, verify naming, initial focus, focus containment, inert background, dismissal rules, and focus return using the installed primitive.
  Non-modal surfaces must not trap focus. Closing an overlay must preserve valuable work or offer a clear recovery path.
- Anchor popovers to their trigger, handle collisions and scrolling, and keep the overlay inside usable viewport space. Load `ui-mobile` for keyboard/sheet cases.
- Use inline feedback for field and local errors. Use a toast for a brief cross-surface result, not as the sole record of a critical failure or required action.
- Announce meaningful async changes without unnecessary focus moves or flooding assistive technology. Loading should reserve space, not shift actions.
- Prefer undo for reversible changes. Confirm destructive, irreversible consequences specifically; repeated generic “Are you sure?” dialogs teach dismissal.

## Accessibility proof

Verify semantic roles and names, keyboard-only operation, focus behavior, text contrast, and non-color status cues. For web UI, use WCAG 2.2 AA as the
default floor unless a stricter project standard applies: normal text 4.5:1, large text 3:1, and applicable non-text indicators 3:1.
Aim for comfortable 44px touch targets; check the 24 CSS px target-size minimum and its defined exceptions rather than treating visual icon size as hit area.

Automated accessibility checks supplement, not replace, keyboard and assistive-technology checks. State which you ran. Use `ui-motion` when feedback moves;
use `ask-sonner`, if present, only for actual Sonner work and verify its API against the installed version.
