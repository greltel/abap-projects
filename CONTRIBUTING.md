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

**2. Dynamic data access needs an authority check.** Anything that reads a table
name from user input must check the caller's authorisation before selecting,
the way `SE16`/`SE16N` do. A dynamic `SELECT` without `AUTHORITY-CHECK` turns a
convenience report into a way of reading any table in the system.

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
npm run lint  # static analysis  (must be clean)
npm test      # off-stack ABAP Unit (must be clean)
```

Please run both before opening a pull request. CI runs exactly the same two
commands.

### `npm run lint` — abaplint

`abaplint.json` is configured for **v758**, matching the target release. Rules
are split into two severities on purpose:

- **Error** — must be clean. The build fails.
- **Warning** — the known cleanup backlog. Visible on every run and in the job
  summary, but not blocking yet.

The working agreement for warnings is simple: **do not add new ones.** When you
touch a file, clear the warnings in the part you touched. As a rule class drops
to zero, promote it to `Error` in `abaplint.json` in the same pull request so it
can never come back.

Three rules are set to `Warning` because `abaplint/deps` does not ship the SALV
and ALV grid classes or the complete type-pool `ABAP` constants — those findings
are missing stubs, not defects: `check_syntax`, `implement_methods`,
`superclass_final`. `dangerous_statement` is a genuine open finding (see rule 2
above) and gets promoted back to `Error` once the authority check lands.

### `npm test` — off-stack ABAP Unit

The ABAP Unit tests run **without a SAP system**, by transpiling the ABAP to
JavaScript with the [abaplint transpiler](https://github.com/abaplint/transpiler)
and executing it against
[open-abap-core](https://github.com/open-abap/open-abap-core).

```
src/*.abap ──▶ abap_transpile ──▶ ci/out/*.mjs ──▶ node ──▶ PASS / FAIL
                     ▲
               open-abap-core
               ci/ddic (stubs)
```

| Path | Purpose |
|---|---|
| `abap_transpile.json` | Which objects get transpiled |
| `ci/ddic/` | Minimal DDIC stubs (data elements, domains, tables) for objects the off-stack runtime has no dictionary for |
| `ci/run_unit_tests.mjs` | Test runner: `SYST` shim, per-test isolation, xfail handling |
| `ci/offstack-known-gaps.json` | Tests that cannot pass off-stack, with the reason |
| `ci/run_ci.sh` | Pipeline driver |
| `ci/out/` | Generated output — **not** committed |

**Adding an object to the off-stack suite.** Add a pattern to `input_filter` in
`abap_transpile.json` and run `npm test`. If it fails on an unknown DDIC type,
add a stub under `ci/ddic/` — copy the shape from an existing one. Note that a
field in a `.tabl.xml` needs `<COMPTYPE>E</COMPTYPE>` when it refers to a data
element via `ROLLNAME`; without it the parser expects an inline `DATATYPE` and
aborts.

**What the off-stack runtime cannot do.** It is a real ABAP implementation, but
not a complete one, and it is weakest in exactly the area this repository
specialises in — runtime-typed dynamic programming. Known limits today:

- DDIC conversion exits are not wired up: `get_ddic_field( )-convexit` comes back
  blank, so `CONVERSION_EXIT_*` routines are never reached.
- `SORT <itab> BY (dynamic_name)` transpiles with the sort key **silently
  dropped**.
- `CORRESPONDING #( )` into a generic `FIELD-SYMBOL TYPE SORTED TABLE` whose row
  type was built at runtime emits a placeholder row type and fails at run time.
- `DELETE TABLE <itab> WITH TABLE KEY (dynamic_name) = value` cannot be parsed at
  all. `READ TABLE ... WITH KEY (dynamic_name)` parses fine, which makes the gap
  easy to trip over. Use `DELETE TABLE <itab> FROM <work_area>` instead.

When a test fails for one of these reasons and not because the ABAP is wrong,
add it to `ci/offstack-known-gaps.json` with a concrete explanation. It is then
reported `XFAIL` and does not break the build. If a listed test later starts
passing it is reported `XPASS` and **does** break the build, so stale entries
cannot accumulate — delete the entry in that case.

Keep that list short. Every entry is a limit on what CI can prove, so prefer
making the code testable over adding an exception.

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
- `CHECK` for validation inside a method. `CHECK` belongs at the start of a loop
  pass; everywhere else it exits silently and the caller cannot tell whether the
  method did its job or gave up. Use `IF … RETURN` with a result, or raise.
- Swallowing exceptions. `CATCH cx_… ##NO_HANDLER` on a path the caller depends
  on hides real failures — either handle it, wrap it, or let it out.
- Commented-out code. Git remembers it.
- Hardcoded user-facing text. Use text symbols.

**Error handling.** A method that cannot do what its name says should say so.
Prefer an exception; where a result structure is the better fit, fill it with
something the caller can act on — never return an initial structure and leave
them guessing.

---

## Unit tests

Every class method gets a unit test. A pull request that adds or changes
behaviour without a test will be asked for one.

```abap
CLASS ltc_split_table DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS when_segment_zero_then_raises FOR TESTING RAISING cx_static_check.
ENDCLASS.
```

- Local test classes: `ltc_` (tests), `ltd_` (doubles), `lth_` (helpers).
- `FINAL`, `RISK LEVEL HARMLESS`, `DURATION SHORT`.
- Assert with **`cl_abap_unit_assert`**. `cl_aunit_assert` is obsolete, is not
  released for ABAP Cloud, and does not exist off-stack.
- Every assertion carries a meaningful `msg`.
- Name methods after the behaviour, not the method under test:
  `given_…_when_…_then_…`, 30 characters or fewer.
- Arrange / Act / Assert visible in the body. One concept per test.
- No database, RFC, authority or clock dependency — inject or stub it. Tests
  that need a real system belong behind an injected interface, not in the test.
- Cover the edges, not just the happy path: empty input, unknown column name,
  zero or negative sizes, a table kind the method was not written for.

---

## ABAP Doc

Every public declaration carries ABAP Doc. This is the interface documentation
other developers read in ADT, so write what a caller needs to know — especially
what happens when things go wrong.

```abap
"! <p class="shorttext synchronized">Split a table into fixed-size chunks</p>
"!
"! Splits any standard internal table into smaller tables of
"! <em>segment_size</em> rows each, for parallel processing.
"!
"! @parameter table        | Source table. A sorted or hashed table is rejected.
"! @parameter segment_size | Rows per chunk. Must be greater than zero.
"! @parameter result       | One data reference per chunk, in source order.
"! @raising   zcx_abap_projects | Segment size is zero or negative.
CLASS-METHODS split_table
  IMPORTING table         TYPE ANY TABLE
            segment_size  TYPE i DEFAULT 100
  RETURNING VALUE(result) TYPE tt_split_tables
  RAISING   zcx_abap_projects.
```

Document the contract, not the implementation. `@parameter table | the table`
adds nothing; say what shape it has to be and what happens if it isn't.

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
- [ ] `npm test` is clean
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
