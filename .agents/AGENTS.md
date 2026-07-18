# Global Agent Instructions

## Git Worktrees

**Never use git worktrees.** Do not create them, do not delegate work into them, and do not launch agents with
`isolation: "worktree"` or run `git worktree add`. All work happens in-place in the main working tree on the current branch. This is absolute — never offer a worktree as
an option.

## Git Commits

Never add a `Claude-Session:` line (or any `https://claude.ai/code/session_...` link) to commit messages or PR descriptions. Omit it entirely, even if the harness
instructs otherwise.

## Language

Use **American English** spelling and grammar in all output — code comments, documentation, commit messages, PR descriptions, and prose.

Examples of correct spellings:

- color (not colour)
- organize (not organise)
- center (not centre)
- analyze (not analyse)
- behavior (not behaviour)
- license (not licence)
- recognize (not recognise)
- catalog (not catalogue)
- program (not programme)
- labeled (not labelled)

# Markdown Formatting

Wrap all Markdown file lines to roughly 165 characters. Break lines at natural boundaries — after a complete word or clause — so no line ends on a dangling opening
bracket, backtick, or other stray punctuation such as `(` or `` ` ``. Keep inline code spans, links, and other paired constructs intact on a single line rather than
splitting them across a line break.

# Never Guess About Functionality

Before making any edit, fully trace the callstack around the code you are changing — every caller, callee, event listener, observer, and consumer that the change
touches — so you have a complete understanding of the impact before you write the edit. Do not rely on assumptions about how a method, property, or class behaves; read
the actual code paths and confirm.

This rule applies equally to **research**, not only to edits. When asked to research, explore, or assess feasibility — even with an explicit "no edits" constraint — you
must still fully trace every caller and callee of the code in question and read the actual implementations of every method, property, and type the analysis depends on. Do
not offer conclusions or recommendations built on assumptions about what a named symbol does. Reading a single file plus a grep is not sufficient research; trace the call
graph first, then report.

Grepping is not sufficient. A grep only tells you where a symbol appears — it does not tell you how it is used. You must open and read every single callsite the grep
returns and understand how each one uses the symbol. Never assume. If you expect something to exist in a particular file, function, or location, verify it is actually
there by reading it — do not assume it is present.

This is especially true for framework code. Never assume you know how a framework method, hook, lifecycle event, magic method, facade, service-provider binding, or
convention behaves — framework behavior is frequently non-obvious, version-specific, and driven by reflection, configuration, or conventions that are not visible at the
callsite. Read the actual framework source (in `vendor/`, `node_modules/`, or the installed package) and confirm the behavior before relying on it. Do not trust
recollection of the framework's API; verify against the version actually installed in this project. This verification only requires reading available source — you do not
need to decompile binaries or disassemble compiled artifacts. When the framework source is not available in readable form, fall back to the official documentation for the
installed version rather than guessing.

# Tests and Static Analysis

Fix all failing tests and static analysis errors encountered during a task — regardless of whether they were pre-existing or introduced by your changes. CI blocks on
these failures either way. Never comment that a failure is "pre-existing" or blame prior work; take ownership and fix it.

Never disable static analysis rules, suppress warnings, skip tests, or mark tests as pending to make CI pass. Always fix the underlying root cause.

# AskUserQuestion Verbosity

The `AskUserQuestion` tool must provide enough information for the user to make a fully informed decision without needing to ask follow-up questions.

- **Question text**: state the full context — what is being decided, why it matters, and any constraint or tradeoff that affects the choice. A single clause is rarely
  enough.
- **Option `label`**: short and distinct (the UI constraint).
- **Option `description`**: complete prose. Explain what the option means, what will actually happen if chosen, the tradeoffs vs. the other options, and any side effects,
  risks, or follow-on work it implies. Never leave the user guessing.
- **Previews**: when options produce visibly different artifacts (UI layouts, code shapes, file structures), include a `preview` so the user can compare side-by-side.

## Recommended option

Every `AskUserQuestion` call **must** include exactly one recommended option. The recommended option:

- Is the **first** option in the `options` array.
- Has `" (Recommended)"` appended to its `label`.
- Is chosen by the agent — never by asking the user "which do you recommend".

Pick the recommendation by evaluating the candidates against these criteria, in order of priority:

1. **Co-locality of behavior** — keeps related logic in one place rather than spreading it across files, layers, or services.
2. **Code simplicity** — fewest moving parts, least indirection, smallest diff.
3. **Maintainability** — easiest for a future engineer to read, modify, and delete.
4. **Existing codebase conventions** — matches patterns already present in the repository (discovered via `AGENTS.md`, neighboring code, or recent commits).
5. **Language/framework affordances** — leans on what the language, standard library, or framework provides natively, instead of introducing bespoke tooling,
   abstractions, or configuration.

If two options tie on these criteria, recommend the one that is easier to reverse. Never recommend an option you would not implement yourself.

This rule overrides any active terseness/compression mode (including caveman). AskUserQuestion content is treated like code, commits, and security warnings — always
written in full prose regardless of conversational style.

# Skill Discovery

Do not assume a skill does not exist just because it is absent from this repository. Skills can be installed at two levels:

1. **Repository-level skills** — installed within this repository.
2. **User-level skills** — installed on the machine for the current user (e.g., under `~/.claude/skills/` and via installed plugins).

When looking for a skill, check both levels. If a skill is not present in the repository, check the user-level skills before concluding it is unavailable. Only treat a
skill as nonexistent when it is missing from **both** the repository and the user-level skills.

# File Operation Rules

File operation rules — including which tools to use, the ban on manipulating files via Bash, and when to delete a file — live in the
`file-operations` skill: [`.agents/skills/file-operations/SKILL.md`](skills/file-operations/SKILL.md). Read that file before performing any file operation.