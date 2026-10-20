# Sources and deliberate choices

This collection synthesizes installed skills inspected on October 20, 2026. The entries below describe the files found on that machine, not a guarantee
that another machine has the same versions. Local filenames below are relative to each installed skill directory under `~/.agents/skills/`.

These are source influences, not claims that the source authors endorse these house rules. Framework/API claims still need version-specific verification.
The local accessibility, scope-control, and conflict-resolution rules are house additions unless identified otherwise.

## Third-party UI inventory

`tools/ai_setup.ts` installs `emilkowalski/skills` and `mattpocock/skills` with wildcard selections, plus
`vercel-react-best-practices` from `vercel-labs/agent-skills`. Wildcard installs and name collisions can change which skill a name resolves to.
Use the actual installed `SKILL.md` as the source of behavior, not another router's summary or an assumed upstream owner.

### Visual and interaction craft

- **`emil-design-eng`**: inspected `SKILL.md`. Influences coherent defaults, immediate feedback, anchored origins, restraint, and checking rendered feel.
- **`apple-design`**: inspected `SKILL.md`. Influences direct manipulation, presentation-state continuity, velocity handoff, agency, hierarchy, and type.
  Its Apple/WWDC attributions and exact physics constants weren't independently verified; this collection doesn't present them as platform guarantees.
- **`mobile-native`**: inspected `SKILL.md`. Influences capability-based input, viewport selection, safe areas, input sizing, native scroll, and hardware checks.
- **`break-ui`**: inspected `SKILL.md` and `CATALOG.md`. Influences plausible extremes, boundary-level fixtures, full states, and normal/stress comparisons.
- **`prototype`**: inspected `SKILL.md` and `PICKER.md`. Influences distinct working alternatives, realistic context, a comparison harness, and promotion by choice.
  This installed variant is explicit-only. The installed `ask-matt/SKILL.md` describes a different prototype workflow, so its summary isn't authoritative here.
- **`pick-ui-library`**: inspected `SKILL.md`. Influences checking existing dependencies and using established primitives instead of hand-built complex widgets.
  Explicit-only; its curated library preferences aren't mandatory dependencies.
- **`ask-sonner`**: inspected `SKILL.md`. Offers optional toast implementation help. Exact API details belong in its `API.md` and the installed package;
  this collection doesn't copy its API recipes or universal styling claims.

### Motion

- **`animate`**: inspected `SKILL.md` and `RECIPES.md`. Influences purpose/frequency gates, driver selection, timing ranges, entry/exit, and motion preferences.
- **`animate-expo`**: inspected `SKILL.md`. Influences native/web separation, gesture-thread awareness, platform navigation, release-device testing, and
  nonexclusive visual feedback. Exact APIs and recipes must be read and checked when working in a matching Expo project.
- **`animation-performance`**: inspected `SKILL.md`. Influences cause-first diagnosis, frame-budget thinking, direct animated values, and measured optimization.
- **`animation-vocabulary`**: inspected `SKILL.md`. Optional naming reference; no reason to load its glossary for every animation task.
- **`review-animations`**: inspected `SKILL.md` and `STANDARDS.md`. Influences origin, interruption, and purpose checks. Explicit-only; not a general UI review.
- **`find-animation-opportunities`**: inspected `SKILL.md`. Influences rejecting low-value motion candidates and explaining why survivors help.
- **`improve-animations`**: inspected `SKILL.md`, `AUDIT.md`, and `PLAN-TEMPLATE.md`. Influences evidence-backed prioritization and concrete feel checks.
  Its audit/plan workflow isn't the default for implementation work. Its worktree execution branch conflicts with this repo's operating rules and isn't adopted.

### Adjacent implementation guidance

- **`vercel-react-best-practices`**: inspected `SKILL.md` (MIT, author metadata: Vercel). Optional React performance router, not a visual design authority.
  Read individual rule files for a relevant finding; this collection doesn't reproduce its 70-rule catalog or apply Next.js-specific APIs to other stacks.
- **`ask-matt`**: inspected `SKILL.md` to check the prototype routing conflict. It is a general workflow router, not an additional UI design source.
- **`writing-for-agents`**: inspected `SKILL.md` and `SKILL-MECHANICS.md` for descriptions, invocation boundaries, and progressive disclosure.
  It shapes this collection's packaging, not its visual style.

## Existing owned and optional private skills

- **`frontend-design`**, at `agents/skills/ui/frontend-design/SKILL.md`: part of this collection; owns distinctive new visual direction and UI copy.
- **`react-optimization`**, at `agents/skills/optimization/react-optimization/SKILL.md`: inspected for audit-only versus planning scope and framework selection.
- **`tanstack-optimization`**, at `agents/skills/optimization/tanstack-optimization/SKILL.md`: inspected for library-specific audit/planning scope.
- **`inertia-best-practices`**: inspected its installed `SKILL.md`. Absent from this public repo's skill inventory; treat as an optional private/custom skill,
  not a third-party UI source or a universally installed dependency. Use only its applicable rules after discovering the host framework.

Broader language, backend, security, and project-planning skills remain outside this collection; load them when the actual implementation needs them.

## Departures that matter

1. **Timing is contextual.** Sources combine a sub-300ms rule with 400ms toast and 500ms drawer recipes. House guidance treats ranges as starting points,
   keeps repeated operation immediate, and allows measured large-surface or platform exceptions rather than treating both statements as absolute.
2. **Keyboard isn't a ban on feedback.** Keep shortcuts and focus immediate, but don't remove useful state communication merely because activation used a key.
3. **Pure fades and static changes are valid.** Some review rules reject pure fades while reduced-motion recipes recommend them. The house rule is purpose
   and accessibility, not mandatory translation or scale.
4. **Acceleration is conditional.** Sources differ on Motion shorthand and CSS acceleration. Confirm the installed implementation and measure the real path;
   property names alone don't prove GPU execution. `transform`/`opacity` are preferences, not free or guaranteed work.
5. **Geometry has meaning.** A scale transform doesn't replace every size change: text also scales, siblings don't reflow, and hit/layout bounds differ.
   Keep legitimate size animation when it preserves the required behavior and meets a measured budget.
6. **Mobile fixes are scoped.** Keep native document scrolling, selection, zoom, and link behavior unless a specific control needs a different behavior.
   Viewport and software-keyboard behavior vary; emulation and CSS inspection aren't hardware proof.
7. **Accessibility beats an effect recipe.** Full text needs a touch/keyboard-usable route, duplicated visual controls need one semantic interaction model,
   and gesture-only or hold-only actions need alternatives. Opacity doesn't make hidden UI noninteractive.
8. **Reuse before preference.** A curated library list doesn't justify replacing a working dependency. Read current package source/docs before prescribing APIs.
9. **Mode controls mutation.** Review-only stays read-only; repair mode fixes confirmed in-scope defects. An external report-first workflow doesn't force
   another approval round for known fixes the user already authorized, nor does a build skill authorize edits during a review.
10. **Exploration preserves agency.** Offer a reasoned recommendation, but promote only after selection. Keep experiments dev-only, work in-place, and follow
    governing approval rules for removal. Don't inherit an external workflow's branch, worktree, or cleanup policy.

## Updating the collection

Reinspect the installed skill and relevant references before changing a source claim or route. Record meaningful departures here, preserve explicit-only
boundaries, and update [routing-checks.md](routing-checks.md) when adding a new task branch. Keep source recipes out of the common index.
