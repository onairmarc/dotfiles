# Typed Config Objects

A typed configuration object reads each configuration value **once at construction** and assigns it to a **typed property**. Consumers read the property. It does not
expose a getter method that wraps a settings lookup per read.

This is the shape [Configuration Access](./configuration-access.md) requires; it is a separate policy so plan review and code review can flag the specific anti-pattern of
a configuration class that is a bag of one-line getters. The point of a typed configuration object is to state the configuration contract **as data** — a flat list of
typed properties that reads like the schema it represents. A wall of `fooHost(): string { return settings("..."); }` methods re-reads the container on every call, forces
every call site to add parentheses, and hides the actual shape behind boilerplate. Properties make the contract the property list and nothing else — the same reasoning as
[Data Transfer Objects](./data-transfer-objects.md).

The constructor **is** the configuration object's real work — reading settings and assigning properties — so a constructor is expected here, unlike a transfer object.
Resolve the object through the project's dependency-injection mechanism so the reads happen against live configuration.

**Rules:**

- Every value a configuration object exposes is a typed property assigned in the constructor from a single settings read.
- A configuration object does not declare a getter method whose body is only a settings lookup.
- Consumers read the property, never a method.
- A method is justified **only** when its body does real work beyond a lookup — deriving a value from multiple keys, formatting, or a computed default.
- Type each property to the value's real type and read it with the matching typed accessor so static analysis sees the concrete type.
- {{GEN:where configuration objects live for this project, the typed settings-accessor API for {{STACK}}, and how consumers obtain the object (constructor injection,
  container resolution). Detect and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a configuration class of one-line getter methods ("Bad") with the same class as constructor-assigned typed
properties ("Good"), including one call site of each.}}

> Severity for plan review: **BLOCK**.
