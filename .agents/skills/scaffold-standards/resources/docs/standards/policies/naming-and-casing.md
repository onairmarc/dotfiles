# Naming and Casing

Names describe intent, and every identifier kind has exactly one casing — fixed here so no reviewer has to ask twice.

Casing inconsistency is the canonical "death by a thousand cuts" review nit. Pinning the rule once means every reviewer asks the same question and every coding agent
generates code that already matches. The rule is opinionated on purpose and applies even where the language's own style guide would let either form pass. Naming itself is
the other half: a name that describes the mechanism (`counter2`, `dataList`) forces the reader to reconstruct the intent the author already knew.

**Rules:**

- Names describe intent, not mechanism. `retryBudget`, not `counter2`.
- No abbreviations a newcomer would have to decode, except ones defined in the [glossary](../glossary.md).
- A name that needs a comment to explain what it holds is the wrong name; rename rather than annotate.
- {{GEN:the concrete casing rules for {{PRIMARY_LANGUAGE}}, one bullet per identifier kind — local variables, functions/methods, types/classes, constants, enum members,
  files, and directories — each with a real example in the language's idiom. Author from the language's conventions and confirm with the user, since projects often fix a
  choice the language leaves open.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting mechanism-named, inconsistently-cased identifiers ("Bad") with intent-named identifiers following the casing rules
above ("Good").}}

> Severity for plan review: **BLOCK**.
