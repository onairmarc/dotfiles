# Configuration Access

Environment variables are read only at the configuration layer; application code reads configuration through typed configuration objects, never by pulling a key out of
the environment or a global settings bag at the call site.

A settings lookup scattered through business logic gives no type safety, no completion, no single place to override during tests, and no way to answer "what configuration
does this system actually take?" without grepping. A typed configuration object states the contract once and every consumer reads the same contract. Keeping environment
reads at the configuration layer also means the defaults live in exactly one file — the file a newcomer can read to learn what the system needs to boot.

**Rules:**

- Environment variables are read only in the project's configuration layer. Application code, modules, and tests do not read the environment directly.
- Inside the configuration layer, every environment read has a sensible default — the default is what runs when the variable is unset.
- Application code reads configuration through typed configuration objects — see [Typed Config Objects](./typed-config-objects.md) for the required shape.
- Do not sprinkle string-keyed settings lookups through business code; expose the value as a typed property on a configuration object.
- Secrets are never defaulted to a real value and never logged — see [Structured Logging](./structured-logging.md).
- {{GEN:name this project's configuration layer (the directory/files where environment reads are allowed), the environment-read API, and where typed configuration objects
  live given {{MODULE_LAYOUT}}. Detect and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a raw settings lookup inside business logic ("Bad") with the same value read from an injected typed configuration
object ("Good").}}

> Severity for plan review: **BLOCK**.
