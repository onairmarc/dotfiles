---
name: ui-mobile
description: >-
  Build or repair mobile web UI across responsive layouts, touch input, viewport sizing, safe areas, scrolling, and software keyboards.
  Use for mobile screens, PWAs, bottom sheets, sticky controls, or desktop UI that fails on a phone; not React Native implementation.
---

# UI mobile

Load `ui-common` once. This skill owns mobile web behavior; use `ui-motion` and optional `animate-expo` for React Native rather than porting web fixes.
Load `mobile-native` if installed for symptom-specific examples, then apply only the fixes whose conditions match the app.

## Workflow

1. Read the layout shell, viewport configuration, scroll containers, fixed/sticky UI, forms, and gesture handlers. Identify supported browsers and PWA modes.
2. Trace the reported symptom with browser chrome, keyboard, orientation, and input capability in mind; screen width doesn't tell you whether touch exists.
3. Fix the smallest responsible layer using platform behavior and existing components before adding JavaScript viewport or device-detection logic.
4. Verify narrow and wide containers, keyboard-open behavior, scrolling, zoom, and input. Use real hardware for browser chrome, safe areas, and touch feel.

Done when the main task remains reachable with the keyboard open, content can scroll and zoom, and fixed controls don't obscure essential content.
If hardware isn't available, finish code/browser checks and name the specific unverified device behaviors rather than claiming device proof.

## Mobile opinions

- **Adapt the task:** reflow navigation and actions for available space; don't shrink the desktop screen until its controls become hard to use.
- **Viewport by purpose:** `dvh` can suit a shell that tracks visible chrome; `svh` can suit a stable hero. Verify keyboard behavior separately—`dvh` alone
  doesn't guarantee keyboard-aware layout in every browser. Use fallbacks based on the support matrix.
- **Insets by ownership:** for edge-to-edge layouts, use `viewport-fit=cover` and safe-area padding on the chrome that owns each edge; avoid double padding.
- **Zoom stays available:** preserve pinch zoom. On iOS-facing forms, use an input font size of at least 16 CSS px to avoid focus zoom; don't disable scaling.
- **Input follows intent:** choose input type, `inputmode`, autocomplete, capitalization, and return-key hints by field meaning. Numeric-looking identifiers
  such as postal codes may still need text storage, leading zeroes, and nonnumeric characters.
- **Hover is optional:** gate decorative hover by capability and provide focus/press alternatives. Hybrid devices need both pointer and touch paths.
- **Feedback stays visible:** show press feedback immediately; if removing the browser tap highlight, replace it. Keep link conventions where useful.
- **Scroll stays native:** prefer native overflow and scroll snap where they fit. Contain scroll chaining on an overlay only when it fixes the flow;
  don't globally remove pull-to-refresh, bounce, or page scrolling from ordinary documents.
- **Gesture ownership is narrow:** `touch-action` declares browser-owned gestures. Preserve page panning and pinch zoom unless a small, deliberate custom
  surface needs otherwise. A broad `touch-action: none` can make the page unusable.
- **Selection is useful:** keep body text, identifiers, messages, and ordinary links selectable. Suppress selection only on controls prone to accidental drags.
- **Reachability matters:** use comfortable hit areas and spacing, keep primary actions reachable, and leave scroll padding beneath sticky bottom controls.
- **Theme includes chrome:** if theme metadata is in scope, match it to the actual light/dark or user-selected theme and test installed-PWA behavior separately.

## Device checks

Try a long form with the last field focused, rotate once, show/hide browser bars, scroll nested content to both ends, open and dismiss overlays, and
switch input methods where supported. Check that actions remain above or reachable around the keyboard and home indicator.
Include large text, landscape, reduced motion, and a slower supported phone. Report emulation and hardware results separately.
