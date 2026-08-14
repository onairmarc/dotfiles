# Dependency Licensing

Every dependency ships under a permissive license. **Viral copyleft licenses — GPL, AGPL, SSPL, and their variants — are forbidden**, at any depth of the dependency tree,
in application code, packages, build tooling, and test-only dependencies alike.

A permissive license (MIT, Apache-2.0, BSD, ISC) grants use with attribution and nothing more. A viral copyleft license attaches an obligation to the software that links
against it: the GPL family can require the combined work to be distributed under the same terms, and the AGPL extends that trigger to network use — merely running the
software as a hosted service can oblige source disclosure. SSPL goes further still and is not OSI-approved. The cost of getting this wrong is not a refactor: it is a
legal obligation over the whole codebase, discovered late, remediable only by ripping the dependency out and auditing everything that touched it. That asymmetry is why
this is a hard block rather than a judgment call — the downside is unbounded and the upside is one convenient package.

Transitive dependencies carry the same obligations as direct ones. A permissive package that pulls a GPL package into the lockfile puts the GPL terms in your build.

**Rules:**

- **Never add a dependency licensed GPL (any version), AGPL (any version), or SSPL.** This is absolute — it is not traded off against convenience, feature fit, or
  deadline. There is no "temporarily" and no "only in dev".
- The ban covers the **whole resolved tree**, not just direct requirements. Check what a candidate package drags in before adding it.
- It also covers **build, tooling, and test-only** dependencies. A copyleft tool that is merely run (not linked or distributed) is usually fine, but a test or build
  dependency that ends up linked into or bundled with a shipped artifact is not — and telling the two apart reliably is the reason this rule stays conservative.
- Weak and file-level copyleft — LGPL, MPL-2.0, EPL, CDDL — is **not** automatically allowed. It requires explicit approval before the dependency is added, because
  whether the obligation stays contained depends on how the code is linked and distributed.
- Verify the license **before** adding the dependency, not after. Record the license in the pull request that introduces it.
- A dependency that changes its license in a later version is treated as a new decision: re-check the license on major upgrades, and stop upgrading if it has moved to a
  forbidden one.
- Unlicensed code — no `LICENSE` or `LICENSE.md` file, no license metadata, "free to use" in a README and nothing more — is forbidden too. No license means no grant of
  rights.
- **Discovering a forbidden license halts the work immediately.** Stop implementing, do not commit around it, and do not proceed on the assumption it will be sorted out
  later. Raise it, then resolve it one of exactly two ways before any further work continues:
    1. **Replace it** with a permissively licensed dependency that covers the need, or
    2. **Hand-roll** the functionality in this repository under the project's own license.
        - Do not leave it in place because it "already shipped".
        - Do not lift the licensed code out of the dependency into this repository. The code is what is licensed, not the dependency itself.

  "Ship it now and swap it later" is not a third option. A forbidden-licensed dependency that reaches a release has already attached its obligations, and the remediation
  cost only grows with every commit written on top of it.
- The same halt applies to a dependency already in the tree: when an audit or an upgrade surfaces a forbidden license, new work depending on it stops until it is replaced
  or reimplemented. Do not leave it in place because it "already shipped".
- This policy is an engineering guardrail, not legal advice. {{GEN:name who to escalate a licensing question to in this organization — a legal contact, an engineering
  lead, or an approval process. Ask the user; if there is no such contact, state that the answer defaults to "do not add it" until someone can approve.}}
- {{GEN:name the command or tool that lists the licenses of the resolved dependency tree for {{STACK}} (for example the package manager's own license subcommand or a
  license-audit tool), and state whether it runs in CI. Detect from the tooling config and CI; if the project has no such check, say plainly that verification is manual
  at review time.}}

**License classification:**

| Class                | Examples                                         | Allowed?                                    |
|----------------------|--------------------------------------------------|---------------------------------------------|
| Permissive           | MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC | Yes                                         |
| Public-domain-like   | Unlicense, CC0-1.0                               | Yes                                         |
| Weak / file copyleft | LGPL, MPL-2.0, EPL-2.0, CDDL                     | Only with explicit approval, recorded in PR |
| **Viral copyleft**   | **GPL-2.0, GPL-3.0, AGPL-3.0, SSPL**             | **No — forbidden**                          |
| No license declared  | —                                                | **No — forbidden**                          |

{{GEN:if the user names additional licenses this project specifically allows or forbids, add them to the correct row. Otherwise leave the table as written.}}

> Severity for plan review: **BLOCK**. A plan that adds a GPL/AGPL/SSPL-licensed dependency, or that is found to depend on one, does not proceed under any override.
> Work halts until the dependency is replaced with a permissively licensed one or the functionality is reimplemented in this repository.
