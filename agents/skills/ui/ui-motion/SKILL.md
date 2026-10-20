---
name: ui-motion
description: >-
  Decide whether UI should animate, then build or repair purposeful motion, gesture continuity, timing, interruption, and reduced-motion behavior.
  Use for transitions, press feedback, drawers, drag/swipe interactions, and animation performance problems on web or native UI.
---

# UI motion

Load `ui-common` once. Motion earns its place through feedback, orientation, continuity, or explanation; no animation is a valid design decision.

## Decide before implementing

1. Identify the action, frequency, purpose, affected state, and product personality. Keep shortcuts, focus changes, and high-frequency navigation immediate.
   Input modality alone doesn't determine value: keyboard users still deserve clear state feedback without waiting for choreography.
2. Prefer a static change or near-imperceptible feedback for repeated work. Reserve larger expressive motion for rare moments and explanatory content.
3. Reuse existing motion tokens and the cheapest suitable driver. For web, CSS transitions suit state changes; WAAPI suits programmatic timelines;
   a spring/gesture tool suits continuous manipulation. A fade doesn't justify a new library.
4. Read the relevant specialist if installed: `animate` for web construction, `animate-expo` for native, `apple-design` for gesture continuity,
   or `animation-performance` for jank. Verify version-dependent APIs and acceleration claims before using them.
5. Implement reduced-motion behavior, interruption, and exit alongside entry. Test the real interaction, not only the first playback.

Done when motion has a named purpose, preserves immediate operation, survives interruption, and has a verified gentler or instant equivalent.

## Starting values, not universal laws

Reuse product values first. If none exist, these starting ranges reflect the installed animation guidance; tune against the actual surface and hardware.

| Interaction                           | Starting point                                                                       |
|---------------------------------------|--------------------------------------------------------------------------------------|
| Press feedback                        | Immediate state feedback; optional subtle scale around `0.97`, settling in 100–160ms |
| Tooltip or small popover              | 125–200ms; anchored origin if scaling                                                |
| Menu or select                        | 150–250ms; responsive ease-out                                                       |
| Modal                                 | Around 200–300ms; centered unless the interaction has a different spatial model      |
| Large sheet or gesture settle         | Roughly 200–500ms perceived, justified by travel and continuity                      |
| Repeated keyboard navigation or focus | Immediate, without an animation wait                                                 |

Default to a responsive ease-out for entering UI. If the product lacks curves, `cubic-bezier(0.23, 1, 0.32, 1)` is a useful starting point;
`cubic-bezier(0.32, 0.72, 0, 1)` suits a sheet. Use linear timing for actual continuous progress, not a fabricated progress estimate.
Spring parameters are library-specific: preserve velocity and tune them in the installed API rather than translating numbers by name alone.

## Continuity and restraint

- Prefer small transforms and opacity. A subtle fade alone is valid; motion need not scale to count as polished. Avoid dramatic scale-from-zero entrances.
- Place the origin of an anchored surface at its source. Use a consistent entry/exit path; don't force unrelated surfaces to share the same transition.
- Retarget reversible UI from its current presentation. CSS transitions can retarget position; gesture physics may also need release velocity.
- While dragging, track the pointer and grab offset directly; apply spring/momentum behavior on handoff, not a lagging spring between finger and object.
- Handle pointer capture, cancellation, lost capture, extra pointers, and scroll competition. Use recent signed velocity with explicit units.
- Give drag/swipe actions a non-drag alternative. Hold-to-confirm isn't the default delete control; it needs accessible alternatives and tested cancellation.
- Stagger only if sequence explains something or a rare entrance benefits. Keep content operable throughout; repeated lists don't need a cascading entrance.
- Under reduced motion, remove spatial movement, parallax, and overshoot. Preserve meaning with static feedback or a short fade where appropriate.

## Performance diagnosis

Name and measure the cause before optimizing: layout, paint, main-thread work, excessive nodes, per-frame renders, or style recalculation.
Prefer `transform` and `opacity`; name transition properties explicitly. Scaling isn't a behavior-preserving replacement when surrounding layout must reflow.
An accordion's size animation can be correct if bounded and measured. Opacity alone doesn't hide an element from focus, hit testing, or assistive technology.

CSS and WAAPI can run compositor-friendly animation off the main thread; acceleration depends on the property, browser, element, and library version.
Neither “all CSS is GPU-driven” nor “all Motion shorthand is slow” is a safe conclusion. Check the implementation and profile the target path.
Avoid per-frame framework renders, broad inherited-variable updates, and expensive full-surface blur. Add narrowly scoped `will-change` only for a measured need.

Verify rapid toggles, reverse/cancel mid-flight, entry/exit cleanup, reduced motion, and busy-page playback. Use slow playback for timing and a performance
recording for frame cost. For gestures, use real hardware; for native, check a release build. Clearly separate measured results from source-based risks.
