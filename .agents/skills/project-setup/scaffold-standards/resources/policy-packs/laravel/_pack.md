# Laravel Policy Pack

**Pack gate:** `composer.json` requires `laravel/framework` **or** any `illuminate/*` package (most commonly `illuminate/support`).

The second half of the gate matters: a Laravel **package** depends on the `illuminate/*` components it needs rather than on `laravel/framework`, so gating on the
framework alone would skip the pack for exactly the repositories that most need it. Individual policies below still narrow further — a package with no `database/`
directory or no HTTP surface gates those rows out on their own.

Policies in this pack state Laravel-specific mechanisms that the language-agnostic core templates deliberately leave open. Adopt the pack only after confirming it with
the user; adopt each individual policy only when its own gate matches.

| Policy file                        | Severity | Index category                       | Individual gate                                                | Supersedes core policy     |
|------------------------------------|----------|--------------------------------------|----------------------------------------------------------------|----------------------------|
| `no-raw-sql.md`                    | BLOCK    | Data, configuration, transfer shapes | Always (with pack)                                             | `data-access.md`           |
| `no-db-facade.md`                  | BLOCK    | Data, configuration, transfer shapes | Always (with pack)                                             | —                          |
| `laravel-migrations.md`            | WARN     | Data, configuration, transfer shapes | `database/migrations/` exists                                  | `schema-migrations.md`     |
| `no-foreign-key-constraints.md`    | BLOCK    | Data, configuration, transfer shapes | User confirms the project enforces relations in Eloquent only  | —                          |
| `eloquent-vs-dto.md`               | WARN     | Data, configuration, transfer shapes | Always (with pack)                                             | `data-transfer-objects.md` |
| `dto-class-properties.md`          | WARN     | Data, configuration, transfer shapes | `spatie/laravel-data` required                                 | —                          |
| `typed-config-classes.md`          | BLOCK    | Data, configuration, transfer shapes | Always (with pack)                                             | `typed-config-objects.md`  |
| `carbon-immutable-only.md`         | WARN     | Code style, structure, language      | Always (with pack)                                             | `immutable-value-types.md` |
| `illuminate-over-stdlib.md`        | WARN     | Code style, structure, language      | Always (with pack)                                             | —                          |
| `no-final-or-readonly.md`          | WARN     | Code style, structure, language      | User confirms the open-by-default stance                       | `type-sealing.md`          |
| `ambient-log-context.md`           | WARN     | Logging, errors, validation          | Always (with pack)                                             | —                          |
| `form-request-validation.md`       | WARN     | Logging, errors, validation          | Project exposes HTTP endpoints                                 | `input-validation.md`      |
| `queue-jobs.md`                    | WARN     | Concurrency and background work      | Project dispatches queued jobs or registers event listeners    | `background-jobs.md`       |
| `cache-lock-over-lockforupdate.md` | WARN     | Concurrency and background work      | Project dispatches queued jobs or has concurrent writers       | `concurrency-guards.md`    |
| `pest-conventions.md`              | BLOCK    | Testing and documentation            | `pestphp/pest` required                                        | —                          |
| `eloquent-factories-only.md`       | BLOCK    | Testing and documentation            | Always (with pack)                                             | `test-data-factories.md`   |
| `filament-panel-rbac.md`           | BLOCK    | Authorization and panels             | `filament/filament` required                                   | —                          |
| `livewire-wire-typing.md`          | BLOCK    | Frontend                             | `livewire/livewire` required                                   | —                          |
| `module-monorepo-workflow.md`      | BLOCK    | Modules and boundaries               | `composer.json` declares path repositories for in-repo modules | —                          |

**Notes for the skill:**

- **A pack policy inherits the severity of the core policy it supersedes.** Supersession swaps the *mechanism* a rule is stated in, never how hard the rule bites — a
  project does not get a stricter rule because it happens to be built on Laravel. The `Severity` column above must equal the superseded core policy's footer severity;
  when it does not, the manifest is wrong. Severity changes only when the user says the project treats that rule differently, per the Fill and Write phase.
- **A pack policy carries forward every rule of the core policy it supersedes.** The superseded core file is not written, so any rule it owned that the pack file omits
  is silently lost. Before adopting a supersession, diff the two rule lists and confirm nothing dropped out.
- `pest-conventions.md` extends `testing.md` rather than replacing it; write both, and have `testing.md` link to it.
- `ambient-log-context.md` extends `structured-logging.md` rather than replacing it; write both, and have `structured-logging.md`'s ambient-context `{{GEN}}` block name
  `Context` / `Log::shareContext()` and point at the pack file for the detail.
- **Licensing stays in the core policy.** No pack file supersedes `dependency-licensing.md` — the GPL/AGPL/SSPL ban is stack-independent and states fine agnostically.
  What the pack contributes is the *mechanism*: resolve that policy's tooling `{{GEN}}` block to Composer's own reporting (`composer licenses`, and the `license` field
  in each manifest), and note that the resolved tree lives in the root `composer.lock` even for requirements declared in a module manifest.
- `no-db-facade.md` and `no-raw-sql.md` together replace the agnostic `data-access.md`; write both pack files and skip the core file.
- When a pack policy is skipped by its individual gate but supersedes a core policy, write the **core** policy instead — the concern still applies, only the Laravel
  mechanism does not.
- Two categories in this manifest (`Authorization and panels`, `Frontend`) do not exist in the core index. Add the section to `policies.md` only when a policy lands in
  it.
- Cross-file dependencies. When one of these pack policies is written, the file it links to must be written too — or the link rewritten to drop the reference:
    - `filament-panel-rbac.md` → core `authorization-identifier-naming.md`
    - `no-foreign-key-constraints.md` → core `module-isolation.md`
    - `no-db-facade.md` and `queue-jobs.md` → pack `cache-lock-over-lockforupdate.md`
    - `queue-jobs.md` and `data-transfer-objects` rules in `eloquent-vs-dto.md` → core `module-isolation.md`
    - `queue-jobs.md` → pack `eloquent-vs-dto.md` and pack `ambient-log-context.md`
    - `dto-class-properties.md` → pack `eloquent-vs-dto.md`
    - `no-final-or-readonly.md` → pack `typed-config-classes.md`
    - `illuminate-over-stdlib.md` → core `dependencies.md` (always written) and pack `carbon-immutable-only.md`
    - `ambient-log-context.md` → core `structured-logging.md` (always written)
    - `module-monorepo-workflow.md` → core `documentation.md` and core `dependency-licensing.md` (both always written)
- **Inbound links into superseded files.** A core policy that *survives* may link to a core policy this pack supersedes, leaving a dangling reference. Rewrite each of
  these to point at the pack file that replaced the target:
    - core `configuration-access.md` → `typed-config-objects.md`, replaced by pack `typed-config-classes.md`
    - core `error-handling.md` → `input-validation.md`, replaced by pack `form-request-validation.md`
    - core `test-helper-classes.md` → `test-data-factories.md`, replaced by pack `eloquent-factories-only.md`
    - core `module-isolation.md` → `data-transfer-objects.md`, replaced by pack `eloquent-vs-dto.md`
    - core `background-jobs.md` → `concurrency-guards.md` and `data-transfer-objects.md`, replaced by pack `cache-lock-over-lockforupdate.md` and `eloquent-vs-dto.md`
      (only relevant when `queue-jobs.md` gated out and the core file was written)
