# Code Comments

Comments explain why something odd is the way it is. They are not documentation, and they do not narrate what the code does.

A later editor reads the names, types, and control flow. If those already say what happens, a comment is noise — and a long class essay is a second docs tree that drifts.
Architecture, design rationale, and how a subsystem works live in docs (see [Documentation](./documentation.md)). A comment stays only when removing it would make a future
editor do the wrong thing.

**Rules:**

- Keep a comment only when the next reader would do the wrong thing without it: a framework quirk, a race, a sentinel, a typed lie, or a constraint the next line does
  not show.
- Comments explain why, never what. If the names and types already say it, delete the comment.
- Do not use comments as documentation. If unique knowledge lives only in a comment, port it to the right doc first, then delete or trim the comment.
- Do not restate the method, class, or property name in a doc comment.
- Do not cite ticket numbers, sub-plans, or phase names in comments. The ticket is not a reason.
- Do not add section banners (`// Public API`, `// ───`).
- {{GEN:language-specific type-annotation comments that stay — e.g. PHPDoc `@var`/`@return`/`@param` types, JSDoc types, C# XML `<param>`/`<returns>` without summary
  prose. Drop prose on those tags. If the language has no such annotations, omit this bullet.}}
- {{GEN:if the language's tooling extracts docs from comments (godoc, rustdoc), a one-line contract on exported symbols is allowed; it still must not narrate the body or
  retell architecture. Otherwise omit this bullet.}}
- Tests do not caption the next assertion. A fixture constraint the assertion cannot show may stay as a short why.

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a restates-name or architecture-essay comment ("Bad") with a one-line why on a non-obvious constraint ("Good"),
plus a type-only annotation if the language has them.}}

> Severity for plan review: **BLOCK**.
