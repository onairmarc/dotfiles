# Version Control

Work happens on a branch off `{{DEFAULT_BRANCH}}`, in focused commits whose messages explain the *why*.

The commit log is the only record of intent that survives after the author forgets and the pull request is archived. A commit that says what the diff already shows adds
nothing; one that says why the change was necessary saves the next reader an hour of archaeology. Focused commits also make the tools work: a bisect over ten
mixed-concern commits tells you almost nothing.

**Rules:**

- Never commit directly to `{{DEFAULT_BRANCH}}`; branch, then open a pull request.
- One concern per commit. Formatting sweeps and behavioral changes do not share a commit.
- The message states the *why*, not a restatement of the diff.
- Do not commit generated artifacts, credentials, or local environment files.
- {{GEN:the branching model, commit-message convention, and required pull-request checks for this project. Detect from CI and any pull-request template; ask the user for
  the convention if it is unclear.}}

> Severity for plan review: **WARN**.
