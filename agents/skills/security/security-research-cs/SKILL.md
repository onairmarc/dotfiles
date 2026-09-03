---
name: security-research-cs
description: C# and .NET application security review for ASP.NET Core, Entity Framework, desktop services, and shared libraries. Use when a repository contains C# code.
---

# C# and .NET security overlay

Apply `security-research` first. Verify behavior against the target .NET and framework version rather than relying on memory.

## Entry points and authorization

- Inspect endpoint routing, minimal APIs, controllers, Razor Pages, SignalR hubs, gRPC services, middleware order, filters, and background handlers.
- Verify authentication and authorization on every sensitive endpoint, including policy, resource, role, and tenant checks. Check both route-level and object-level
  authorization for identifiers supplied by the caller.
- Check anti-forgery protection for cookie-authenticated state changes, CORS origins and credentials, open redirects, and secure cookie settings.

## .NET-specific sinks

- Review EF Core raw SQL, interpolated SQL, dynamic identifiers, LINQ expressions, and query filters for SQL injection or tenant-filter bypass.
- Review `Process`, shell, PowerShell, reflection, expression compilation, unsafe code, native interop, and dynamic assembly loading for command or code execution.
- Review `BinaryFormatter`, dangerous serializers, polymorphic JSON settings, XML readers, and type binders for unsafe deserialization or XXE.
- Review `Path.Combine`, archive extraction, uploads, temporary files, and file serving for traversal, symlink, overwrite, and executable-file risks.
- Review `HttpClient` destinations, redirects, DNS or IP validation, proxy behavior, and response handling for SSRF and credential leakage.
- Review data protection, password hashing, token generation, certificate validation, TLS, key storage, and logs for cryptographic or secret-handling flaws.

## Configuration and supply chain

Inspect `appsettings`, environment binding, user secrets, launch settings, Docker and deployment files, NuGet manifests and lock files, debug exceptions, forwarded
headers, HTTPS enforcement, security headers, request limits, and rate limits. Check that production defaults do not expose diagnostics or secrets.

Use [Microsoft ASP.NET Core security guidance](https://learn.microsoft.com/en-us/aspnet/core/security/) and
the [OWASP .NET Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/DotNet_Security_Cheat_Sheet.html) to verify framework claims.
