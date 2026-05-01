---
name: avalonia-optimization
description: Audits an Avalonia C# application or project path for performance issues (UI thread blocking, excessive bindings, missing virtualization, memory leaks via event handlers, sync I/O on UI thread, inefficient rendering), then delegates to the feature-planning skill to produce a self-contained, phased, agent-ready optimization plan. Does NOT execute optimizations. A single failing test in the plan's Phase 0 baseline gate is a hard stop.
argument-hint: "<project-path> [additional context]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(test -f *)
  - Bash(find * -name "*.cs" -type f)
  - Bash(find * -name "*.axaml" -type f)
  - Bash(cat *)
  - Skill(feature-planning)
  - AskUserQuestion
model: opus
---

# Avalonia Optimization Skill

You are an expert Avalonia UI performance engineer. Your job is to **audit** a project path, discover performance
issues, and then invoke the **feature-planning skill** to produce a self-contained, agent-ready optimization plan. You
do not execute any optimization code yourself.

**Input:** `$ARGUMENTS` — the project path to audit (e.g. `src/MyApp`, `src/MyApp.Desktop`, `src/Views`).

---

## Step 0 — Validate input

Parse `$ARGUMENTS`. Extract:

- `PROJECT_PATH` — first positional argument (required). If missing or the path does not exist, abort with:
  ```
  Error: PROJECT_PATH is required. Usage: /avalonia-optimization <path/to/project> [additional context]
  ```
- `EXTRA_CONTEXT` — everything after the first positional argument (optional). Free-form text the caller provides about
  known issues, architectural decisions, or constraints the automated audit may not discover (e.g. "the MainViewModel is
  a singleton shared across windows", "the DataGrid always loads the full dataset on startup"). Preserve it verbatim.

Derive `PROJECT_NAME` from the last meaningful path segment (if last segment is `src`, use its parent).

---

## Step 1 — Detect project type

Read the `.csproj` file(s) in `PROJECT_PATH`. Classify the project:

| Signal                                                                      | Classification             |
|-----------------------------------------------------------------------------|----------------------------|
| `<UseAvalonia>true</UseAvalonia>` or `Avalonia` in `PackageReference` items | **Avalonia Application**   |
| `OutputType` is `Library` or no `Avalonia.Desktop` dependency               | **Avalonia Class Library** |
| Multiple `.csproj` files with shared `Views`/`ViewModels` structure         | **Avalonia Monorepo**      |

Record as `PROJECT_TYPE`. Scope rules per type:

- **Avalonia Application** — out of scope: anything outside `PROJECT_PATH`, `obj/`, `bin/`
- **Avalonia Class Library** — out of scope: host application code, `bin/`, `obj/`
- **Avalonia Monorepo** — out of scope: sibling projects outside `PROJECT_PATH`, `bin/`, `obj/`

Determine test root:

- Application: `tests/` at repo root, or `{PROJECT_PATH}.Tests/`
- Library: `{PROJECT_PATH}.Tests/` or nearest `Tests/` sibling
- Monorepo: project-local `Tests/` preferred, repo root `tests/` as fallback

Emit before continuing:

```
Project type: {PROJECT_TYPE}
Project:      {PROJECT_NAME} ({PROJECT_PATH})
Test root:    {TEST_ROOT}
```

If classification is ambiguous, state your best guess and the reason, then continue.

---

## Step 2 — Audit the project

Systematically search `PROJECT_PATH` for every problem category below. For each hit, **read the actual file to confirm
line numbers before recording**. Never approximate.

Record each finding as:

- **Category**
- **Class::Method()** (or class name)
- **File path** (exact, relative to repo root)
- **Line range**
- **One-sentence description of the specific problem**

### UI thread patterns

| Problem                                  | How to detect                                                                                                                 |
|------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| Sync I/O on UI thread                    | `File.Read`, `File.Write`, `HttpClient.Send` (non-async), `Thread.Sleep` in code-behind or ViewModel `Initialize`/constructor |
| `Task.Result` or `.Wait()` on UI thread  | Grep `\.Result\b` or `\.Wait\(\)` in files that also reference `Dispatcher` or inherit `Window`/`UserControl`/`ViewModelBase` |
| `Dispatcher.UIThread.InvokeAsync` misuse | Wrapping CPU-bound work in `InvokeAsync` instead of `Task.Run` + marshalling only the UI update                               |
| Long-running sync work in event handlers | `Button.Click`/`Tapped` handlers with no `async`/`await` containing loops or I/O calls                                        |

### Binding and ViewModel patterns

| Problem                                           | How to detect                                                                                                                                |
|---------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| Missing `[ObservableProperty]` / manual INPC      | Classes implementing `INotifyPropertyChanged` manually with `PropertyChanged?.Invoke` — check if CommunityToolkit.Mvvm is used               |
| `ObservableCollection` replaced wholesale         | `MyCollection = new ObservableCollection<T>(...)` in a loop or on every refresh instead of `Clear()` + `AddRange`                            |
| Binding to computed property without notification | C# property with a getter that reads other properties but no `[NotifyPropertyChangedFor]` or manual `OnPropertyChanged` for its dependencies |
| `RaisePropertyChanged` in tight loop              | `RaisePropertyChanged`/`OnPropertyChanged` called inside `for`/`foreach`/`while`                                                             |
| ViewModel doing heavy work in constructor         | Constructor body containing `await`, database calls, file I/O, or `Task.Run(...).Result`                                                     |

### Rendering and layout patterns

| Problem                                        | How to detect                                                                                                 |
|------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| `ItemsControl` without virtualization          | `ItemsControl`/`ListBox`/`DataGrid` in `.axaml` without `VirtualizingStackPanel` or `IsVirtualizing="True"`   |
| Deeply nested layout panels                    | More than 4 levels of `Grid`/`StackPanel`/`DockPanel` nesting in a single `.axaml` file                       |
| `Canvas` misused as general layout             | `Canvas` used as root or primary layout container for non-absolutely-positioned content                       |
| Unnecessary `Opacity=0` instead of `IsVisible` | Elements set to `Opacity="0"` or `Opacity="{Binding ...}"` evaluating to 0 that should use `IsVisible`        |
| Heavy `ControlTemplate` duplication            | Identical `ControlTemplate` or `DataTemplate` blocks defined more than once instead of using `StaticResource` |

### Memory and resource patterns

| Problem                                        | How to detect                                                                                                                                                 |
|------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Event handler subscription without unsubscribe | `+=` on `EventHandler`/`RoutedEvent` in a class that does not implement `IDisposable` or does not have a corresponding `-=` in a `Dispose`/`Unloaded` handler |
| `WeakReference` / `WeakEventManager` missing   | Long-lived publisher (singleton service, static event) with subscriber `+=` in a short-lived `UserControl` or `ViewModel`                                     |
| `Bitmap`/`WriteableBitmap` not disposed        | `new Bitmap(...)` or `new WriteableBitmap(...)` in a method with no `using` or explicit `.Dispose()` call                                                     |
| Static `IImage` / `IBrush` allocated per-call  | `new SolidColorBrush(...)` or `new BitmapImage(...)` inside a method called on render/data update instead of a static cached resource                         |
| `DispatcherTimer` not stopped                  | `new DispatcherTimer(...)` with `.Start()` but no `.Stop()` in `Dispose`/`Unloaded`                                                                           |

### Async and threading patterns

| Problem                                         | How to detect                                                                                                         |
|-------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| `async void` outside event handlers             | `async void` method signatures in non-event-handler contexts (not `Button_Click`, not `OnLoaded`)                     |
| CPU-bound work not offloaded                    | Loops processing >100 items synchronously in a `ViewModel` method with no `Task.Run` or `await Task.Run`              |
| `CancellationToken` not passed to async methods | `async` methods accepting `CancellationToken` but callers passing `CancellationToken.None` or omitting the parameter  |
| Missing cancellation on ViewModel unload        | `CancellationTokenSource` created in ViewModel with no `.Cancel()` in a `Dispose` or `Deactivated`/`Unloaded` handler |

### AXAML and resource patterns

| Problem                                       | How to detect                                                                                        |
|-----------------------------------------------|------------------------------------------------------------------------------------------------------|
| Inline styles instead of `StaticResource`     | `<Control.Styles>` or inline `Style` blocks that duplicate styles defined at app or window level     |
| `DynamicResource` where `StaticResource` fits | `DynamicResource` bindings on resources that never change at runtime                                 |
| Large `ResourceDictionary` not split          | Single `ResourceDictionary` file exceeding 300 lines containing mixed styles and templates           |
| Missing `x:Key` on merged dictionaries        | `ResourceDictionary.MergedDictionaries` entries without `x:Key` causing full re-merge on each access |

---

## Step 3 — Compile findings

Group findings by category. Count totals. Prepare this structured summary:

```
## Audit results: {PROJECT_NAME}

Project type:    {PROJECT_TYPE}
Project path:    {PROJECT_PATH}
Test root:       {TEST_ROOT}
Caller context:  {EXTRA_CONTEXT | "(none)"}

Issues found: N total
  UI thread:          N
  Binding/ViewModel:  N
  Rendering/Layout:   N
  Memory/Resources:   N
  Async/Threading:    N
  AXAML/Resources:    N

### Issues

**UI thread**
- `ClassName::Method()` at `path/File.cs:10-25` — description
[...]

**Binding / ViewModel**
[...]

**Rendering / Layout**
[...]

**Memory / Resources**
[...]

**Async / Threading**
[...]

**AXAML / Resources**
[...]
```

Omit any category with zero findings.

---

## Step 4 — Invoke feature-planning

Hand off to the **feature-planning skill** with the full audit summary as context. Use the following as the feature
description passed to feature-planning (feed it programmatically — do not ask the user to retype it):

---

> Optimization plan for `{PROJECT_NAME}` (`{PROJECT_PATH}`).
>
> Project type: `{PROJECT_TYPE}`
>
> This is NOT a new feature — it is a performance optimization plan for an existing Avalonia application. The plan must
> follow the standard feature-planning plan structure with these overrides:
>
> **Replace "Implementation steps" with two phases:**
>
> **Phase 0 — Baseline test coverage (mandatory, non-negotiable)**
> - Run existing test suite filtered to this project. Record all passing tests.
> - If any pre-existing failures exist, stop — they must be fixed before optimization work begins.
> - For every issue in "Issues addressed" with no existing test pinning current behavior, write an xUnit or NUnit
    > baseline test.
> - Baseline tests must assert current (pre-optimization) behavior, not desired behavior.
> - Commit baseline tests separately before Phase 1: `test({project}): baseline tests before optimization`
> - Re-run suite. All tests including new baselines must pass before proceeding.
>
> **Phase 1 — Optimizations (one numbered step per issue)**
> - Each step: names file and method, shows exact before/after code snippet, includes a grep/search command to verify no
    > other callers are broken.
> - After every individual step: run the test suite. A single failing test = that step is a failure. Revert and fix
    > before continuing to the next step.
> - One PR per phase.
>
> **Hard constraints to embed in the plan:**
> 1. Every issue cites exact file path and line number range — no approximations.
> 2. Every fix includes a working code snippet using the project's own namespace and conventions.
> 3. Phase 0 is non-negotiable. No Phase 1 step ships without green baseline tests.
> 4. A single test failure after any Phase 1 step = hard stop. Revert, fix, re-run.
> 5. No new infrastructure dependencies (no new NuGet packages unless they are zero-dependency and widely adopted).
> 6. Do not touch files outside `{PROJECT_PATH}` except test files for code inside it.
> 7. `Task.Result` / `.Wait()` on the UI thread → always replace with `await`. No exceptions.
> 8. `async void` outside event handlers → always replace with `async Task`. No exceptions.
> 9. `ObservableCollection` replaced wholesale → always replace with `Clear()` + range add or diff update.
> 10. Never recommend changing data binding `Mode` to `OneTime` as a performance shortcut — data must stay live unless
      > the data genuinely never changes after load.
> 11. `ItemsControl`/`ListBox`/`DataGrid` with unbounded items must use `VirtualizingStackPanel` or the platform
      > virtualization API. Always. No exceptions.
> 12. Event handler `+=` subscriptions in short-lived controls must have a corresponding `-=` in `Dispose` or an
      > `Unloaded` handler. Use `WeakEventManager` or `WeakReference` when the publisher outlives the subscriber.
> 13. `DispatcherTimer` created in a ViewModel or control must be stopped in `Dispose` or `Unloaded`. The plan step must
      > show the exact disposal site.
> 14. CPU-bound work longer than ~16ms must be offloaded via `Task.Run`. The plan step must show the `await Task.Run`
      > wrapping and the UI-thread marshal for any resulting property updates.
> 15. `DynamicResource` bindings on resources that never change at runtime must be converted to `StaticResource`.
>
> **Out of scope:** Native interop rewrites, platform-specific rendering pipeline changes, new build tooling,
> files outside `{PROJECT_PATH}`.
>
> **Caller-supplied context** (treat as authoritative — may describe issues not discoverable by static analysis):
>
> {EXTRA_CONTEXT | "(none provided)"}
>
> **Audit findings to address:**
>
> {FULL_AUDIT_SUMMARY_FROM_STEP_3}

---

The feature-planning skill handles the rest: discovers the planning directory, drafts the plan, applies review lenses,
iterates with the user, and writes the final agent-ready plan to disk.