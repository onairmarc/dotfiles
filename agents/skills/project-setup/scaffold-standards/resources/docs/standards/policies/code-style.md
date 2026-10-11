# Code Style

Formatting is owned by the formatter and style linter (`{{FORMAT_COMMAND}}`), not by hand — they decide whitespace, import order, and line breaks.

Hand-maintained formatting produces diffs that hide intent, review comments that argue about whitespace, and per-directory style drift. One tool with one configuration
file settles every one of those arguments in advance. What the formatter cannot decide — how long a function may get, whether a guard clause comes first, what belongs in
a file header — is stated below so it is a rule rather than a reviewer's preference.

**Rules:**

- Style is governed by the project-level formatter configuration. Do not introduce per-module or per-directory style overrides.
- `{{FORMAT_COMMAND}}` — the formatter and style linter — **runs in CI only**. Do not run it locally, and coding agents must never run it in any mode, including
  `--check`/`--dry-run`; see [Formatter Authority](./formatter-authority.md). Write the code plainly and let the CI pass settle the formatting. This says nothing about
  `{{STATIC_ANALYSIS_COMMAND}}`, which agents are required to run.
- Match the surrounding code: naming, comment density, and idiom. A change should be indistinguishable in style from the code around it.
- Hand-formatted whitespace tweaks in a pull request are noise; let the formatter resolve them.
- {{GEN:the project's hard style rules that the formatter does NOT enforce — e.g. maximum function length, guard-clause-first style, file-header requirements, import
  grouping the formatter leaves alone. Author from {{PRIMARY_LANGUAGE}} conventions; ask the user for anything genuinely discretionary.}}
- {{GEN:name the formatter and its configuration file, detected from the repo tooling config.}}

## React JSX input formatting

`tsfmt` remains the final authority for TypeScript and TSX output. Authors must still format JSX input to make the rendered tree clear before `tsfmt` runs. Readable input
lets a human review nested forms, callbacks, conditions, and mapped children without reconstructing their structure from a dense line of code.

**Rules:**

- Put a JSX element with several props or children across lines, with one prop per line and child nodes indented beneath the opening tag.
- Put a render callback on its own indented line. When it returns a JSX element, put that element and its children on their own lines rather than compressing them into the
  callback expression.
- Put conditional and mapped child expressions on their own lines. Indent the callback body and multiline child element beneath the expression.
- Keep a simple one-line element only when it has no nested children and remains easy to read. Do not manually run `tsfmt`, Prettier, ESLint, or any other style tool.

```tsx
<form.Field name="contactMethod">
    {(field) =>
        <TextField
            select
            label="Contact method"
            value={field.state.value ?? ""}
            error={fieldError(field.state.meta.errors) !== undefined}
            helperText={fieldError(field.state.meta.errors)}
            onBlur={field.handleBlur}
            onChange={
                (event) => field.handleChange(event.target.value === ""
                    ? undefined
                    : event.target.value)
            }
        >
            <MenuItem value="">Choose a contact method</MenuItem>
            {
                contactMethods.map((method) =>
                    <MenuItem key={method.value} value={method.value}>
                        {method.label}
                    </MenuItem>)
            }
        </TextField>
    }
</form.Field>
```

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a hand-formatted, intent-obscuring version ("Bad") with the same code written plainly and left to the formatter (
"Good").}}

> Severity for plan review: **BLOCK**.
