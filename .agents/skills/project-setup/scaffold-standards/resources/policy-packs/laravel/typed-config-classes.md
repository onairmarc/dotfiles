# Typed Config Classes

A Laravel config file under `config/` exists for exactly one purpose: to load environment variables into the framework. It is not the application's configuration surface.
**Class-based configs are what the application actually uses** — a typed config class loads each value into a **public typed property in the constructor**, and
application code reads that property. Never scattered `config('...')` calls, and never a method that wraps a framework config accessor.

`env()` outside the config directory returns `null` the moment configuration is cached, which is exactly how it behaves in production and never locally — so
`config/*.php` is the only place `env()` may appear, and its whole job is that hand-off. Scattered `config('some.key')` calls give no type safety, no completion, and no
single place to override in tests. A class full of `imapHost(): string { return Config::string(...); }` getters re-reads the container on every call and hides the config
shape behind boilerplate — properties make the contract the property list and nothing else. The constructor **is** the config class's real work, so a constructor is
expected here, unlike a DTO.

**Rules:**

- `env(...)` may be called only inside files under `config/`. Application code, modules, and tests never call it.
- Files under `config/` do nothing but map environment variables to keys. No logic, no derived values, no service resolution — just `env('VAR', $default)` with a sensible
  default, which is what runs when the variable is unset.
- Application code reads configuration through a typed config class; each value is a **public typed property** assigned in the constructor from a single
  `Config::string|integer|boolean|array(...)` read.
- No method that only wraps a framework config accessor — `config(...)`, `Config::get(...)`, `Config::string(...)`, or any facade/helper equivalent. Consumers read
  `$config->initialSyncDays`, never `$config->initialSyncDays()`.
- A method is justified only when its body does real work beyond a config read — deriving from multiple keys, formatting, a computed default.
- Resolve the config class from the container (constructor injection or `app(FooConfig::class)`) so reads happen against live config.
- {{GEN:name where typed config classes live for this project given {{MODULE_LAYOUT}} — e.g. `app/Support/Config/` plus per-module `src/Support/Config/`. Detect and
  confirm.}}

**Example:**

```php
// config/mail.php — only job is loading env vars into the framework
return [
    'imap' => [
        'host' => env('MAIL_IMAP_HOST', 'localhost'),
        'initialSyncDays' => env('MAIL_IMAP_INITIAL_SYNC_DAYS', 30),
    ],
];

// Bad — a bag of getters wrapping framework config accessors; call sites need ()
class EmailConfig
{
    public function imapHost(): string
    {
        return Config::string('mail.imap.host');
    }
}

// Good — typed properties assigned once in the constructor
class EmailConfig
{
    public string $imapHost;
    public int $initialSyncDays;

    public function __construct()
    {
        $this->imapHost = Config::string('mail.imap.host');
        $this->initialSyncDays = Config::integer('mail.imap.initialSyncDays');
    }
}
```

> Severity for plan review: **BLOCK**.
