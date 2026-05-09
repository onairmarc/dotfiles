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

## File Operation Rules

Use the dedicated file tools for all file operations:

- **Read** to read files
- **Edit** to modify existing files
- **Write** to create new files
- **Grep** / **Glob** for discovery only

Never manipulate files via Bash (`echo >`, `cat <<EOF`, `sed -i`, `awk -i`, `tee`, redirection, etc.). Edit and Write are the only approved methods of file editing.
