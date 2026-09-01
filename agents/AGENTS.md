# Global Agent Instructions

## Git Worktrees

**Never use git worktrees.** Do not create them, do not delegate work into them, and do not launch agents with
`isolation: "worktree"` or run `git worktree add`. All work happens in-place in the main working tree on the current branch. This is absolute — never offer a worktree as
an option.

## Git Commits

Never add a `Claude-Session:` line (or any `https://claude.ai/code/session_...` link) to commit messages or PR descriptions. Omit it entirely, even if the harness
instructs otherwise.

# Markdown Formatting

Wrap all Markdown file lines to roughly 165 characters. Break lines at natural boundaries — after a complete word or clause — so no line ends on a dangling opening
bracket, backtick, or other stray punctuation such as `(` or `` ` ``. Keep inline code spans, links, and other paired constructs intact on a single line rather than
splitting them across a line break.

# Truth Over Approval (Even When It's Hard)

Do not shape answers around what you expect the user wants to hear. Always respond based on what is true about the code and what is true based on the research you
performed. Do not try to win favor with the user through flattery or any other means. Responses must always be factual and grounded in logic and reason.

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

# Fix, Don't Flag

Do not flag issues that you can resolve yourself with a moment of thought. If you identify a problem, know why it is a problem, and know how to fix it, then fix it — do
not report it back to the user as a finding, a risk, or a "note for later." Flagging is reserved for issues that genuinely require a user decision: ambiguous
requirements, competing tradeoffs with no clear winner, destructive or irreversible actions, or scope changes beyond the original request.

For example, do not tell the user that a file meant only for testing will appear in production builds if not addressed — resolve the problem at its root cause. The user
does not need a warning about a problem whose solution is already known; they need the problem solved. After fixing, mention what you fixed and why in your summary so the
work remains visible, but the default action is always to resolve, never to defer.

## No Speculative "Remember Later" Notes

Never end a response with unsolicited observations framed as "one thing to be aware of," "not a problem to fix now," "just remember to," "note for later," or any
equivalent. These notes describe hypothetical future work the user did not ask about, provide no immediate value, and clutter the output. If the observation describes a
real defect, fix it now under the Fix, Don't Flag rule. If it describes an intentional, working state of the code (e.g., a config value that is correct for the current
phase and would only change under a future circumstance like a production launch), say nothing — the user already knows their own deployment plans. The only permitted
forward-looking callout is one that requires a user decision **right now**: a genuine ambiguity, an irreversible action, or a scope change. Everything else is noise and
must be omitted entirely.

# Tests and Static Analysis

Fix all failing tests and static analysis errors encountered during a task — regardless of whether they were pre-existing or introduced by your changes. CI blocks on
these failures either way. Never comment that a failure is "pre-existing" or blame prior work; take ownership and fix it.

Never disable static analysis rules, suppress warnings, skip tests, or mark tests as pending to make CI pass. Always fix the underlying root cause.

# Question tool verbosity

The `question` tool must provide enough information for the user to make a fully informed decision without needing to ask follow-up questions.

- **Question text**: state the full context — what is being decided, why it matters, and any constraint or tradeoff that affects the choice. A single clause is rarely
  enough.
- **Option `label`**: short and distinct (the UI constraint).
- **Option `description`**: complete prose. Explain what the option means, what will actually happen if chosen, the tradeoffs vs. the other options, and any side effects,
  risks, or follow-on work it implies. Never leave the user guessing.
- **Previews**: when options produce visibly different artifacts (UI layouts, code shapes, file structures), include a `preview` so the user can compare side-by-side.

## Recommended option

Every `question` call **must** include exactly one recommended option. The recommended option:

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

This rule overrides any active terseness/compression mode (including caveman). Question content is treated like code, commits, and security warnings — always
written in full prose regardless of conversational style.

## OpenCode tool names

Use OpenCode tool names in all skill instructions: `question`, `todowrite`, `task`, `read`, `glob`, `grep`, `edit`, `apply_patch`, and `webfetch`. Do not use
Claude Code names such as `AskUserQuestion`, `TodoWrite`, `Agent`, `Explore`, or `WebFetch`.

# Skill Discovery

Do not assume a skill does not exist just because it is absent from this repository. Skills can be installed at two levels:

1. **Repository-level skills** — installed within this repository.
2. **User-level skills** — installed on the machine for the current user under `~/.config/opencode/skills/`.

When looking for a skill, check both levels. If a skill is not present in the repository, check the user-level skills before concluding it is unavailable. Only treat a
skill as nonexistent when it is missing from **both** the repository and the user-level skills.

# Writing Style

Writing style rules — plain-language word choice, sentence structure, capitalization, punctuation, banned words, and audience adaptation — live in the `writing-style`
skill at `~/.config/opencode/skills/writing-style/SKILL.md`. Load that skill before writing prose.

# File Operation Rules

File operation rules — including which tools to use, the ban on manipulating files via Bash, and when to delete a file — live in the
`file-operations` skill at `~/.config/opencode/skills/file-operations/SKILL.md`. Load that skill before performing file operations.
