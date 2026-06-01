# Global Agent Instructions

## Language

Use **American English** spelling and grammar in all output — code comments, documentation, commit messages, PR
descriptions, and prose.

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

This rule overrides any active terseness/compression mode (including caveman). AskUserQuestion content is treated like code, commits, and security warnings — always
written in full prose regardless of conversational style.

# File Operation Rules

Use the dedicated file tools for all file operations:

- **Read** to read files
- **Edit** to modify existing files
- **Write** to create new files
- **Grep** / **Glob** for discovery only
- **Bash `rm`** to delete files — always confirm with the user before deleting

Never manipulate files via Bash (`echo >`, `cat <<EOF`, `sed -i`, `awk -i`, `tee`, redirection, etc.). Edit and Write are the only approved methods of file editing. `rm`
is the only approved method of file deletion.