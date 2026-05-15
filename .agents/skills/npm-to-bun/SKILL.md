---
name: npm-to-bun
description: Converts a repository from npm (or yarn) to bun as the package manager. Audits all affected files, applies changes, runs bun install, and verifies the build still works. Does NOT change build tool configuration beyond what is required to invoke the existing build tooling via bun.
argument-hint: [ root-path ]
---

You are converting a JavaScript/TypeScript repository from npm (or yarn) to bun as its package manager. Your job is
narrowly scoped: swap the package manager, not the build tooling. Vite configs, tsconfig files, and other build tool
configuration stay untouched unless they contain `npm`/`npx`/`yarn` invocations that must be updated to keep the build
working.

---

## Inputs

If `$ARGUMENTS` is provided, treat it as the root path of the repository to convert and set `$ROOT` to that path.
Otherwise set `$ROOT` to the current working directory.

---

## Step 0 — Discover the repository layout

Before making any changes, build a picture of what needs to change.

Run these discovery steps in parallel:

1. Check for a `package.json` at `$ROOT`. If absent, stop and tell the user this does not look like a Node.js repo.
2. Check which lockfile exists at `$ROOT`: `package-lock.json`, `yarn.lock`, or `bun.lock`. Report the finding.
3. Glob for every file that may reference `npm` or `yarn` commands, scoped to `$ROOT`:
    - `$ROOT/**/.gitignore`
    - `$ROOT/**/.npmrc`
    - `$ROOT/**/package.json` (all, not just root)
    - `$ROOT/**/*.sh`
    - `$ROOT/**/*.yml` and `$ROOT/**/*.yaml` (CI files — discovered but not modified; see Step 1e)
    - `$ROOT/**/CLAUDE.md`, `$ROOT/**/AGENTS.md`, `$ROOT/**/README.md`
    - Any TypeScript/JavaScript source files under `$ROOT` that call `execa`, `spawn`, or `exec` with `"npm"`,
      `"npx"`, `"yarn"`, `"node"` (when used to run a `.js` file that could be run with `bun`), or `"tsx"` as the
      executable
4. Check if `$ROOT/.gitlab-ci.yml` or files under `$ROOT/.gitlab/ci/` exist — note them in the summary but do not
   modify them.

Present a summary of what was found before proceeding.

---

## Step 1 — Apply changes

Apply all changes below. Run independent file edits in parallel where possible.

### 1a — package.json (root and any workspace packages)

For each `package.json` found:

| What to find                              | What to replace with                             |
|-------------------------------------------|--------------------------------------------------|
| `"engines": { "node": "..." }`            | `"engines": { "bun": ">=1.2.0" }`                |
| `"packageManager": "npm@..."`             | `"packageManager": "bun@1.2"`                    |
| `"npm"` in `devDependencies`              | Remove the entry entirely                        |
| `"tsx"` in `devDependencies`              | Remove the entry (bun runs `.ts` files natively) |
| `"node": "..."` in `devDependencies`      | Remove if it is there as an explicit dep         |
| Script commands using `npm run X`         | `bun run X`                                      |
| Script commands using `npm ci`            | `bun install --frozen-lockfile`                  |
| Script commands using `npm install`       | `bun install`                                    |
| Script commands using `npx X`             | `bunx X`                                         |
| Script commands using `tsx src/file.ts`   | `bun src/file.ts`                                |
| Script commands using `node bin/file.mjs` | `bun bin/file.mjs`                               |
| Script commands using `yarn X`            | `bun X` (or `bun run X` for script names)        |

If `@types/bun` is absent from `devDependencies` AND the repo contains TypeScript source files, add it:
`"@types/bun": "latest"`.

For `exports` fields: if there are `"import"` or `"require"` keys pointing to built `dist/` output, and the repo also
has a `"bun"` export condition, leave it. If the repo is a library that ships source directly (not a dist), add a
`"bun"` export condition pointing to the source entry alongside `"import"`.

### 1b — Lock files

- Delete `package-lock.json` if it exists.
- Delete `yarn.lock` if it exists.
- Do NOT create `bun.lock` manually — it is generated in Step 2.

### 1c — .gitignore

For each `.gitignore` found:

| What to find        | What to replace with                                     |
|---------------------|----------------------------------------------------------|
| `npm-debug.log`     | Remove the line                                          |
| `yarn-error.log`    | Remove the line                                          |
| `yarn-debug.log`    | Remove the line                                          |
| `.npm/`             | Remove or replace with `.bun/`                           |
| `package-lock.json` | Keep or add if not present (it should be gitignored now) |

Add `.bun/` if not already present.

### 1d — .npmrc

Bun reads `.npmrc` natively for scoped registry configuration and `_authToken` entries. In most cases no changes are
needed.

Exception: if `.npmrc` contains an `_authToken` entry that looks like a literal secret (not an environment variable
reference), flag it in the Step 4 report for the user to review. No file edit needed unless the file contains
commented-out `npm config set` commands — remove those comments.

### 1e — CI files

Do NOT modify any CI files (`.gitlab-ci.yml`, files under `.gitlab/ci/`). CI configuration is managed separately —
the user will drop in pre-converted CI scripts themselves.

### 1f — Shell scripts (`.sh` files)

| What to find  | What to replace with            |
|---------------|---------------------------------|
| `npm ci`      | `bun install --frozen-lockfile` |
| `npm install` | `bun install`                   |
| `npm run X`   | `bun run X`                     |
| `npx X`       | `bunx X`                        |
| `yarn X`      | `bun X`                         |

### 1g — TypeScript/JavaScript source files (build tools, runners)

Only change source files that directly invoke package manager commands as a subprocess. Do not touch application logic.

| What to find                                                      | What to replace with            |
|-------------------------------------------------------------------|---------------------------------|
| `execa("npx", [...])`                                             | `execa("bunx", [...])`          |
| `execa("npm", ["run", ...])`                                      | `execa("bun", ["run", ...])`    |
| `execa("tsx", [filePath, ...])`                                   | `execa("bun", [filePath, ...])` |
| `execa("node", [filePath, ...])` where `filePath` is a `.ts` file | `execa("bun", [filePath, ...])` |
| `spawn("npx", ...)`                                               | `spawn("bunx", ...)`            |
| `spawn("npm", ...)`                                               | `spawn("bun", ...)`             |

### 1h — Documentation (CLAUDE.md, AGENTS.md, README.md)

Update any command references in documentation files:

| What to find                                         | What to replace with                            |
|------------------------------------------------------|-------------------------------------------------|
| `npm run X`                                          | `bun run X`                                     |
| `npm install`                                        | `bun install`                                   |
| `npm ci`                                             | `bun install --frozen-lockfile`                 |
| `npx X`                                              | `bunx X`                                        |
| `yarn X`                                             | `bun X`                                         |
| "Package Management: npm"                            | "Package Management: bun"                       |
| "Node.js Version" section referencing `engines.node` | "Bun Version" section referencing `engines.bun` |
| "requires Node.js X.x"                               | "requires Bun >=1.2.0"                          |

---

## Step 2 — Install dependencies

Run `bun install` in the repository root. This generates `bun.lock`.

If the install fails:

- Read the error output carefully.
- If a package is incompatible with bun, note it for the user but do not change the dependency itself.
- If it is an auth error for a private registry, remind the user to set the `BUN_AUTH_TOKEN` environment variable or
  verify `.npmrc` credentials.

---

## Step 3 — Verify the build

Run the build script: `bun run build`.

If the build succeeds, report success.

If the build fails:

- Read the error. Determine if it is caused by the npm→bun change (e.g. a `tsx` invocation that was missed) or a
  pre-existing issue.
- Fix any issues caused by the migration and re-run.
- If the failure is unrelated to the migration, report it to the user without attempting to fix it.

---

## Step 4 — Report

Summarize:

1. Files changed (list each file and what changed).
2. Lock file status (`bun.lock` generated, `package-lock.json` / `yarn.lock` removed).
3. Build result (pass / fail and reason if fail).
4. Any items that need manual follow-up (e.g. private registry auth, publish flow, bun-incompatible packages).

---

## Scope boundaries — do NOT change these

- `vite.config.*`, `tsconfig.json`, `biome.json`, `eslint.config.*`, `rollup.config.*`, `webpack.config.*` — leave
  untouched unless they contain literal `npm`/`npx`/`yarn` subprocess calls.
- Application source code not related to invoking the package manager.
- All CI files (`.gitlab-ci.yml`, `.gitlab/ci/**`) — managed separately by the user.
- `package.json` dependency versions — do not bump versions as part of this migration.
- `bun.lockb` (binary lockfile from older bun versions) — if present, note it but do not convert; bun >=1.1 generates
  `bun.lock` (text format) automatically.

---

## Important guidelines

- **One concern at a time.** This skill migrates the package manager only. If you notice unrelated improvements, note
  them in the final report instead of applying them.
- **Parallel edits.** Apply independent file changes in parallel tool calls.
- **Never guess registry URLs or tokens.** If auth configuration is unclear, flag it in the report rather than
  inventing values.