---
name: file-operations
description: Canonical file operation rules shared across all skills. Read this file at the start of any skill that performs file operations.
---

# File Operation Rules

Use the dedicated file tools for all file operations:

- **`read`** to read files
- **`edit`** or **`apply_patch`** to modify existing files
- **`write`** to create new files
- **`grep`** / **`glob`** for discovery only
- **`bash` with `rm`** to delete files — always confirm with the user before deleting

Never manipulate files via `bash` (`echo >`, `cat <<EOF`, `sed -i`, `awk -i`, `tee`, redirection, etc.). `edit`, `apply_patch`, and `write` are the only approved
methods of file editing. `rm` is the only approved method of file deletion.

Keep every file-editing tool call small and focused. Large patch preparation and large patch calls can take too long, trigger timeouts, and interfere with
`todotracker` enforcement. A timeout in this situation is not a permission or harness block.

After a timeout or required `todotracker` update, do not retry the same large operation. Break it into smaller, progressive edits, complete one focused change per tool
call, and continue from the updated file state. Treat edits as related only when each is necessary for the same indivisible behavior change, such as its implementation
and direct test. If an edit can be applied, reviewed, or verified independently, it is unrelated and must use a separate tool call. When in doubt, split the calls.

## When to Copy or Move Files

If the task at hand is purely file organization, you may run the platform native copy or move command.

## When to Delete a File

Only delete a file when a refactor calls for it — for example, when the file has become functionally empty and no longer serves a purpose. In that case, deletion is
mandatory: delete the file rather than leaving a comment explaining why it is now empty and was not removed. Do not delete files for any other reason without explicit
user direction.
