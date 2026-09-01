# The Review Loop and Severity

How every planning skill runs its interactive review: how questions are batched and asked, how the file is iterated until clean, and what BLOCK vs WARN means. Follow this
wherever a skill analyzes an artifact against lenses and resolves the findings with the user.

---

## Severity — BLOCK vs WARN

Every finding a lens raises carries a severity:

- **BLOCK** — a genuine show-stopper. It must be resolved before the artifact is finalized; no plan, northstar, or review is called done while a BLOCK finding is open.
  Fix it in the file, or if it genuinely cannot be met, surface it to the user before proceeding.
- **WARN** — a flag for human review. Either fix it or record it as acknowledged, then proceed.

Two classes of finding are **always blockers**, outranking everything else: a violation of `$PROJECT_STANDARDS` (see
[`paths.md`](paths.md)) and a violation of the delivery constraints (`~/.config/opencode/skills/delivery-constraints/SKILL.md`).

**Northstar severity.** When `$NORTHSTAR` is set, each Guiding Principle carries its own `> BLOCK if …` / `> WARN if …` annotation — the northstar file is the
authoritative source of those checks; do not invent checks it does not state. When `$NORTHSTAR = null`, skip every northstar check silently.

---

## Question — batching and ranking

- **At most 4 questions per call.** The tool accepts no more.
- **Rank by blast radius** when more than 4 findings need user input, and ask the top 4 first: standards/policy and delivery-constraint blockers → contradictions →
  missing information → ambiguity → scope/completeness.
- **Consolidate** tightly-related findings into a single question.
- **Defer the overflow** to the next round — but only after writing the current round's resolved answers back to disk.
- **Never invent answers.** If intent is unclear, ask; do not assume. Do not ask about anything the artifact, the code, or the discovered conventions already settle.

### Standard question format

```
**<Skill> review: round N**

I found the following gaps. Please answer each one so I can update the <artifact>.

---

**[Lens label — short title]**

> *Quoted or paraphrased text from the artifact*

❓ Your question.

---

*(repeat per question group)*
```

### Compact one-line variant

When a round is dense with small, mechanical findings, a one-line-per-finding form is clearer than the block form above:

```
**[Lens]** "quoted text" — current: path:LINE — Q: <closed-ended question>
```

Use a multi-line block only for a finding that needs a code snippet or multi-field context.

---

## Iterate until clean

After each round of answers:

1. **Write the answers into the file immediately** with `Edit` (or `Write` when a full rewrite is cleaner). Integrate each answer into the relevant section — never append
   a raw Q&A block. Rewrite sentences to be declarative and unambiguous. When an answer describes *how*
   code should be implemented, express it as a code example, not prose.
2. **Re-read** the updated file.
3. **Run every lens again** on the updated content — resolving obvious issues often surfaces new ones.
4. If findings remain, compile the next round and repeat. If none remain, proceed to the skill's final-confirmation step.

**Always write the updated file to disk before calling `question` again.** After every round the file must be a standalone, self-contained document.
