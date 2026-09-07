# Technology stack

This page is the canonical human-readable reference for **{{PROJECT_NAME}}**'s runtime, framework, and tooling versions. Keep it in sync with the machine-readable
manifests; other documentation links here instead of repeating version numbers.

{{GEN:identify every package manifest and lockfile that defines the project's dependency and runtime constraints. State which files are authoritative for each ecosystem,
and any generated documentation block that must be regenerated rather than edited.}}

## Runtime and framework

{{GEN:a table with Technology, Package / constraint, and Role columns. Include the primary runtime, framework, database, and other core platform dependencies detected
from the manifests.}}

## User interface

{{GEN:a table with Technology, Package / constraint, and Role columns for detected frontend frameworks, server-driven UI layers, component libraries, CSS tooling, and
build tools. Remove this section when the project ships no UI.}}

## Platform and integrations

{{GEN:a table with Technology, Package / constraint, and Role columns for internal packages, significant infrastructure dependencies, and external integrations. Remove
this section when none apply.}}

## Observability

{{GEN:a table with Technology, Package / constraint, and Role columns for logging, error reporting, metrics, tracing, and local diagnostic tooling. Remove this section
when none apply.}}

## Quality tooling

{{GEN:a table with Technology, Package / constraint, and Role columns for test frameworks, browser test runners, static analyzers, formatters, and monorepo tooling.
Link to the relevant policy when one governs the tool.}}
