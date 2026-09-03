---
name: security-research
description: Security-focused application review for vulnerabilities, security regressions, and exploitable data flows. Use when reviewing code or changes for application security.
---

# Application security research

Review application code as an attacker would, then verify each suspected path against the implementation. This skill is read-only unless the invoking agent
explicitly has permission to make changes.

## Scope

Default to a diff-based review of the current branch and its affected behavior. If the request names a file, feature, endpoint, or full codebase, review that
scope instead. Inspect configuration, dependency manifests, routes, middleware, templates, migrations, jobs, tests, and deployment files when they affect the
security boundary.

## Method

1. Establish the review boundary. Identify the changed files or requested subsystem, repository language and framework, exposed entry points, sensitive assets,
   trust boundaries, and relevant prior security controls.
2. Build the attack surface. Locate HTTP, RPC, CLI, queue, webhook, file, deserialization, template, database, filesystem, process, and outbound-network entry
   points. Include authentication, authorization, tenant, and administrative paths.
3. Trace data flow. Follow untrusted and sensitive data from every source through parsing, validation, normalization, authorization, business rules, storage,
   logging, rendering, and external calls. Treat client-side checks as untrusted.
4. Check controls. Verify default-deny authorization, object-level access checks, server-side validation, contextual output encoding, safe query and command
   construction, safe file handling, secure session and token handling, cryptography, rate and resource limits, error handling, logging, and dependency integrity.
5. Test hypotheses. Read every relevant caller, callee, middleware, framework implementation, configuration value, and consumer needed to prove or disprove an
   attack path. Use installed SAST, dependency, or test tools only with permission. Treat scanner output as a lead, not proof.
6. Validate impact. Describe a realistic attacker, required privileges, reachable trigger, affected asset, exploit result, and whether a defense-in-depth control
   blocks the path. Downgrade or remove findings that cannot be supported.
7. Report. Use the finding schema below, order by severity, deduplicate root causes, and distinguish vulnerabilities from hardening opportunities.

## Review priorities

Start with broken access control and authentication, then injection and unsafe interpretation, sensitive-data exposure, file and path handling, SSRF, unsafe
deserialization, cryptographic misuse, resource exhaustion, security misconfiguration, supply-chain changes, and logging or exception failures. Pay special
attention to IDOR, privilege escalation, cross-tenant access, mass assignment, race conditions, replay, and workflow bypasses.

## Finding schema

```text
severity: Critical | High | Medium | Low
confidence: High | Medium | Low
title: concise vulnerability name and affected component
location: repository-relative file path and exact line range
classification: CWE identifier and name; OWASP ASVS v5.0.0 requirement when defensible
impact: concrete confidentiality, integrity, availability, or accountability impact
preconditions: attacker privileges, input, state, and deployment conditions required
evidence: traced source, missing or ineffective control, sink, and relevant callers or consumers
reproduction: a safe, minimal request or test scenario without destructive payloads
remediation: smallest complete fix, including related validation or regression test
references: primary documentation URLs used to validate the conclusion
```

Report no finding when the path is unreachable, input is safely constrained, authorization is enforced by a verified control, or the concern is only a style
preference. Do not report secrets that are clearly placeholders or test fixtures unless they can be used against a real system.

## Severity

- **Critical**: likely unauthenticated or broadly reachable remote compromise, cross-tenant or mass data access, or severe loss of control.
- **High**: reliable account takeover, privilege escalation, sensitive data access, command or code execution, or material integrity impact.
- **Medium**: meaningful exploitation with limited scope, user interaction, privileges, or compensating controls.
- **Low**: real but limited security weakness with narrow impact or difficult exploitation.

Use confidence separately from severity. Do not inflate severity to compensate for uncertain evidence.

## References

- [OWASP ASVS 5.0.0](https://owasp.org/www-project-application-security-verification-standard/)
- [OWASP Top 10:2025](https://owasp.org/Top10/2025/)
- [MITRE CWE Top 25:2025](https://cwe.mitre.org/top25/archive/2025/2025_cwe_top25.html)
- [OWASP Secure Code Review Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secure_Code_Review_Cheat_Sheet.html)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/index.html)
