# Static Analysis

`{{STATIC_ANALYSIS_TOOL}}` runs on every build and the only acceptable response to a finding is to fix the underlying code. **An agent runs `{{STATIC_ANALYSIS_COMMAND}}`
against its own work before calling it done.**

Suppressing a finding erodes the safety net the whole codebase relies on for refactors. Every new finding is a hint that a contract is wrong — a type that does not
describe reality, a nullable value treated as present, an unreachable branch — not noise to be silenced. A baseline or ignore file exists for legacy debt being paid down,
never as a landing zone for new issues.

This tool is not a linter and the distinction is critical. `{{STATIC_ANALYSIS_TOOL}}` reports **defects** — a real type error, a null dereference, an impossible branch —
that only a human or an agent can correctly resolve, and that a failing build should never be shipped past. A style linter reports **formatting** it can rewrite itself,
which is why running one is barred by [Formatter Authority](./formatter-authority.md). Findings here are the agent's problem; findings there are not.

**Rules:**

- Warnings are treated as errors. A change that introduces a new finding does not merge.
- Every finding is resolved at its **root cause** — correct the contract, narrow the type, or add the missing annotation.
- **Never suppress a finding to make the build pass.** No blanket ignore comments, no lowering the ruleset, no excluding files, no new baseline entries. A suppression is
  allowed only with an inline justification approved in review, and only when the finding is a proven false positive. A human must approve the suppression, not an agent.
- Fix pre-existing analysis failures you encounter — the build blocks on them regardless of who introduced them. Do not label a failure "pre-existing" and move on.
- Running `{{STATIC_ANALYSIS_COMMAND}}` is expected of agents and humans alike before a change is considered done. It only reads; it never rewrites your files.
- {{GEN:the exact local invocation an agent should use to check its own work before the build runs — including whether it must be scoped to changed files rather than the
  whole codebase — and the ruleset/config file and level/preset {{STATIC_ANALYSIS_TOOL}} runs at, from the detected tooling config. Name the analyzer specifically; do not
  fold a style linter into this command.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a suppressed finding ("Bad" — an ignore comment or cast that silences the tool) with the same code fixed at the
root cause ("Good" — an early return or narrowed type that makes the property provable).}}

> Severity for plan review: **BLOCK**.
