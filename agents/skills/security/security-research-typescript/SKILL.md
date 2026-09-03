---
name: security-research-typescript
description: TypeScript, JavaScript, Node.js, and browser application security review for APIs, frontends, build tooling, and npm supply chains. Use when a repository contains TypeScript or JavaScript code.
---

# TypeScript and JavaScript security overlay

Apply `security-research` first. Treat TypeScript types as compile-time assistance, not runtime validation, and identify whether each module runs in a browser,
Node.js, edge runtime, serverless function, or build process.

## Entry points and trust boundaries

- Inspect Express, Fastify, Nest, Next, serverless, WebSocket, GraphQL, CLI, worker, webhook, and browser event entry points.
- Verify runtime schema validation for request bodies, query and route values, headers, cookies, WebSocket messages, environment variables, and external API data.
- Verify server-side authentication and object-level authorization. Check client routes, hidden fields, JWT claims, role checks, and tenant identifiers for bypasses.
- Review CORS, CSRF, cookie flags, origin checks, postMessage, WebSocket origin validation, redirects, and browser storage.

## Runtime sinks

- Review SQL and NoSQL query objects, template rendering, `innerHTML`, DOM injection, URL construction, redirects, and unsafe HTML sanitization for injection and XSS.
- Review `eval`, `Function`, dynamic imports, `vm`, `child_process`, shell interpolation, prototype mutation, and unsafe deserialization for code execution or pollution.
- Review `fs`, archive extraction, path joins, file uploads, symlinks, and static file serving for traversal and overwrite risks.
- Review `fetch`, HTTP clients, redirects, URL parsing, DNS or private-address validation, and forwarded headers for SSRF and credential leakage.
- Review request and upload limits, regular expressions, JSON parsing, event-loop blocking, worker usage, and concurrency for denial of service.
- Review `crypto` usage, token storage, JWT verification, randomness, secrets in bundles or source maps, source maps in production, and sensitive logging.

## Supply chain and build security

Inspect `package.json`, lock files, workspace boundaries, `.npmrc`, install and lifecycle scripts, publish files, CI workflows, package scopes, dependency changes,
and generated artifacts. Check for dependency confusion, typosquatting, unreviewed scripts, leaked environment values, and missing audit or provenance controls.
Use `npm audit`, the repository's package-manager audit command, or SCA tools only with permission, then verify exploitable reachability in application code.

Use the [OWASP Node.js Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Nodejs_Security_Cheat_Sheet.html),
[OWASP NPM Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/NPM_Security_Cheat_Sheet.html),
and [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) for verification.
