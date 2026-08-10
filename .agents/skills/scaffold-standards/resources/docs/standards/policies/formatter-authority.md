# Formatter Authority

**CI owns formatting and linting entirely. A coding agent never runs the formatter or the style linter — not to rewrite, and not to check.**

This is the operational complement of [Code Style](./code-style.md). "Follow the style" is a rule about output; this is a rule about *who runs the tool*. When formatting
and automated-fix tools are run from several places, the passes race each other: two branches formatted by different tool versions produce conflicting diffs, and a
whole-repo rewrite buries the actual change in a thousand unrelated lines. Pinning the run to CI means exactly one tool version, on exactly one machine, produces every
formatting change in the repository.

The rule extends to these tools' **check and dry-run modes**, and that is deliberate. A style linter fixes its own findings automatically, so a finding is not information
anyone needs to act on — CI will resolve it on the next pass. An agent that runs the check anyway gets back a list of violations it cannot correctly resolve, concludes
the code needs editing, and spends tokens and turns hand-matching whitespace and import order that the tool was going to rewrite for free. The output is worse than
useless: it is a prompt to do damage. The agent's job is to write the code plainly and leave style alone.

**Linting is not static analysis.** This policy covers tools that rewrite style — the formatter and the style linter. It does **not** cover
`{{STATIC_ANALYSIS_TOOL}}`, which reports real defects that only a human or an agent can fix; running that is required, not barred. See
[Static Analysis](./static-analysis.md).

**Rules:**

- **A coding agent MUST NOT run `{{FORMAT_COMMAND}}` or any other formatter, style linter, import sorter, or codemod — in any mode, including
  `--check`/`--test`/`--dry-run`.** This holds even when the agent believes the change is small and even when the user's request appears to imply reformatting.
- Style and formatting findings are not the agent's problem. Do not seek them out, and if one surfaces from another source, do not act on it — CI rewrites the file
  automatically.
- Do not hand-match the formatter's output to pre-empt it. Write the code plainly and let the CI pass settle whitespace, import order, and line breaks.
- CI owns the formatting pass. `{{FORMAT_COMMAND}}` runs there and nowhere else; developers do not run it locally either.
- Never run a whole-repo rewrite as part of an unrelated change. A formatting sweep is its own commit, on its own branch, produced by CI.
- `{{STATIC_ANALYSIS_COMMAND}}` is explicitly **not** restricted by this policy and is expected before a change is called done — see
  [Static Analysis](./static-analysis.md).
- {{GEN:name every style-rewriting tool this project has — the formatter and style linter (e.g. Pint, Biome, Prettier, php-cs-fixer, an ESLint autofix run), plus any
  codemod runner or import sorter — and state that all of them fall under this CI-only rule in every mode. Detect from the tooling config and CI. Be explicit that this
  list does not include {{STATIC_ANALYSIS_TOOL}}, so the agent can tell the forbidden commands from the required one at a glance.}}

> Severity for plan review: **BLOCK**.
