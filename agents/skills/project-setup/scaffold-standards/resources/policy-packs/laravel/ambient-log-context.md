# Ambient Log Context

Before adding a context key to a `Log::` call, check what `Context`, `Log::shareContext()`, middleware, and service providers already inject. Do not re-pass a field the
framework supplies — **and do not trust an ambient field in work that iterates across scopes.**

Anything stored via `Illuminate\Support\Facades\Context` is automatically appended as metadata to every log record for the rest of the request, command, or job — and it
is dehydrated into queued job payloads and rehydrated when the worker picks them up, so it survives the queue boundary without anyone passing it along.
`Log::withContext()` and `Log::shareContext()` do the same for a channel and for all channels respectively. The practical result is that `trace_id`, the user, and — in a
multi-tenant application — `tenant_id` are usually already on the record before the call site adds anything. Passing them again produces two copies of the same value that
drift the first time one source changes.

The failure mode that actually costs an incident is the opposite one. Ambient context is bound to the scope that set it: one request, one tenant, one job. A process that
walks *across* tenants — reconciling billing for every tenant, a cross-account backfill, a nightly system command — either starts with no tenant in context or keeps the
first one it was given for the entire run. Every record then carries a `tenant_id` that is missing or flatly wrong, and because the field looks populated nobody questions
it while triaging. Tenancy packages make this easy to walk into: they bind the tenant during a request or while a tenant is "current", and a loop that switches tenants
without re-scoping the context leaves the log field stale.

**Rules:**

- Read the ambient context before writing a log call. Check the application's middleware, the service providers' `boot()` methods, and any tenancy or correlation package
  for `Context::add(...)`, `Log::withContext(...)`, and `Log::shareContext(...)`.
- Do not re-pass an ambient field at the call site. If `tenant_id` and `trace_id` are injected at boot, `Log::info('invoice issued', ['invoice_id' => $invoice->id])` is
  the complete call — adding `tenant_id` again is noise that will eventually disagree with the canonical value.
- Pass at the call site only what is specific to *this* event: the record id, the outcome, the counts.
- **In any loop or command that spans more than one tenant/account, set the context explicitly per iteration.** Use `Context::scope(...)` so the value is restored
  afterward rather than leaking into the next iteration. Never assume the ambient tenant is the one you are currently operating on.
- The same applies to any long-running process that changes ambient scope mid-run — a queue worker handling several tenants' jobs, a daemon, an Octane request lifecycle.
  If the scope can change, set it explicitly.
- Prefer `Context::add()` over `Log::shareContext()` for new ambient fields, so the value crosses the queue boundary with the job instead of stopping at the request.
- Secrets and personal data go in `Context::addHidden(...)` or nowhere. Hidden context is not written to logs.
- {{GEN:list this project's actual ambient context keys and the exact file each is injected from — the middleware class, the service provider, or the tenancy package — so
  a reader can see which keys never need passing. Detect from the middleware stack, provider `boot()` methods, and the tenancy/correlation packages in
  `composer.json`. Ask the user if the injection point is not obvious.}}

**Example:**

```php
// Bad — re-passes tenant_id and trace_id that middleware already injected via Context::add(),
// and buries the module in a context key instead of the message prefix
Log::info('invoice issued', [
    'module' => 'billing',
    'tenant_id' => $tenant->id,
    'trace_id' => Context::get('trace_id'),
    'invoice_id' => $invoice->id,
]);

// Good — module in the template prefix; only what this event adds in the context;
// the ambient keys ride along automatically
Log::info('[Billing] invoice issued', ['invoice_id' => $invoice->id]);
```

```php
// Bad — system-level loop: tenant_id in the context is whatever it was at boot,
// so every record is attributed to the wrong tenant (or to none)
foreach ($tenants as $tenant) {
    $this->reconcileBilling($tenant);
    Log::info('[Billing] reconciled', ['charged_cents' => $total]);
}

// Good — the ambient field is set for the iteration and restored afterward
foreach ($tenants as $tenant) {
    Context::scope(function () use ($tenant, &$total): void {
        $total = $this->reconcileBilling($tenant);

        Log::info('[Billing] reconciled', ['charged_cents' => $total]);
    }, data: ['tenant_id' => $tenant->id]);
}
```

> Severity for plan review: **WARN**.
