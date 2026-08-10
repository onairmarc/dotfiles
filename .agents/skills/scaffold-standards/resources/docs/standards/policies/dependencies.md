# Dependencies

Adding a third-party dependency is a decision, not a reflex.

Every dependency is a permanent liability: it must be updated, audited, and understood by whoever debugs through it at 2am, and it can be abandoned by its maintainer at
any time. The standard library and what the framework already provides carry none of that cost. A dependency that saves fifty lines rarely repays the supply-chain and
maintenance bill; one that saves a subsystem usually does.

**Rules:**

- Prefer what is already available — the framework's own facilities first, then the standard library — before reaching for a package. When the framework and the standard
  library both offer the operation, the framework's version wins: it is already a hard dependency, it is configured and testable through the same machinery as the rest of
  the application, and it usually handles the edge cases (locale, encoding, missing keys) that the raw function leaves to the caller.
- A new dependency needs a reason that outweighs its maintenance, security, and supply-chain cost — state it in the pull request.
- Pin and lock dependencies through the project's lockfile; never rely on a floating version resolving the same way twice.
- Remove a dependency when its last consumer is deleted. An unused dependency is still an attack surface.
- **Check the license before adding anything.** Viral copyleft — GPL, AGPL, SSPL — is forbidden outright, as is a package with no declared license. See
  [Dependency Licensing](./dependency-licensing.md) for the full classification and the transitive-tree rule.
- {{GEN:name the concrete framework-first ordering for {{STACK}} — the framework helper namespaces or modules that take precedence over their standard-library
  equivalents, with two or three real pairs. Author from the detected stack. Omit this bullet if the project has no framework beyond the language runtime.}}
- {{GEN:any *other* dependency policy this project enforces beyond licensing — allowlist, minimum age, vendor trust, approval process. Ask the user; if there is none,
  state the default "prefer what is already available, justify additions" rule and drop the extra clause.}}

> Severity for plan review: **WARN**.
