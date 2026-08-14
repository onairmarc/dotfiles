# {{PROJECT_NAME}}

{{PROJECT_TAGLINE}}

## Overview

{{GEN:a paragraph or two on what {{PROJECT_NAME}} is and does — the problem it solves and its headline capabilities — authored from the project's purpose and confirmed
with the user.}}

## Technology Stack

- **Language** — {{PRIMARY_LANGUAGE}}
- **Runtime / framework** — {{STACK}}
- **Tests** — {{TEST_FRAMEWORK}}
- **Static analysis** — {{STATIC_ANALYSIS_TOOL}}
- **Logging** — {{LOG_LIBRARY}} → {{LOG_SINK}} {{GEN:add any other headline stack elements — database, message bus, deploy target — detected from the manifests. Omit
  bullets that do not apply.}}

## Architecture

{{GEN:a short description of how the code is organized ({{MODULE_LAYOUT}}) — the top-level modules/packages/projects and each one's role. Use a table if there is more
than a handful. Author from detection; confirm the module list with the user.}}

## Getting Started

### Prerequisites

{{GEN:the tools and versions needed to build and run the project (language runtime/SDK version, database, any services) — detected from manifests and CI.}}

### Build

```
{{BUILD_COMMAND}}
```

### Test

```
{{TEST_COMMAND}}
```

### Static analysis

Reports defects to fix. Run it before calling a change done — see
[`{{DOCS_PATH}}/policies/static-analysis.md`]({{DOCS_PATH}}/policies/static-analysis.md).

```
{{STATIC_ANALYSIS_COMMAND}}
```

### Format / style lint

**Runs in CI only** — do not run it locally, and coding agents must never run it in any mode, including `--check`. See
[`{{DOCS_PATH}}/policies/formatter-authority.md`]({{DOCS_PATH}}/policies/formatter-authority.md).

```
{{FORMAT_COMMAND}}
```

## Development

- Branch off `{{DEFAULT_BRANCH}}`; open a pull request for review.
- All code follows the standards in [`{{DOCS_PATH}}/policies.md`]({{DOCS_PATH}}/policies.md).
- `{{STATIC_ANALYSIS_TOOL}}`, the formatter, and the test suite all run in CI and must be green before merge.

## Further Documentation

- [AGENTS.md](AGENTS.md) — AI-agent guidance, key commands, and the standards index.
- [`{{DOCS_PATH}}/policies.md`]({{DOCS_PATH}}/policies.md) — coding-standards index, routing to one file per policy in
  [`{{DOCS_PATH}}/policies/`]({{DOCS_PATH}}/policies/).
- [`{{DOCS_PATH}}/policies/structured-logging.md`]({{DOCS_PATH}}/policies/structured-logging.md) — the full logging contract, write side and read side.
- [`{{DOCS_PATH}}/glossary.md`]({{DOCS_PATH}}/glossary.md) — project terminology.
- [`{{PLANNING_PATH}}/README.md`]({{PLANNING_PATH}}/README.md) — plan lifecycle. {{GEN:add a bullet for `module-isolation.md` ("module boundaries and the
  published-surface working list") only if that Tier 2 policy was written; omit it otherwise.}}
