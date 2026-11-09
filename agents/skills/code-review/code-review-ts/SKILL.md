---
name: code-review-ts
description: TypeScript code review extending the base code-review skill. Checks for breaking changes, type safety, test coverage, and TypeScript, Node.js, React, and Next.js patterns. Outputs AI agent prompts by default; use `--full` for a complete actionable report with per-file grouping, two severity tiers, and inline diffs.
---

# TypeScript code review (extends code-review)

This skill extends the base `code-review` skill with TypeScript-specific rules.

**Before doing anything else**, read the base skill:

```
~/.agents/skills/code-review/SKILL.md
```

Follow every step defined there, applying the overrides below in the matching steps. Where a section is marked **Extension point** in the base skill, replace it entirely
with the TypeScript-specific version below.

---

## Override: Step 2 — File filter

Filter for TypeScript files only:

```bash
git diff --name-only origin/main...HEAD | grep -E '\.(ts|tsx|mts|cts)$'
```

If no TypeScript files changed, inform the user and exit gracefully.

---

## Override: Step 3 — Detect available tools

Check `package.json` and the lockfile to identify the package manager. Use its executable runner: `bunx` for Bun, `pnpm exec` for pnpm, `yarn` for Yarn, or `npx` for npm.

Check `package.json` for these development tools and scripts:

- `typescript` or a `typecheck` script for type checking
- `eslint` or a `lint` script for linting
- `biome` or a `check` script for linting and formatting
- `vitest`, `jest`, `@jest/core`, or a `test` script for tests

Also check for these configuration files when their matching dependency or script is present:

```
tsconfig.json
eslint.config.*
.eslintrc.*
biome.json
vitest.config.*
vite.config.*
jest.config.*
```

Record the available commands and their package-manager runner. Prefer explicit scripts over guessed direct tool invocations. If both Vitest and Jest are present,
prefer the runner named by the `test` script. Otherwise, prefer Vitest.

---

## Override: Step 4 — Permission prompts

If tools are found, ask the user:

- If TypeScript or a `typecheck` script is found: "Type checking is available. Run it for the changed TypeScript project?"
- If ESLint, Biome, or a `lint` script is found: "Linting is available. Run it on changed TypeScript files?"
- If Vitest, Jest, or a `test` script is found: "Tests are available. Run the tests that cover changed TypeScript files?"

Use `question`. If denied, continue with manual review only.

---

## Override: Step 5B — Framework-specific breaking changes

Read `package.json` to detect the framework and runtime.

**Public TypeScript API changes:**

- Removed or renamed exports, including barrel exports
- Changed exported function, class constructor, hook, component, or callback signatures
- Narrowed exported parameter types or widened required return values
- Changed exported discriminated unions, enums, or object property requirements
- Changed behavior of default exports or CommonJS/ESM module boundaries

**Node.js services and libraries:**

- Removed or changed HTTP routes, request parameters, response shapes, status codes, or error contracts
- Changed event names, event payloads, queue message shapes, or serialized data consumed outside the process
- Removed environment variables or changed their expected types or semantics
- Changed middleware order, authentication, authorization, rate limits, or error handling

**React and Next.js applications:**

- Removed or renamed public routes, route segments, API routes, server actions, or page exports
- Changed component props used by consumers without a compatible default or migration path
- Changed server/client component boundaries that invalidate supported consumers or move server-only code to the client
- Changed data-fetching cache, revalidation, or rendering behavior that callers depend on

Flag any of the above as **Actionable**.

---

## Override: Step 5D — Framework pattern review

**TypeScript:**

- New `any`, unsafe type assertions, or `@ts-ignore` / `@ts-nocheck` directives that hide real type errors
- Non-null assertions (`!`) without a local invariant that proves the value exists
- Type-only imports used as runtime values, or value imports used only as types when project settings require type-only imports
- Runtime validation missing at untrusted boundaries, including HTTP input, environment variables, file input, and parsed JSON
- Mutable exported objects or module-level state that leaks between requests or tests

**Node.js:**

- Blocking filesystem, cryptography, compression, or child-process work on request or event-loop paths
- Promises started without awaiting, returning, or handling rejection
- Event listeners, streams, timers, or abort listeners that are not cleaned up when their owner ends
- Unbounded concurrency, unbounded input sizes, or unbounded in-memory collections on request paths
- Unsafe shell command construction, path traversal, SSRF, or secrets written to logs

**React:**

- Side effects during render, derived state stored in effects, or effects missing cleanup or complete dependency lists
- Unstable props, callbacks, or context values that cause avoidable subtree re-renders when a stable alternative is already available
- Lists with unstable or index keys where items can reorder, insert, or delete
- Missing loading, empty, or error states for asynchronous UI
- Direct DOM access or browser APIs in components that can render on the server

**Next.js:**

- Client components importing server-only modules, secrets, database clients, or Node.js-only APIs
- Server components importing browser-only APIs without a client boundary
- Sequential data fetching that can run concurrently, unnecessary client-side fetching for server-rendered data, or cache settings that conflict with the data's required
  freshness
- Dynamic route parameters, search parameters, or server action input used without validation or authorization

Flag as **Nitpick** unless the pattern causes a direct correctness, performance, or security issue, in which case flag as **Actionable**.

---

## Override: Step 5E — Test coverage analysis

For each changed TypeScript file, check whether a corresponding test file exists.

**Test file locations to check:**

For `src/services/user-service.ts`, look for:

- `src/services/user-service.test.ts`
- `src/services/user-service.spec.ts`
- `tests/services/user-service.test.ts`
- `tests/services/user-service.spec.ts`
- `__tests__/services/user-service.test.ts`
- `__tests__/services/user-service.spec.ts`

For `src/components/UserCard.tsx`, also look for:

- `src/components/UserCard.test.tsx`
- `src/components/UserCard.spec.tsx`
- `src/components/__tests__/UserCard.test.tsx`
- `src/components/__tests__/UserCard.spec.tsx`

**Files that don't need tests (exclude from test coverage findings):**

- Build and tool configuration (`*.config.*`, `vite.config.*`, `next.config.*`)
- Type declarations (`*.d.ts`)
- Framework route wiring without business logic
- Generated files and generated API clients
- Static constants, locale data, and barrel-only export files

**Flag as Nitpick:**

- New files without any corresponding test file, except excluded files
- Modified files where the test file wasn't also updated (check git diff for the test file)

---

## Override: Step 6 — Run static analysis (if approved)

If the user approved type checking, run the project's explicit `typecheck` script. If none exists and TypeScript is installed, run:

```bash
<package-manager-runner> tsc --noEmit --pretty false
```

If the user approved linting, run the project's explicit `lint` script when it accepts file paths. Otherwise, run the detected linter only on changed TypeScript files:

```bash
<package-manager-runner> eslint path/to/File1.ts path/to/File2.tsx
<package-manager-runner> biome check path/to/File1.ts path/to/File2.tsx
```

Parse the output. Classify TypeScript errors, lint errors, and directly relevant warnings as Actionable or Nitpick, then add them to the findings collection. Clearly
note whether an issue came from a changed file or the broader codebase.

---

## Override: Step 7 — Run tests (if approved)

If the user approved test execution, run only the tests corresponding to changed TypeScript files, not the entire test suite.

```bash
# Vitest
<package-manager-runner> vitest run src/services/user-service.test.ts src/components/UserCard.test.tsx

# Jest
<package-manager-runner> jest src/services/user-service.test.ts src/components/UserCard.test.tsx --runInBand
```

Use the project's explicit test script if it accepts test paths. Otherwise, invoke the detected runner directly. If no test files exist for changed code, skip execution
and
add a Nitpick finding per non-excluded source file.

---

## Additional edge cases (TypeScript-specific)

- **Monorepos**: Find the nearest `package.json` and `tsconfig.json` for each changed file. Run tools from the owning package, not the repository root.
- **Generated code**: Skip generated files such as `*.generated.ts`, `*.gen.ts`, and files in generated-client directories unless the change updates generated output
  incorrectly.
- **Declaration merging and module augmentation**: Read all related declaration files before reporting a missing or incompatible type.
- **No TypeScript files changed**: Inform the user and exit gracefully.

---

**Begin your review now. Follow the base skill steps with the overrides above applied.**
