# Glossary

Definitions for acronyms and **{{PROJECT_NAME}}**-specific terms that appear across the developer documentation. Add a new entry whenever you introduce a term that would
not be obvious to someone new to the project.

Entries are short on purpose: one or two sentences, plus a link to the canonical reference when one exists.

## Product and domain

{{GEN:glossary entries for the core product and domain terms of {{PROJECT_NAME}} — the product name itself, any historical/abbreviated names still living in code, and the
top domain nouns the codebase is organized around. Ask the user for the domain vocabulary; author one bullet per term as "**Term** — one-or-two-sentence definition."
Include at least the product name and its tagline-level definition.}}

## Internal packages and components

{{GEN:entries for the project's own internal packages, modules, or notable components a newcomer would encounter — detected from {{MODULE_LAYOUT}} and confirmed with the
user. One bullet per component, "**Name** — what it is and what it owns." Remove this section if the project has no distinct internal packages worth naming.}}

## Tooling and runtime

{{GEN:entries for the third-party tools and runtime services that show up in the codebase and docs — the log sink ({{LOG_SINK}}), the metrics/APM tool, the CI system, the
deploy target, and any framework-specific runtime a newcomer must recognize. One bullet each, defining the tool and its role in this project.}}

## Process and conventions

- **ADR** — Architecture Decision Record. A durable, numbered Markdown document that captures a significant architectural decision: the question asked, the options
  weighed, the decision made, and its consequences. Unlike a `{{PLANNING_PATH}}/` plan (throwaway scaffolding), an ADR is permanent. Project-wide ADRs live at
  `{{DOCS_PATH}}/decisions/NNNN-<slug>.md`; module-scoped ADRs live in that module's own `docs/decisions/`. See the Documentation policy.
