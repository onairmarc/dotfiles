# Structured Logging

Diagnostic output goes through **{{LOG_LIBRARY}}** with a static message template plus a structured context payload; ad-hoc debug output does not appear in committed
code.

Logs are read by humans during incidents and by tooling during routine operation, so they are a first-class interface rather than an afterthought. Structured context —
the request id, the tenant or account, the record being mutated — is what makes a line actionable and searchable; a message with the values interpolated into the string
is neither. Ad-hoc debug output is worse than useless in production: it is unsearchable, unleveled, and can leak data into a response.

Some of that context arrives on its own. Frameworks and their packages inject ambient fields at boot or per request, so the correlation keys a call site would think to
pass are often already attached to every record. Knowing which ones is part of writing a good log line: duplicate a field the pipeline supplies and you get two copies
that drift apart, but assume a field is ambient when the process has stepped outside the scope that sets it and you get records labeled with the wrong value — which is
the more expensive mistake, because the log looks correct while pointing at the wrong tenant.

This file carries the **full logging contract**: the policy rules below, the write-side reference every call site follows, and the read-side playbook for reconstructing
behavior from emitted logs.

**Rules:**

- Use **{{LOG_LIBRARY}}** with a **static** message template. Dynamic values go in the structured context, never interpolated into the message.
- **Prefix the message with the originating module in brackets** — `"[Billing] payment authorized"` — rather than passing the module as a context key. The prefix keeps
  the origin visible in a raw tail and greppable across the source tree. See [Message templates](#message-templates).
- Pass context on essentially every call. If you cannot name a single useful context key, the line is probably not worth writing.
- Pick the level deliberately: `error` is an actionable failure, `warn` is recoverable degradation, `info` is a discrete business event, `debug` is developer detail
  behind a gate. See [Log levels](#log-levels).
- Carry the required correlation fields on every `info`-level-and-above record — see [Required context fields](#required-context-fields).
- Do not select a log destination at the call site — routing is a configuration decision that the logging configuration already owns.
- Banned in committed code: `print`, `console.log`, stdout/stderr writes, and any debug-dump helper used as a logging mechanism.
- Sensitive payloads — tokens, credentials, full card numbers, personal data — are redacted or excluded, never logged raw.
- **Know what is already in the context before you add anything.** Middleware, service providers, framework bootstrappers, and third-party packages commonly inject
  ambient fields — request/trace id, authenticated user, tenant or account — into every record automatically. Check those entry points first; re-adding a field the
  pipeline already supplies is redundant, and the manual copy will eventually drift from the canonical one.
- **Set an ambient field explicitly when the process is not running under it.** The automatic injection is bound to a single ambient scope — one request, one tenant, one
  job. Work that iterates *across* scopes — billing reconciliation over every tenant, a cross-account backfill, a scheduled system task — either has no ambient value or
  keeps the one it started with, so every record in the loop is unlabeled or, worse, labeled with the wrong tenant. In that case set the field per iteration, scoped so it
  is restored afterward, and never rely on the ambient value.
- {{GEN:name the ambient log context this project injects and where it is injected from — the middleware, service provider, bootstrapper, or package that does it — and
  list the exact field names it supplies, so a reader can tell at a glance which keys never need to be passed at a call site. Detect from the logging setup and the
  dependency list; ask the user about any tenancy/correlation package. Then name the mechanism this project uses to override one of those fields for a bounded block of
  work, for the cross-scope case above.}}
- {{GEN:any message-template convention this project adds beyond the bracketed module prefix — a sub-scope token, an event-name casing rule. Author from the detected
  logging setup and confirm with the user. Omit this bullet if the prefix is the whole convention.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting an interpolated, context-free, destination-pinned log call that carries the module as a context key ("Bad") with a
static template prefixed by the bracketed module plus structured context at the right level ("Good").}}

> Severity for plan review: **BLOCK**.

---

## The write-side contract

What every log call site must follow.

### Format and pipeline

- Logging library: **{{LOG_LIBRARY}}**.
- Logs are **structured** — every record is a message template plus typed key/value context, serialized to the sink. No interpolating values into the message string.
- Production aggregation sink: **{{LOG_SINK}}**.
- {{GEN:the concrete pipeline — how a log record travels from a call site to {{LOG_SINK}} (middleware, appender, exporter) and the serialization format (JSON, logfmt) —
  authored from the detected logging setup.}}

### Logger entry points

- Obtain a logger through the framework-provided mechanism (injection / module logger / context logger) — do not construct ad-hoc logger instances.
- A module- or class-scoped logger is fine and does not replace the bracketed message prefix. Whatever the logger records about its own origin lives in the structured
  payload, which is precisely what the prefix exists to survive without.
- {{GEN:the concrete entry point for {{LOG_LIBRARY}} on {{STACK}} (e.g. the injected logger, a facade, the default package logger) with the one-line idiomatic acquisition
  snippet.}}

### Required context fields

Every `info`-level-and-above record MUST carry the fields below so records can be filtered without reading source. These are the filter keys the
[read-side playbook](#the-read-side-playbook) relies on.

{{GEN:a table of the project's real correlation keys — one row per field with "field", "what it identifies", and "required on". Author from the stack and domain (common
keys: request_id/trace_id, user_id, error; plus domain keys the user names such as tenant_id or job_class). Ask the user for the domain-specific correlation keys. Do
**not** include a `module` key — the originating module belongs in the message template prefix, not the context; see [Message templates](#message-templates).}}

### Message templates

- The message is a **constant template**; variables go in the context, not the string. This keeps records groupable by template at the sink.
- **The originating module is a bracketed prefix on the message, not a context key.** Write `"[Billing] payment authorized"`, never `"payment authorized"` with a
  `module` context field. The prefix is part of the constant template, so it stays groupable, and it survives every place the context does not: a raw `tail`, a truncated
  line, a plain-text formatter, a grep across the log file, a paste into a ticket. A `module` key is only visible where something has already parsed and expanded the
  structured payload — which is exactly not the situation you are in when reading logs quickly.
- The prefix is also what makes templates searchable as a set: `grep '\[Billing\]'` returns that module's entire log surface from the source tree as readily as from the
  sink, and a new call site is written by copying a neighboring one.
- Message text after the prefix is a short, present-tense statement of the event: `"[Billing] payment authorized"`, `"[Sync] profile synced"`, `"[Queue] job failed"`.
- Do not put personal data or secrets in the message or in context fields. Redact at the call site.
- {{GEN:state the exact prefix vocabulary for this project — the bracketed token used for each module in {{MODULE_LAYOUT}}, and its casing — so every call site in a
  module writes the identical prefix. Author from the detected module list and confirm with the user.}}
- Log an event **once**, at the layer that owns the outcome. Do not re-log the same event as it bubbles up the stack.

### Log levels

| Level   | Use for                                                             |
|---------|---------------------------------------------------------------------|
| `error` | An actionable failure — something a human/agent must investigate.   |
| `warn`  | Recoverable degradation — a retry, a fallback, a soft limit hit.    |
| `info`  | A discrete business event worth reconstructing later.               |
| `debug` | Developer detail. Off in production unless a debug gate is enabled. |
| `trace` | Firehose-level detail; local diagnosis only.                        |

### Banned output

- No `print` / `console.log` / stdout or stderr writes as logging in committed code.
- No logging inside tight loops without a volume guard — emit a per-batch summary, not a record per iteration.
- No logging of full request/response bodies on unauthenticated routes (personal-data risk).
- {{GEN:any project-specific banned sinks or forbidden fields the user names. Omit this bullet if there are none beyond the defaults above.}}

### Volume control

- High-frequency paths log a summary, not per-item detail. Guard expensive log construction behind an `isEnabled(level)` check so it is skipped when the level is
  disabled.
- Debug logging for a noisy subsystem is gated (feature flag, per-module toggle, or config) rather than always-on.
- {{GEN:the project's debug-gating mechanism if one exists (feature flag, per-module config toggle). Omit this bullet if the project has none.}}

### What belongs elsewhere

- Runtime **metrics** (throughput, latency, cache hit rate) belong in the metrics/APM system, not the log sink.
- One-off **data backfills** belong in the project's operations/migration runner, not in log-and-hope code.
- {{GEN:name the project's metrics/APM tool and its operations/backfill runner so the boundary is unambiguous. Ask the user if not detectable.}}

---

## The read-side playbook

For anyone — human or coding agent — diagnosing **{{PROJECT_NAME}}** behavior from its logs. Reading this section plus the log output should be enough to reconstruct any
operation without source-code spelunking.

### Where the logs live

{{GEN:a table of log destinations with columns "destination", "local development", "production" — authored from the detected/asked logging setup. Cover the production
sink ({{LOG_SINK}}) and however logs surface locally (stdout, a tail command, a local file). State plainly if local file logs are not used.}}

### Narrowing to a module

Module is not a context field — it is the bracketed prefix on the message. Narrow to one module by matching the message text (`[Billing]`) rather than by filtering on a
key, and the same match works in the sink, in a raw `tail`, and in a `grep` over the source tree.

{{GEN:show the concrete message-match syntax for {{LOG_SINK}} that filters to one module's prefix, plus the equivalent local `grep`/tail invocation. Use a real module
name from {{MODULE_LAYOUT}}.}}

### Key context fields for filtering

Every `info`+ record carries structured context. When chasing an issue, filter by these in order of specificity — most specific first.

{{GEN:a table mirroring the [Required context fields](#required-context-fields) table above, with columns "field", "what it identifies", "where to filter" (the concrete
UI/query location in {{LOG_SINK}}). Keep it consistent with the write-side table — in particular, it carries no `module` row, since module is matched on the message
prefix instead.}}

### Common diagnostic patterns

Worked examples of turning a symptom into a query. Each is: the question, then the numbered filter/inspect steps.

{{GEN:2–4 diagnostic playbooks tailored to this project's domain and stack — each a "Why did X happen?" question followed by numbered steps that name the real fields,
record messages, and tools to filter by. Base them on the project's actual subsystems (ask the user for the top failure modes worth documenting).}}

### What is NOT in the logs

Deliberately omitted to keep signal-to-noise high:

{{GEN:the categories intentionally kept out of the log sink and where to find them instead (e.g. query traces → the APM tool, cache stats → the metrics dashboard,
redacted request bodies). Author from the "What belongs elsewhere" section above and keep the two consistent.}}

### Logs vs. metrics — quick reference

{{GEN:a short bulleted contrast of the project's log sink ({{LOG_SINK}}, for discrete events and errors) versus its metrics/APM tool (for live throughput/latency) and any
local tail tool — stating which question each answers. Omit tools the project does not have.}}
