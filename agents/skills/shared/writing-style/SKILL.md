---
name: writing-style
description: >-
    Plain-language writing rules based on the Microsoft Style Guide. Covers word choice, sentence structure, capitalization, punctuation,
    audience adaptation, and a banned-words list. Applies to ALL prose output — documentation, commit messages, PR descriptions, code
    comments, plan files, skill files, and conversational responses. Read this skill before writing any prose. Other skills that produce
    prose (user-docs, dev-docs, feature-planning, plan-split, codebase-audit, change-audit) should read and follow this skill.
---

# Writing style

Follow the [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/top-10-tips-style-voice). These rules apply to all prose output — documentation,
commit messages, PR descriptions, code comments, plan files, skill files, and conversational responses. Code identifiers, technical terms, and API names are exempt.

## American English

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

## Core rules

1. **Use short, plain words.** Pick the simplest word that says what you mean. Never use a fancy word when a plain one works.

| Use this       | Not this                                       |
|----------------|------------------------------------------------|
| use            | utilize, leverage, make use of                 |
| remove         | extract, eliminate, excise                     |
| tell           | inform, advise, apprise                        |
| start          | initiate, commence                             |
| end            | terminate, conclude, finalize                  |
| stop           | cease, desist, discontinue                     |
| help           | assist, facilitate                             |
| show           | demonstrate, illustrate, exhibit               |
| get            | obtain, acquire, procure, retrieve             |
| give           | provide, furnish, supply                       |
| buy            | purchase                                       |
| need           | require, necessitate                           |
| about          | approximately, regarding, concerning           |
| to             | in order to, as a means to, for the purpose of |
| also           | in addition, additionally, furthermore         |
| but            | however, nevertheless, notwithstanding         |
| so             | consequently, therefore, accordingly           |
| before         | prior to, preceding, antecedent to             |
| after          | subsequent to, following                       |
| next           | subsequent                                     |
| last           | final, ultimate                                |
| second-to-last | penultimate                                    |
| enough         | sufficient, adequate                           |
| whole          | entire, totality                               |
| set up         | establish, instantiate                         |
| connect        | establish connectivity                         |
| many           | a plethora of, a multitude of, myriad          |

2. **Write like you speak.** Read your text aloud. If it sounds stiff or unnatural, rewrite it. Use contractions: *it's*, *you'll*, *you're*, *we're*, *don't*, *can't*,
   *let's*.

3. **Get to the point.** Lead with what matters most. Front-load keywords for scanning. Cut filler words (*just*, *really*, *basically*, *actually*, *simply*, *quite*,
   *very*, *effectively*). If a word doesn't add meaning, delete it.

4. **Be brief.** Give readers just enough information to act. Prune every extra word. Don't use two or three words when one works.

5. **Start with a verb.** Edit out *you can* when it isn't needed. Avoid weak openings: *there is*, *there are*, *it is important to note that*.

6. **Use sentence-style capitalization.** Capitalize only the first word of a heading and proper nouns. Don't use title case (Like This).

7. **Use the Oxford comma.** In a list of three or more items, include a comma before the conjunction: *Android, iOS, and Windows*.

8. **Use one space after periods.** No spaces around em dashes.

9. **Skip end punctuation on headings.** Don't use periods or colons at the end of titles, headings, or subheadings.

10. **Revise weak writing.** Choose strong, specific verbs. Avoid vague verbs like *be*, *have*, *make*, and *do* when a more precise verb exists.

## Words and phrases to avoid

Never use these in prose. The list isn't exhaustive — apply the same judgment to similar words.

- **Latinate or academic synonyms when a plain word exists:** *utilize*, *leverage*, *facilitate*, *commence*, *terminate*, *penultimate*, *aforementioned*, *herein*,
  *wherein*, *thereof*, *subsequent*, *antecedent*, *ascertain*, *endeavor*, *procure*, *furnish*, *apprise*, *substantiate*, *delineate*, *elucidate*, *promulgate*,
  *effectuate*, *aforestated*.
- **Filler adverbs:** *quite*, *very*, *really*, *just*, *basically*, *actually*, *simply*, *effectively*, *essentially*, *fundamentally*, *literally* (when not literal).
- **Vague hedging:** *it should be noted that*, *it is important to*, *it is worth mentioning*, *as a matter of fact*, *in point of fact*, *needless to say*.
- **Overblown connectors:** *furthermore*, *moreover*, *nevertheless*, *notwithstanding*, *henceforth*, *heretofore*, *insofar as*, *inasmuch as*, *vis-à-vis*.

When you catch yourself reaching for a fancy word, ask: "Would I say this out loud to a coworker?" If not, pick the word you would say.

## Technical terms

Technical terms are exempt from plain-word substitution when they're the correct term for the concept. *Middleware*, *polymorphism*, *idempotent*, *serialization* — these
are precise, not fancy. Use them when they're the right word. Don't use them when a plain word is just as accurate.

## Audience adaptation

- **End-user documentation:** Write for people who may have limited technical experience. Use plain language, step-by-step instructions, and real-world examples from the
  application's domain. Avoid jargon entirely.
- **Developer documentation:** Technical precision matters. Use correct terminology and exact names from the code. Code examples must be accurate and runnable. Jargon is
  acceptable when it's the correct term — but still prefer the simpler synonym when two terms are equally precise.
- **All other prose (commits, plans, skills, conversations):** Default to plain language. Use technical terms only when they add precision a simpler word can't match.
