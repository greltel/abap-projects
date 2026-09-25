# Contributing to ABAP Projects

Thanks for taking the time to contribute. This repository collects reusable,
dynamic ABAP utilities, so the bar is a little different from an application
project: everything here is meant to be dropped into somebody else's system and
still behave. That means portability, defensive behaviour and tests matter more
than feature count.

- [Ground rules](#ground-rules)
- [Getting the code into a system](#getting-the-code-into-a-system)
- [Running the checks locally](#running-the-checks-locally)
- [Coding standards](#coding-standards)
- [Unit tests](#unit-tests)
- [ABAP Doc](#abap-doc)
- [Commits and pull requests](#commits-and-pull-requests)
- [Reporting a bug](#reporting-a-bug)

---

## Ground rules

| | |
|---|---|
| **Target release** | SAP S/4HANA 2023 FPS03, ABAP 7.58 |
| **Namespace** | `Z*` only — `ZCL_`/`ZCX_` for classes, `ZIF_` for interfaces, `Z` for programs |
| **Language** | Code, identifiers, comments and commit messages in English |
| **Style** | [Clean ABAP](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md) |
| **Transport format** | abapGit, `PREFIX` folder logic, sources under `/src/` |

Two rules are specific to this repository and are worth stating up front,
because breaking either one makes a utility unusable for the people it is
written for:

**1. No foreign application namespaces.** A reusable utility may only depend on
ABAP language constructs, released SAP APIs and its own objects. Do not borrow a
constant, type or class from an unrelated application component just because it
happens to hold the value you need. Declare your own constant instead.

```abap
" No - drags in an unrelated component and will not activate everywhere
DATA(length) = cl_mmim_maa_2=>gc_integer_8.

" Yes
CONSTANTS icon_column_length TYPE i VALUE 8.
```

**2. Dynamic data access stays read-only.** `Z_SALV_ALV` reads any table by name,
and that is the point of it. Access is governed by who can start the program —
the same way `SE16` is restricted — rather than by an `AUTHORITY-CHECK` in the
code. Keep it that way: never add a dynamic path that writes, deletes or locks a
table chosen at runtime, and never let a table name reach anything other than a
`SELECT`. Anyone installing this on a system with real users should restrict the
program or its transaction accordingly.

---

## Getting the code into a system

1. Install [abapGit](https://abapgit.org) in your development system.
2. Create the package (`ABAP_PROJECTS` by default) and clone
   `https://github.com/greltel/abap-projects` into it.
3. Pull, then activate the objects.

For local development off a real system, see the next section — the static
analysis and the unit tests both run on your laptop without a SAP system.

---

## Running the checks locally

Both CI jobs run on any machine with Node.js 22 or newer. No SAP system
required.

```bash
npm ci        # install abaplint + the transpiler
npm run lint  # static analysis      (must be clean)
npm test      # off-stack ABAP Unit  (must be clean)
npm run clean # remove the generated output/ folder
```

Please run both checks before opening a pull request. CI runs exactly the same
two commands.

### `npm run lint` — abaplint

`abaplint.json` is configured for **v758**, matching the target release. Rules
are split into two severities on purpose:

- **Error** — must be clean. The build fails.
- **Warning** — visible on every run and in the job summary, but not blocking.

The working agreement for warnings is simple: **do not add new ones.** When you
touch a file, clear the warnings in the part you touched. As a rule class drops
to zero, promote it to `Error` in `abaplint.json` in the same pull request so it
can never come back.

Current state: **0 errors, 5 warnings.** All five come from `check_syntax`,
which is the one rule deliberately set to `Warning`: `abaplint/deps` does not
ship `CL_SALV_CONTROLLER` or the full type-pool `ABAP` constants, so those
findings are missing stubs rather than defects. Treat a *new* `check_syntax`
finding in your own code as an error anyway — the transpiler will reject it.

Two rules are worth knowing about because they shape how code is written here:

- `method_parameter_names` enforces the `IV_`/`EV_`/`CV_`/`RV_` prefixes. Test
  includes and `ZCX_*` classes are excluded, since exception constructors take
  `textid` and `previous`.
- `sql_escape_host_variables` and `obsolete_statement` are `Error`. There is no
  grandfathering — if you touch a statement, it comes up to standard.

`dangerous_statement` is not enabled. The dynamic `SELECT` in `Z_SALV_ALV` is
what the report is for, so the rule would do nothing but hold a permanent
exemption. Ground rule 2 is what keeps that statement honest instead.

### `npm test` — off-stack ABAP Unit

The ABAP Unit tests run **without a SAP system**, by transpiling the ABAP to
JavaScript with the [abaplint transpiler](https://github.com/abaplint/transpiler)
and executing it against
[open-abap-core](https://github.com/open-abap/open-abap-core).

```
src/*.abap ──▶ abap_transpile ──▶ output/*.mjs ──▶ node ──▶ pass / fail
                     ▲
               open-abap-core
```

| Path | Purpose |
|---|---|
| `abap_transpile.json` | Which objects get transpiled, and where the DDIC stubs are |
| `test/ddic/` | Minimal abapGit XML for the SAP standard DDIC objects the tests reference |
| `output/` | Generated JavaScript and the test driver — **not** committed |

There is no separate runner script. The transpiler generates `output/index.mjs`
itself, and `package.json` simply chains the two steps:

```json
"test": "abap_transpile abap_transpile.json && node output/index.mjs"
```

**DDIC stubs.** open-abap-core ships no SAP application dictionary, so a test that
touches `MARA`, `VBELN`, `RSTABLE` and the like would hit a `Void type` error.
`test/ddic/` holds minimal abapGit-format definitions of exactly those objects —
key fields, lengths and `CONVEXIT` only — and `abap_transpile.json` loads the
folder as a local library. The folder sits outside `/src/` on purpose: abapGit's
starting folder never deploys it and abaplint's `files` glob never analyses it.
`"unknownTypes": "runtimeError"` stays on, so a type nobody stubbed still fails
loudly in the test that uses it rather than at transpile time. When a new test
needs another standard object, add the smallest stub that satisfies it there.

**Adding an object to the off-stack suite.** Add a pattern to `input_filter` in
`abap_transpile.json` and run `npm test`.

**Skipping a test that cannot run off-stack.** The list is currently empty and
should stay that way. If a genuine runtime gap appears, add an entry to
`options.skip` with a `comment` saying why:

```json
{ "comment": "DDIC conversion exits are not wired up off-stack, CONVEXIT comes back blank",
  "object": "ZCL_ABAP_PROJECTS", "class": "ltc_alpha_conversion", "method": "given_alpha_in_then_padded" }
```

The test is then reported as `skipped due to configuration` and does not break
the build. Keep the list short and keep every `comment` concrete — each entry is
a limit on what CI can prove, so prefer making the code testable over adding an
exception. Skip only for a genuine runtime gap, never to silence a real failure.
Before adding one, check whether the test can be rescoped instead: a test that
only exercises validation usually does not need a DDIC type at all.

**What the off-stack runtime cannot do.** It is a real ABAP implementation, but
not a complete one, and it is weakest in exactly the area this repository
specialises in — runtime-typed dynamic programming. Verified limits today:

- DDIC conversion exits are not wired up: the domain's `CONVEXIT` is parsed from
  the XML but never reaches the runtime, so `CONVERSION_EXIT_*` routines are
  never called.
- `GET_DDIC_FIELD_LIST` fills only `TABNAME`, `FIELDNAME`, `LENG` and `KEYFLAG`.
  `INTTYPE` and `DATATYPE` come back blank, so anything that branches on the
  field's type sees nothing.
- `READ TABLE … WITH TABLE KEY (name) = value` does not match when `name` is a
  variable — `sy-subrc` is 4. The same statement with a literal key name works,
  which makes the gap easy to miss.
- `SORT <itab> BY (name)` transpiles, but the sort key is **silently dropped** —
  the table comes back in its original order with `sy-subrc` 0.
- `DELETE TABLE <itab> WITH TABLE KEY (name) = value` cannot be parsed at all and
  fails the build with `parser_error`. Use `DELETE TABLE <itab> FROM <work_area>`
  instead.
- `TEST-SEAM` / `TEST-INJECTION` is rejected outright with
  `Statement TestSeam not supported`, and it fails the whole build rather than the
  one test that uses it. Where something has to be faked, it has to be faked
  through an interface.

---

## Coding standards

Modern syntax throughout. The detailed rules are in Clean ABAP; these are the
ones that come up most often in review here.

**Do**

- `SELECT FROM source FIELDS list WHERE … INTO …` — `FROM` first, never the
  legacy field-list-before-`FROM` form. Escape host variables with `@`.
- Inline declarations at first use: `DATA(result) = …`.
- `VALUE`, `CONV`, `COND`, `SWITCH`, `CORRESPONDING`, string templates.
- `INSERT … INTO TABLE` rather than `APPEND`; `line_exists( )` rather than
  `READ TABLE … TRANSPORTING NO FIELDS`.
- Explicit table keys. Booleans as `abap_bool`, set via `xsdbool( )`.
- Named constants for anything that is not self-evident.
- `RAISE EXCEPTION NEW zcx_…( )`.

**Don't**

- `MOVE`, `CREATE OBJECT`, `CALL METHOD`, `CONCATENATE`, `ADD … TO`, `REFRESH`,
  `TYPE-POOLS`, `PERFORM`/`FORM`.
- `SWITCH` or `COND` without `ELSE` when every case matters. `SWITCH` raises
  `CX_SY_CASE_NOT_FOUND`; `COND` quietly returns the initial value, which is the
  more dangerous of the two because nothing tells you it happened.
- `CHECK` for validation inside a method. `CHECK` belongs at the start of a loop
  pass; everywhere else it exits silently and the caller cannot tell whether the
  method did its job or gave up. Use `IF … RETURN` with a result, or raise.
- Swallowing exceptions. `CATCH cx_… ##NO_HANDLER` on a path the caller depends
  on hides real failures — either handle it, wrap it, or let it out.
- Commented-out code. Git remembers it.
- Hardcoded user-facing text. Use text symbols or the message class.

**Error handling.** A method that cannot do what its name says should say so.
Failures go through `ZCX_ABAP_PROJECTS`, which carries a T100 message from
`ZABAP_PROJECTS` plus the object name and a detail string, so the caller gets a
usable text rather than a bare exception. Where a result structure is the better
fit — `LOCK_TABLE` is the example, because a lock held by somebody else is a
routine outcome and not an error — fill it with something the caller can act on.
Never return an initial structure and leave them guessing.

Calling a classic exception interface functionally is a short dump waiting to
happen. `CL_ABAP_TYPEDESCR=>DESCRIBE_BY_NAME` raises `TYPE_NOT_FOUND` as a
classic exception, so it needs the long form:

```abap
cl_abap_typedescr=>describe_by_name(
  EXPORTING  p_name         = iv_table_name
  RECEIVING  p_descr_ref    = DATA(type)
  EXCEPTIONS type_not_found = 1
             OTHERS         = 2 ).
IF sy-subrc <> 0.
  RETURN.
ENDIF.
```

---

## Unit tests

Every class method gets a unit test. A pull request that adds or changes
behaviour without a test will be asked for one.

```abap
CLASS ltc_split_table DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS given_zero_segment_then_raise FOR TESTING RAISING cx_static_check.
ENDCLASS.
```

- Local test classes: `ltc_` (tests), `ltd_` (doubles), `lth_` (helpers).
- `FINAL`, `RISK LEVEL HARMLESS`, `DURATION SHORT`.
- Assert with **`cl_abap_unit_assert`**. `cl_aunit_assert` is obsolete, is not
  released for ABAP Cloud, and does not exist off-stack.
- Every assertion carries a meaningful `msg`.
- Name methods after the behaviour, not the method under test:
  `given_…_then_…`, 30 characters or fewer.
- Arrange / Act / Assert visible in the body. One concept per test.
- No database, RFC, authority or clock dependency — inject or stub it. Tests
  that need a real system belong behind an injected interface, not in the test.
- Prefer widening a method's visibility over `LOCAL FRIENDS`. `BUILD_VARKEY` is
  public for exactly this reason: it is a useful call in its own right, and the
  test class needs no privileged access to reach it.
- Cover the edges, not just the happy path: empty input, unknown column name,
  zero or negative sizes, a table kind the method was not written for.
- Keep a test's declarations as narrow as the behaviour it checks. A test for
  direction validation does not need a DDIC type, and using one only makes the
  test fail off-stack for a reason that has nothing to do with the assertion.

`ZCL_ABAP_PROJECTS` currently ships four test classes — `LTC_COUNT_VALUES`,
`LTC_ALPHA_CONVERSION`, `LTC_SPLIT_TABLE` and `LTC_BUILD_VARKEY` — with 18
tests.

**`LOCK_TABLE` and `UNLOCK_TABLE` are deliberately not covered.** Faking the
`ENQUEUE`/`DEQUEUE` call means either a test seam, which the transpiler rejects
and which would take the whole build down with it, or a lock interface plus a
production implementation of it injected into the class. Neither buys a test that
CI can actually run: both methods reach `BUILD_VARKEY` → `KEY_FIELDS` →
`GET_DDIC_FIELD_LIST`, and the specific-lock path reads `DD25L`, so the
dictionary gaps above stop the test before the enqueue is ever reached. Two new
repository objects and an injectable static, for tests that would live
permanently in `options.skip`, is not a trade this repository makes. Verify the
locking behaviour in ADT, and say in the pull request what you ran.

If a future change makes the dictionary calls injectable for their own sake, the
lock tests come along for free and this paragraph should go.

---

## ABAP Doc

Every public declaration carries ABAP Doc. This is the interface documentation
other developers read in ADT, so write what a caller needs to know — especially
what happens when things go wrong.

```abap
"! <p class="shorttext synchronized" lang="EN">Split a table into fixed-size chunks</p>
"!
"! Splits any internal table into smaller standard tables of
"! <em>im_split_segment</em> rows each, for parallel processing.
"!
"! @parameter im_table          | Source table, of any table kind.
"! @parameter im_split_segment  | Rows per chunk. Must be greater than zero.
"! @parameter re_tables         | One data reference per chunk, in source order.
"! @raising   zcx_abap_projects | Segment size is zero or negative.
CLASS-METHODS split_table
  IMPORTING !im_table          TYPE ANY TABLE
            !im_split_segment  TYPE i DEFAULT 100
  RETURNING VALUE(re_tables)   TYPE tt_split_tables
  RAISING   zcx_abap_projects.
```

Document the contract, not the implementation. `@parameter im_table | the table`
adds nothing; say what shape it has to be and what happens if it isn't. Always
document `@raising` — when the exception is raised is part of the contract.

---

## Commits and pull requests

**Commits.** Imperative mood, one logical change per commit.

```
Fix inverted length guard in build_varkey

The guard wrote the key only when offset + length exceeded the VARKEY
length, so a normal key was never written and lock_table silently did
nothing. Inverts the comparison and adds a test for MARA.
```

Avoid bare `Update README.md` / `Improvements` messages — they make `git log`
useless for finding when a behaviour changed.

**Pull requests.** Before opening one:

- [ ] `npm run lint` is clean and adds no new warnings
- [ ] `npm test` is clean, and no new `options.skip` entry was needed
- [ ] New and changed public methods have ABAP Doc
- [ ] New and changed behaviour has unit tests
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]`
- [ ] No new dependency on a foreign application namespace

In the description, say what changed and why, and mention anything you could
only verify in ADT rather than in CI — dynamic code is the part CI is weakest
at, so a note about what you actually ran on a system is valuable.

---

## Reporting a bug

Open an issue with:

- the object and the method (`ZCL_ABAP_PROJECTS=>LOCK_TABLE`)
- what you called it with, and the table involved
- what you expected and what happened instead
- your release and support package level

A short snippet that reproduces it is worth more than a description. If you hit
a short dump, the runtime error name and the failing source line are the useful
parts.

---

Ideas for new utilities are as welcome as fixes — open an issue first so we can
talk about scope before you write it.
