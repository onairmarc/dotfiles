# Input Validation

Externally-supplied data is validated once, at the boundary it enters through; everything downstream assumes the input is already valid.

The boundary is the only place that knows the full rule set for an entry point, including its authorization check and its error messages. Spreading rules across the
handler, the service, and the persistence layer means three places to update when the contract changes — and three places to forget. Validating once, in a named place,
also gives the contract a file a reader can open to learn exactly what the endpoint accepts.

**Rules:**

- Every entry point that accepts external input has a single named validation surface that owns its full rule set.
- Handlers do not inline validation rules; they receive already-validated, typed input.
- Custom messages live with the rules they belong to — never split rule and message across files.
- Authorization is checked at the same boundary as validation, before any work begins.
- Client-side validation is a convenience only; the server remains authoritative and a rejection from it is the final word.
- {{GEN:name this project's validation surface for {{STACK}} — the request/schema/validator construct, where those types live given {{MODULE_LAYOUT}}, and how validated
  input reaches the handler. Detect and confirm. Include any documented exception the project deliberately allows.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting inline validation rules inside a handler ("Bad") with a dedicated validation surface the handler consumes (
"Good").}}

> Severity for plan review: **WARN**.
