---
name: security-research-php
description: PHP and Laravel application security review for web requests, Eloquent, Blade, Livewire, queues, and package configuration. Use when a repository contains PHP code.
---

# PHP and Laravel security overlay

Apply `security-research` first. Confirm the installed PHP and framework behavior from `composer.json`, lock files, source, and project configuration.

## Entry points and authorization

- Inspect routes, middleware, controllers, form requests, policies, gates, jobs, commands, Livewire actions, webhook handlers, and scheduled tasks.
- Verify authentication, authorization, tenant scoping, ownership checks, and reauthorization at every object and state transition. Check route model binding and
  query scopes for IDOR and cross-tenant access.
- Review CSRF coverage, session fixation and invalidation, cookie flags, password reset and email verification tokens, rate limiting, and account enumeration.

## PHP and Laravel sinks

- Review raw SQL, query fragments, untrusted column or sort names, Eloquent mass assignment, attribute casting, and model serialization for injection or data exposure.
- Review Blade, Livewire, JSON, mail, PDF, and redirect output for context-appropriate encoding and unsafe HTML or URL handling.
- Review `eval`, `include`, `require`, variable functions, shell execution, process APIs, unserialization, and dynamic class resolution for code execution.
- Review uploads, `Storage`, archive extraction, temporary paths, symlinks, and download responses for traversal, overwrite, MIME, and executable-file risks.
- Review outbound HTTP clients, redirects, URL parsing, DNS or private-address validation, and credential forwarding for SSRF.
- Review password hashing, encryption, random tokens, key storage, signed URLs, logs, exceptions, and debug output for cryptographic or secret-handling flaws.

## Configuration and supply chain

Inspect `.env` handling, `config`, PHP production settings, `composer.json` and `composer.lock`, service providers, queue serialization, trusted proxies, HTTPS,
security headers, debug mode, request limits, and rate limits. Check that secrets are not committed, logged, rendered, or included in published artifacts.

Use the [PHP security manual](https://www.php.net/manual/en/security.php),
[OWASP PHP Configuration Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/PHP_Configuration_Cheat_Sheet.html),
and [OWASP Laravel Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Laravel_Cheat_Sheet.html) for verification.
