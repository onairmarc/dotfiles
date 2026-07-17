---
name: file-operations
description: Canonical file operation rules shared across all skills. Read this file at the start of any skill that performs file operations.
---

# File Operation Rules

Use the dedicated file tools for all file operations:

- **Read** to read files
- **Edit** to modify existing files
- **Write** to create new files
- **Grep** / **Glob** for discovery only
- **Bash `rm`** to delete files — always confirm with the user before deleting

Never manipulate files via Bash (`echo >`, `cat <<EOF`, `sed -i`, `awk -i`, `tee`, redirection, etc.). Edit and Write are the only approved methods of file editing. `rm`
is the only approved method of file deletion.

## When to Delete a File

Only delete a file when a refactor calls for it — for example, when the file has become functionally empty and no longer serves a purpose.
In that case, deletion is mandatory: delete the file rather than leaving a comment explaining why it is now empty and was not removed.
Do not delete files for any other reason without explicit user direction.
