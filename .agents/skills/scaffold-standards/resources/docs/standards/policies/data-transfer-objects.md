# Data Transfer Objects

Data crossing a serialization boundary travels as an explicitly declared transfer object whose shape is a plain list of typed fields — not a promoted-and-assigned
constructor, and not a loosely-keyed map.

For in-process work — including calls between modules — the framework's own primitives are the right currency: wrapping an in-process call in a transfer object adds a
translation layer with no reader benefit, because the caller and callee share one process and one deployment. At a serialization boundary the calculation flips: the
payload outlives the call, the consumer cannot be redeployed in lockstep, and a renamed field becomes a wire-format change. A transfer object is the written-down contract
for exactly those crossings, and it reads best when it is *only* the field list. A constructor that exists solely to promote and assign parameters is a second enumeration
of every field in a fixed positional order, which makes adding or reordering a field noisier than it should be.

**Rules:**

- Use the framework's native types for in-process work, including calls across a module boundary. Introduce a transfer object where the data leaves the process or must
  survive serialization: API request and response shapes, queued messages and queued event payloads, and external integration clients.
- Do not introduce a transfer object for an in-process call merely because it crosses a module boundary — see
  [Module Isolation](./module-isolation.md#exported-contracts-boundary-types).
- A transfer object's shape is its list of public typed fields. Do not write a constructor whose body only assigns its own parameters to fields.
- Keep or add a constructor **only** when its body does real work — normalization, derived defaults, invariant checks.
- Never widen a transfer object to a loosely-keyed map at the boundary — see [Strong Typing](./strong-typing.md).
- {{GEN:name the construct this project uses for transfer objects in {{PRIMARY_LANGUAGE}} (record, struct, data class, DTO library type), where those types live given
  {{MODULE_LAYOUT}}, and any serialization contract they must satisfy. Detect and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a boilerplate promote-and-assign constructor ("Bad") with a declarative typed field list ("Good"), plus a second
"Good" case where a constructor is justified because its body normalizes a value.}}

> Severity for plan review: **WARN**.
