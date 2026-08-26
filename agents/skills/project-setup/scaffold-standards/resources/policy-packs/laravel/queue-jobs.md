# Queue Jobs

Jobs are the only thing that queues. Every queued job is idempotent and safe to retry, sets `tries` / `backoff` / `failOnTimeout` explicitly, and inherits ambient context
rather than re-applying it. Event listeners always run synchronously and dispatch a job when work must move off the request.

Worker crashes, deploys, and network blips will replay jobs — a job that double-charges a card or double-sends an email on retry is a defect. An explicit retry policy
makes failure behavior a decision rather than whatever the framework default is this version. Laravel's `Context` propagates the dispatching request's ambient values
(tenant, correlation id) into the job automatically, so re-applying them inside `handle()` is both redundant and dangerous: a recycled worker can pin the wrong value.

A queued listener is a second, parallel background-work mechanism with its own serialization rules, its own retry configuration, and no class of its own to hang a retry
policy or an idempotency guard on. Keeping listeners synchronous means there is exactly one place background work is defined, one place it is configured, and one place to
look when a retry misbehaves. The listener stays a thin routing step: it decides what to do with the event and dispatches the job that does it.

**Rules:**

- Event listeners never implement `ShouldQueue` and are never registered with `Queue::listen`-style deferred handling. A listener that needs background work dispatches a
  job.
- Do not queue via `->onQueue()` / `->afterCommit()` on a listener, or via queued notification/mailable handling invoked directly from a listener body; route it through a
  job instead.
- Set `public int $tries`, `public int $backoff`, and `public bool $failOnTimeout` explicitly on every job class.
- The `handle()` body is safe to run twice without doubling its effect — guard with `Cache::lock(...)->block(...)` or a state check before the mutation. See
  [Cache Lock over `lockForUpdate`](./cache-lock-over-lockforupdate.md).
- Do not re-apply ambient context inside `handle()`; it is inherited from the dispatching context — see [Ambient Log Context](./ambient-log-context.md). A job that
  processes several tenants in one run is the exception and must scope the context per iteration.
- Jobs take DTOs or primitive scalars in their constructor, never a serialized model — see [Eloquent vs DTO](./eloquent-vs-dto.md).
- Let failures throw so the retry/backoff machinery engages; do not catch-and-swallow inside `handle()` to force a false success.

**Example:**

```php
// Bad — no retry policy, re-applies context, unguarded external mutation
class SyncContact implements ShouldQueue
{
    public function __construct(public int $contactId) {}

    public function handle(): void
    {
        Context::add('tenant_id', $this->tenantId);
        Http::post('https://api.example/contacts', Contact::find($this->contactId)->toArray());
    }
}

// Good — explicit policy, inherited context, guarded and idempotent
class SyncContact implements ShouldQueue
{
    public int $tries = 5;
    public int $backoff = 60;
    public bool $failOnTimeout = true;

    public function __construct(public ContactData $contact) {}

    public function handle(): void
    {
        Cache::lock("contact:sync:{$this->contact->id}", 120)->block(10, function (): void {
            Http::post('https://api.example/contacts', $this->contact->toArray())->throw();
        });
    }
}
```

```php
// Bad — the listener itself queues, so the retry policy and idempotency guard have nowhere to live
class SendWelcomeEmail implements ShouldQueue
{
    public function handle(UserRegistered $event): void
    {
        Mail::to($event->email)->send(new WelcomeMail());
    }
}

// Good — the listener runs synchronously and dispatches the job that does the work
class SendWelcomeEmail
{
    public function handle(UserRegistered $event): void
    {
        SendWelcomeEmailJob::dispatch($event->user);
    }
}
```

> Severity for plan review: **WARN**.
