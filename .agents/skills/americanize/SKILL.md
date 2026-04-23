---
name: americanize
description: Converts British English spelling to American English in a file or directory. Scans text files for common British variants and rewrites them in-place. Accepts a file path or directory path as $ARGUMENTS.
argument-hint: "<file-or-directory-path>"
disable-model-invocation: false
allowed-tools:
  - Read
  - Edit
  - Glob
  - Grep
  - Bash(find *)
model: sonnet
---

# Americanize

Convert British English spelling to American English across a file or directory.

## Your Task

Scan the target path for British English spelling variants and replace them with American English equivalents.
Edit files in-place. Report a summary of what changed.

## Steps

### 1. Resolve Target Path

Read `$ARGUMENTS`. If empty, tell the user to provide a file or directory path and exit.

The path may be absolute or relative. Treat it as-is.

### 2. Collect Files to Scan

**If the target is a single file:** scan that file only.

**If the target is a directory:** use Glob to collect all text files recursively. Skip binary files and these
paths regardless of content:

- `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.webp`, `*.svg`, `*.ico`
- `*.pdf`, `*.zip`, `*.tar`, `*.gz`, `*.woff`, `*.woff2`, `*.ttf`, `*.eot`
- `*.lock` (e.g. `composer.lock`, `package-lock.json`, `yarn.lock`)
- `node_modules/`, `vendor/`, `.git/`

### 3. Scan and Replace

For each collected file, use Grep to check if any British spellings are present before reading.
Only read and edit files that have at least one match.

Apply **all** substitutions from the reference table below. Replacements are **case-sensitive and
case-preserving**: match the casing pattern of the found word and apply the same pattern to the replacement.

Casing patterns to handle for each substitution:

| Found form | Replace with |
|------------|--------------|
| `word`     | `word`       |
| `Word`     | `Word`       |
| `WORD`     | `WORD`       |

Do NOT alter words inside URLs, import paths, package names, or version strings (e.g. `node_modules`,
`colour-js`, `en-GB` locale identifiers). Use judgment — if changing the spelling would break a reference to
an external identifier, skip it.

### 4. British → American Reference Table

Apply every substitution in this table. This list is not exhaustive — use it as a seed. If you encounter an
obvious British variant not listed here, apply the correct American spelling.

#### -our → -or

| British       | American     |
|---------------|--------------|
| colour        | color        |
| colours       | colors       |
| coloured      | colored      |
| colouring     | coloring     |
| colourful     | colorful     |
| behaviour     | behavior     |
| behaviours    | behaviors    |
| behavioural   | behavioral   |
| favour        | favor        |
| favours       | favors       |
| favoured      | favored      |
| favourite     | favorite     |
| favourites    | favorites    |
| flavour       | flavor       |
| flavours      | flavors      |
| honour        | honor        |
| honours       | honors       |
| honourable    | honorable    |
| humour        | humor        |
| humours       | humors       |
| humorous      | humorous     |
| labour        | labor        |
| labours       | labors       |
| neighbour     | neighbor     |
| neighbours    | neighbors    |
| neighbourhood | neighborhood |
| rumour        | rumor        |
| rumours       | rumors       |
| saviour       | savior       |
| tumour        | tumor        |
| tumours       | tumors       |
| vapour        | vapor        |
| vigour        | vigor        |

#### -ise → -ize / -isation → -ization

| British          | American         |
|------------------|------------------|
| organise         | organize         |
| organises        | organizes        |
| organised        | organized        |
| organising       | organizing       |
| organisation     | organization     |
| organisations    | organizations    |
| organisational   | organizational   |
| recognise        | recognize        |
| recognises       | recognizes       |
| recognised       | recognized       |
| recognising      | recognizing      |
| recognisable     | recognizable     |
| authorise        | authorize        |
| authorises       | authorizes       |
| authorised       | authorized       |
| authorising      | authorizing      |
| authorisation    | authorization    |
| authorisations   | authorizations   |
| realise          | realize          |
| realises         | realizes         |
| realised         | realized         |
| realising        | realizing        |
| realisation      | realization      |
| specialise       | specialize       |
| specialises      | specializes      |
| specialised      | specialized      |
| specialising     | specializing     |
| specialisation   | specialization   |
| minimise         | minimize         |
| minimises        | minimizes        |
| minimised        | minimized        |
| minimising       | minimizing       |
| maximise         | maximize         |
| maximises        | maximizes        |
| maximised        | maximized        |
| maximising       | maximizing       |
| optimise         | optimize         |
| optimises        | optimizes        |
| optimised        | optimized        |
| optimising       | optimizing       |
| optimisation     | optimization     |
| optimisations    | optimizations    |
| utilise          | utilize          |
| utilises         | utilizes         |
| utilised         | utilized         |
| utilising        | utilizing        |
| utilisation      | utilization      |
| prioritise       | prioritize       |
| prioritises      | prioritizes      |
| prioritised      | prioritized      |
| prioritising     | prioritizing     |
| prioritisation   | prioritization   |
| synchronise      | synchronize      |
| synchronises     | synchronizes     |
| synchronised     | synchronized     |
| synchronising    | synchronizing    |
| synchronisation  | synchronization  |
| initialise       | initialize       |
| initialises      | initializes      |
| initialised      | initialized      |
| initialising     | initializing     |
| initialisation   | initialization   |
| normalise        | normalize        |
| normalises       | normalizes       |
| normalised       | normalized       |
| normalising      | normalizing      |
| normalisation    | normalization    |
| serialise        | serialize        |
| serialises       | serializes       |
| serialised       | serialized       |
| serialising      | serializing      |
| serialisation    | serialization    |
| deserialise      | deserialize      |
| deserialises     | deserializes     |
| deserialised     | deserialized     |
| deserialising    | deserializing    |
| deserialisation  | deserialization  |
| customise        | customize        |
| customises       | customizes       |
| customised       | customized       |
| customising      | customizing      |
| customisation    | customization    |
| standardise      | standardize      |
| standardises     | standardizes     |
| standardised     | standardized     |
| standardising    | standardizing    |
| standardisation  | standardization  |
| categorise       | categorize       |
| categorises      | categorizes      |
| categorised      | categorized      |
| categorising     | categorizing     |
| categorisation   | categorization   |
| characterise     | characterize     |
| characterises    | characterizes    |
| characterised    | characterized    |
| characterising   | characterizing   |
| characterisation | characterization |
| summarise        | summarize        |
| summarises       | summarizes       |
| summarised       | summarized       |
| summarising      | summarizing      |
| summarisation    | summarization    |
| emphasise        | emphasize        |
| emphasises       | emphasizes       |
| emphasised       | emphasized       |
| emphasising      | emphasizing      |
| analyse          | analyze          |
| analyses         | analyzes         |
| analysed         | analyzed         |
| analysing        | analyzing        |
| analyse          | analyze          |
| paralysed        | paralyzed        |

#### -re → -er

| British  | American  |
|----------|-----------|
| centre   | center    |
| centres  | centers   |
| centred  | centered  |
| centring | centering |
| fibre    | fiber     |
| fibres   | fibers    |
| litre    | liter     |
| litres   | liters    |
| lustre   | luster    |
| metre    | meter     |
| metres   | meters    |
| spectre  | specter   |
| theatre  | theater   |
| theatres | theaters  |

#### -ce → -se (nouns → verbs)

| British  | American |
|----------|----------|
| licence  | license  |
| licences | licenses |
| licenced | licensed |
| practise | practice |

#### -ll- → -l- (single consonant)

| British    | American    |
|------------|-------------|
| labelled   | labeled     |
| labelling  | labeling    |
| travelling | traveling   |
| travelled  | traveled    |
| traveller  | traveler    |
| travellers | travelers   |
| cancelled  | canceled    |
| cancelling | canceling   |
| modelled   | modeled     |
| modelling  | modeling    |
| signalled  | signaled    |
| signalling | signaling   |
| fulfil     | fulfill     |
| fulfils    | fulfills    |
| fulfilled  | fulfilled   |
| fulfilling | fulfilling  |
| fulfilment | fulfillment |
| enrol      | enroll      |
| enrols     | enrolls     |
| enrolled   | enrolled    |
| enrolling  | enrolling   |
| enrolment  | enrollment  |

#### Miscellaneous

| British          | American        |
|------------------|-----------------|
| catalogue        | catalog         |
| catalogues       | catalogs        |
| catalogued       | cataloged       |
| dialogue         | dialog          |
| dialogues        | dialogs         |
| programme        | program         |
| programmes       | programs        |
| programmed       | programmed      |
| programming      | programming     |
| defence          | defense         |
| defences         | defenses        |
| offence          | offense         |
| offences         | offenses        |
| pretence         | pretense        |
| pretences        | pretenses       |
| ageing           | aging           |
| judgement        | judgment        |
| judgements       | judgments       |
| acknowledgement  | acknowledgment  |
| acknowledgements | acknowledgments |
| colour-blind     | color-blind     |
| grey             | gray            |
| greys            | grays           |
| skilful          | skillful        |
| skilfully        | skillfully      |
| mould            | mold            |
| moulds           | molds           |
| moulded          | molded          |
| moulding         | molding         |
| smoulder         | smolder         |
| plough           | plow            |
| ploughs          | plows           |
| draught          | draft           |
| draughts         | drafts          |
| tyre             | tire            |
| tyres            | tires           |
| storey           | story           |
| storeys          | stories         |
| manoeuvre        | maneuver        |
| manoeuvres       | maneuvers       |
| pyjamas          | pajamas         |
| kerb             | curb            |
| kerbs            | curbs           |
| whilst           | while           |
| amongst          | among           |
| towards          | toward          |

### 5. Apply Edits

Use the Edit tool to make replacements. Prefer a single Edit call per file when possible. If a file has many
scattered replacements, make multiple Edit calls — one per unique replacement site to avoid conflicts.

Never alter:

- The file's indentation or whitespace beyond the changed word
- Code logic, variable names that match package/library identifiers, or locale strings like `en-GB`
- URLs, import paths, or dependency names (e.g. `colour` in a npm package name)

### 6. Report Summary

After processing all files, output a markdown summary:

```markdown
## Americanize Summary

**Target:** `<path>`
**Files scanned:** X
**Files changed:** Y

### Changed Files

| File                | Replacements                              |
|---------------------|-------------------------------------------|
| `path/to/file.md`   | colour→color (3), organised→organized (1) |
| `path/to/other.php` | behaviour→behavior (2)                    |

### No Changes Needed

Files scanned but already using American English (or no British variants found) are not listed here.
```

If no files needed changes, say so clearly.

**Begin now. Read `$ARGUMENTS` and proceed.**