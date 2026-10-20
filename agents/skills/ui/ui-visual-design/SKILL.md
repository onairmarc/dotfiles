---
name: ui-visual-design
description: >-
  Design or refine UI hierarchy, typography, color, spacing, density, and visual identity. Use for new screens, layout changes, or visual polish;
  preserves established product language and avoids generic template styling.
---

# UI visual design

Load `ui-common` once for the shared posture, scope, and quality floor. Own the visual choices here; use `ui-interaction-design` for behavior changes.

## Establish the direction

1. Read the screen in context: its task, neighbors, real content, container sizes, existing tokens, and shared components.
2. Decide whether this is a new identity or a refinement. For a new identity, load the collection's `frontend-design`; for refinement, keep the product recognizable.
3. State a compact direction: what gets attention first, the intended density, type roles, surface roles, and one subject-specific choice if the brief needs it.
   Reuse existing tokens. Create only missing roles, in the project's existing token system.
4. Build and inspect the result at realistic size. Revise based on what people must read, compare, or act on, not on decoration count.

Done when hierarchy supports the main task, the design fits its context, and the rendered result has been checked or its unverified parts named.

## Visual opinions

- **Hierarchy first:** order, grouping, alignment, and contrast should reveal the reading path before adding boxes or extra headings.
- **Type as a system:** choose size, weight, line-height, and tracking together. Keep body text readable; check tall scripts and fallback fonts before tight leading.
  System fonts are a sound product default. A custom display face earns its place through the brief, not through a mandatory two-font rule.
- **Color by role:** define text, muted text, surface, border, accent, and semantic status roles. Keep selected, focused, disabled, and error states distinct.
  Check contrast on the actual background in each supported theme; status also needs text or shape, not color alone.
- **Spacing by relationship:** related content sits closer together. Use a small spacing scale and optical alignment; avoid arbitrary margins per element.
- **Density by task:** preserve scanability and comparison in operational screens. Large cards, wide gutters, and giant headings aren't universal improvements.
- **Depth by function:** shadows and translucency distinguish overlapping layers. Ordinary content doesn't need to look like floating chrome.
  Glass needs a legible solid fallback and a rendering-cost check; blur isn't a default treatment.
- **Iconography with meaning:** keep size, stroke, alignment, and vocabulary coherent. Label unfamiliar actions; accessible names alone don't explain a visual icon.
- **Data with precision:** align comparable values, use tabular digits where updates would jitter, and preserve units and significant information.
- **Copy as layout:** use real labels and content. Numbering means sequence or rank; badges mean status or classification; decoration shouldn't invent meaning.

## Replace weak defaults

| Weak default                                           | Better direction                                                                       |
|--------------------------------------------------------|----------------------------------------------------------------------------------------|
| Identical rounded cards for every section              | Group by the content's structure; use rows, tables, sections, or cards where each fits |
| A fashionable palette copied across unrelated products | Derive the palette from the subject and required semantic roles                        |
| Every label muted to reduce visual noise               | Preserve readable contrast; reduce competing content and emphasis instead              |
| More shadows, gradients, and borders to add polish     | Fix type, spacing, alignment, and hierarchy first                                      |
| Fixed heights to keep the screenshot tidy              | Let content grow; use intentional wrapping and responsive composition                  |
| A wholesale redesign for one awkward control           | Repair the smallest responsible component and check its consumers                      |

## Verify

Compare before and after with the same content and viewport. Check the actual narrow container, wide layout, text at 200%, long labels, image fallbacks,
and supported themes. Confirm the primary action remains clear without relying on hover or animation. Load `ui-resilience` for deeper edge-case testing.

Keep screenshots or visual observations separate from source-based judgments. Explain the main visual choice briefly; skip a design manifesto.
