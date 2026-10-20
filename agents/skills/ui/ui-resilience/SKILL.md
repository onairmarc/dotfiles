---
name: ui-resilience
description: >-
  Stress-test UI with realistic long or missing content, empty and error states, large collections, localization, zoom, and media failures.
  Use when hardening a screen, checking data edge cases, or fixing overflow, hidden actions, misleading values, and fragile demo-only layouts.
---

# UI resilience

Load `ui-common` once. Test real failure boundaries, not random nonsense. Use `break-ui` and its catalog if installed for additional fixture ideas;
keep this task's requested review-or-fix mode rather than inheriting a different one.

## Map, exercise, verify

1. Read every rendered field's source, formatter, accepted range, optionality, collection bound, and related action. Trace frontend and backend contracts.
   Record an unknown limit as unknown; it isn't permission to invent a new validation constraint.
2. Add fixtures through the existing data boundary or test harness, using plausible extremes and accepted schema limits. Keep production markup unchanged
   while reproducing the failure so the test exercises the real component.
3. Exercise the applicable cases below in the real container and supported environments. Use existing stories/tests before creating a custom toggle.
   Any added fixture picker or test route must be development-only and excluded from the shipped surface.
4. In repair/build mode, fix confirmed in-scope defects and add regression proof. In review-only mode, report without edits. Ask only where a genuine
   product decision remains; don't defer a known mechanical fix when implementation is authorized.
5. Recheck ordinary data as well as the stress cases. Preserve the fixture as test coverage using repository conventions.

Done when every in-scope field and reachable state has either been exercised or has an explicit untested boundary, with confirmed defects fixed or
reported according to mode. Don't leave test controls in production or claim visual verification from CSS inspection alone.

## Case matrix

| Dimension        | Try                                                                                                     |
|------------------|---------------------------------------------------------------------------------------------------------|
| Names and labels | One-letter name, plausible compound name, expanded translation, identical display names                 |
| Identifiers      | Long email/URL/path, common prefixes with different endings, leading zeroes                             |
| Missing values   | Null, empty string, absent optional field, no image, image load failure                                 |
| Numbers          | Zero, one, negative where valid, large accepted amount, rounding, locale separators, null versus zero   |
| Collections      | Empty, one item, page-size boundary, page-size plus one, realistic upper bound                          |
| Async state      | Initial loading, background refresh, partial response, failure, retry, slow completion, permission loss |
| Text and locale  | Diacritics, tall scripts, emoji graphemes, CJK, RTL where supported, timezone/date boundaries           |
| Environment      | Narrow real container, 320 CSS px viewport, wide layout, 200% text growth, supported themes             |

For web reflow, also check a 320 CSS px equivalent viewport, including 400% zoom on a 1280px-wide window where applicable. Two-dimensional content,
such as a data table, may need its own scroll region; don't hide overflow at the page level to fake a pass.

## Repair patterns

- Give flex text columns `min-width: 0` and grid tracks `minmax(0, 1fr)` where needed. Protect fixed-size icons/actions from unintended shrinking.
- Wrap meaningful identifiers with `overflow-wrap: anywhere` when necessary. Avoid global `word-break: break-all` that harms ordinary reading.
- Choose wrap, clamp, or truncation per field. Keep full text available through an accessible, touch-usable route; a `title` attribute alone isn't enough.
  Preserve the distinguishing end of filenames and paths. Keep comparable amounts, dates, and units readable in full.
- Format numbers, plurals, and dates with the project's locale tools. Handle missing values explicitly; don't silently turn unknown data into zero.
- Use logical properties and bidi isolation for mixed-direction content. Don't infer cultural name structure or slice emoji by code unit.
- Reserve media dimensions or aspect ratio, fit content intentionally, and supply a useful fallback. Check both delayed loading and failure.
- For large collections, choose pagination or virtualization based on the task, accessibility, search, and rendering cost—not a magic row-count threshold.
- Keep content and controls reachable at larger text sizes. Fix the layout rather than adding stricter data limits to protect a fragile design.

Record each defect with its fixture, location, visible consequence, fix, and verification. Preserve unsaved input and focus during error recovery and refresh.
