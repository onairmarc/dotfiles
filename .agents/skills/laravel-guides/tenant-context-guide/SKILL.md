---
name: tenant-context-guide
description: Apply this skill when writing or reviewing any code that sets or switches tenant context — including command loops iterating over multi-tenant records, or any call to TenantContext::applyById or Context::forget(TenantContext::ID).
disable-model-invocation: false
allowed-tools: []
model: haiku
---

## How Tenant Context Works

Tenant context is resolved once and persisted automatically via Laravel's Context system. It propagates throughout the
entire request or job lifecycle without needing to be re-applied.

- **Web requests**: tenant context is applied in middleware and stays set for the lifetime of the request.
- **Queued jobs**: jobs dispatched from a web request or command inherit the tenant context automatically — do **not**
  re-apply it in `handle()`.
- **Command loops over multi-tenant data**: this is the only case where you need to call
  `TenantContext::applyById($tenantId, true)` — once per record to switch the context as you iterate across different
  tenants.

## The Only Rule

Never call `Context::forget(TenantContext::ID)`. When switching between tenants in a loop, calling
`TenantContext::applyById($tenantId, true)` with `true` resets the context to the new tenant. No cleanup is needed.

**Correct — command loop over multi-tenant records:**

```php
foreach ($records as $record) {
    TenantContext::applyById($record->tenant_id, true);
    // work runs in this tenant's context
}
```

**Correct — queued job (no applyById needed):**

```php
public function handle(): void
{
    // tenant context is already set — just do the work
    User::whereHasPermission(KBPermission::Reviewer)->cursor()->each(...);
}
```

**Never do this:**

```php
Context::forget(TenantContext::ID); // ❌ never needed
```