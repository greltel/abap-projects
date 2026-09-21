# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Because this repository ships ABAP source rather than a binary, "breaking"
means a change that alters a method signature, removes an object, or changes
runtime behaviour in a way that requires callers to adapt.

## [Unreleased]

### Added

- `ZCX_ABAP_PROJECTS` — one exception class for the whole repository, based on
  `CX_STATIC_CHECK` and `IF_T100_MESSAGE`, carrying the failing object name and
  a free-text detail alongside the message.
- `ZABAP_PROJECTS` message class, with the eleven T100 messages raised by
  `ZCL_ABAP_PROJECTS` (locking 010–013, conversion 020–022, analysis 030–033).
- ABAP Doc on every method of `ZCL_ABAP_PROJECTS`, documenting the contract and
  the conditions under which each method raises.
- Unit tests for `ZCL_ABAP_PROJECTS`: `LTC_COUNT_VALUES`, `LTC_ALPHA_CONVERSION`,
  `LTC_SPLIT_TABLE` and `LTC_BUILD_VARKEY`, 18 tests in total, covering the
  empty table, an unknown column, a zero segment size, a sorted source table, a
  type without a conversion exit and an invalid conversion direction.
- Continuous integration on GitHub Actions (`.github/workflows/ci.yml`) with two
  jobs: `abaplint` static analysis, and off-stack ABAP Unit execution with a
  run summary.
- Off-stack ABAP Unit pipeline built on the
  [abaplint transpiler](https://github.com/abaplint/transpiler) and
  [open-abap-core](https://github.com/open-abap/open-abap-core), so the tests run
  on any machine with Node.js and no SAP system. Configuration lives entirely in
  `abap_transpile.json`; the transpiler generates its own test driver, so the
  repository carries no runner script and no DDIC stub folder.
  `"unknownTypes": "runtimeError"` lets objects that reference SAP standard
  dictionary types transpile without stubs, and `options.skip` lists the seven
  tests that cannot run off-stack, each with the reason.
- `package.json` with `npm run lint`, `npm test` and `npm run clean`.
- `CONTRIBUTING.md` — contribution guide covering the coding standards, the unit
  test and ABAP Doc requirements, how to run both checks locally, and the
  verified limits of the off-stack runtime.
- `CHANGELOG.md` — this file.
- `.gitignore` for `node_modules/`, `/output/` and `/deps/`.

### Changed

- `abaplint.json` now targets **v758** instead of **v702**. At v702 none of the
  modern-syntax sources could be parsed, and because `parser_error` was not
  enabled the parse failures were discarded silently — the configuration
  reported a clean run while analysing nothing.
- `abaplint.json` rule set extended and split by severity. `Error` rules block
  the build; `check_syntax` is `Warning` because `abaplint/deps` does not ship
  `CL_SALV_CONTROLLER` or the complete type-pool `ABAP` constants, so those
  findings are missing stubs rather than defects. Current state:
  **0 errors, 5 warnings.**
- `ZCL_ABAP_PROJECTS=>BUILD_VARKEY` is now public. It is a useful call in its own
  right, and making it public lets the test class reach it without `LOCAL
  FRIENDS`.
- `ZCL_ABAP_PROJECTS=>COUNT_SINGLE_MULTIPLE_VALUES` rewritten as a single pass
  over the source table into a hashed counter table. The previous implementation
  copied the whole table once per row and then deleted from the table it was
  looping over — O(n²) in time and memory, on an example that passes 10,000 rows.
- Both exported tables of `COUNT_SINGLE_MULTIPLE_VALUES` are hashed and keyed by
  the counted column, with an added `COUNT` component.
- `UNLOCK_TABLE` and `LOCK_TABLE` now default `IV_SCOPE` to `'1'` on both sides.
  The defaults used to be asymmetric (`'2'` to lock, `'3'` to unlock), so a
  caller that accepted the defaults could not release its own lock.
- Test assertions moved from `CL_AUNIT_ASSERT` to `CL_ABAP_UNIT_ASSERT`.
  `CL_AUNIT_ASSERT` is obsolete, is not released for ABAP Cloud, and does not
  exist off-stack.
- The four demo reports (`Z_DYNAMIC_CONVERSION`, `Z_SPLIT_TABLE`,
  `ZCOUNT_SINGLE_MULTIPLE_VALUES`, `Z_DYNAMIC_LOCK_UNLOCK`) now wrap their calls
  in `TRY … CATCH zcx_abap_projects` and write their results, so they compile
  against the new signatures and show what the utility returned.
- `Z_SALV_ALV`: removed `TYPE-POOLS`, replaced `REFRESH` with `CLEAR` and
  `ADD 1 TO` with an assignment, renamed the `LCL_SALV_EDIT` parameters to the
  `IM_`/`RE_` convention, and dropped redundant `EXPORTING` keywords.
- `Z_DYNAMIC_TEXTS_EXPORT`: parameters renamed to the `IM_` convention and the
  unused byte counter removed.

### Fixed

- `BUILD_VARKEY` had an inverted length guard (`IF ( offset + len ) GE
  varkey_length`). The key was written only when it would overflow, so for every
  normal table nothing was written, `LOCK_TABLE` hit its `CHECK varkey IS NOT
  INITIAL` and returned an initial result — reporting failure with no message,
  having taken no lock. The generic (`IV_ENABLE_SPECIFIC_LOCK = ABAP_FALSE`)
  locking path had therefore never worked.
- `UNLOCK_TABLE` did not forward `IV_ENQMODE` to `EXECUTE_SPECIFIC_LOCK`, so the
  dequeue ran with a blank lock mode and never released a lock taken with mode
  `E`.
- `KEY_FIELDS` called `CL_ABAP_TYPEDESCR=>DESCRIBE_BY_NAME` and
  `GET_DDIC_FIELD_LIST` functionally. Both raise **classic** exceptions, so an
  unknown table name produced a short dump instead of an empty result. Both are
  now called with `EXCEPTIONS` and the return code is checked.
- `EXECUTE_SPECIFIC_LOCK` read the lock object out of a one-component structure
  as if it were a character field, which does not convert. It now reads the
  component explicitly.
- `ALPHA_CONVERSION`: the `CAST` to `CL_ABAP_ELEMDESCR` is guarded, the function
  module return code is checked, and the `SWITCH` that picks the conversion
  direction has an `ELSE` branch — without it the statement raised
  `CX_SY_CASE_NOT_FOUND` and the "no conversion exit" path below it was
  unreachable.
- `ALPHA_CONVERSION` used `exit` as a variable name, which is an ABAP keyword.
- `SPLIT_TABLE` now rejects a segment size of zero or less instead of looping.
- `Z_DYNAMIC_TEXTS_EXPORT` swallowed `CX_SALV_MSG` and left the report through a
  bare `EXIT`, so a failed download looked like a successful one. It now raises
  `LCX_TEXTS` with a message.

### Known issues

Open findings from the source review, not yet fixed. Listed by severity so they
can be picked up in order.

- `Z_SALV_ALV` performs a fully dynamic `SELECT * FROM (table)` driven by user
  input with no `AUTHORITY-CHECK` (line 770). Any user who can start the report
  can read any table in the system. Needs an `S_TABU_NAM` / `S_TABU_DIS` check
  before the select, as `SE16N` does. There is no `AUTHORITY-CHECK` anywhere in
  `src/` today.
- `Z_SALV_ALV` depends on three foreign application namespaces for constants that
  are plain literals: `/ACCGO/IF_CCK_DPQS_CONSTANTS` and `/ACCGO/IF_CAS_CONSTANTS`
  (SAP Agricultural Contract Management), `CL_CMS_COMMON` (Collateral Management)
  and `CL_MMIM_MAA_2` (Inventory Management). The `/ACCGO/` add-on is not present
  on a standard S/4HANA system, so the program cannot be activated there.
  `Z_DYNAMIC_TEXTS_EXPORT` uses `CL_CMS_COMMON` for the same purpose.
- `Z_SALV_ALV=>SCREEN_PBO` has the two data-source groups swapped: `P_DB`
  activates group `ID3`, which is the Excel block, and `P_FILE` activates `ID4`,
  which is the database block. Selecting either source shows the other one's
  fields.
- `Z_SALV_ALV=>SCREEN_PBO` also sets `SCREEN-REQUEST` and `SCREEN-DISPLAY_3D`
  from a `COND #( )` with no `ELSE`. Every element other than `T_HITS` therefore
  gets the initial value, blanking the 3D frame across the whole selection
  screen on each PBO.
- `LCL_SALV_EDIT=>SET_EDITABLE` and `GET_CONTROL` are entirely commented out, so
  the edit button and the double-click-to-edit behaviour advertised in the README
  do nothing. The commented body still refers to the old `I_*` parameter names
  and would not compile as it stands.
- `LCL_UTILITIES=>CHECK_FIELD_EXISTS_IN_TABLE` and `DYNAMIC_WHERE_CLAUSE` type
  their field parameter as `CHAR5`, and `P_FIEL` on the selection screen is
  `CHAR5` as well. Field names up to 30 characters are silently truncated, so the
  existence check fails and the filter is dropped for most fields.
- `LCL_SEL_SCREEN=>FIELDS_F4` issues a `SELECT SINGLE` on `DD04T` inside a loop
  over every component of the selected table, and the inline `@DATA(scrtext_l)`
  is not cleared between iterations, so a field without a text inherits the
  previous field's description. The F4 window title is a hardcoded literal.
- `LCL_TEXTS=>POPULATE_TEXTS` calls `READ_MULTIPLE_TEXTS` once per row of
  `LT_TEXTS` rather than passing the whole key table in one call.
- No unit tests exist for `LOCK_TABLE` and `UNLOCK_TABLE`. They call the
  `ENQUEUE`/`DEQUEUE` function modules directly and need an injection seam before
  they can be covered.

## [1.0.0] - 2026-01-15

First release in abapGit format, with all six utilities consolidated behind one
global class.

### Added

- **Project 6 — Dynamic Lock.** `LOCK_TABLE` / `UNLOCK_TABLE` on
  `ZCL_ABAP_PROJECTS`, determining primary keys through RTTI and locking either
  via the table's own lock object or the generic `ENQUEUE_E_TABLE`, plus the
  `Z_DYNAMIC_LOCK_UNLOCK` demo report.
- Text symbols replacing hardcoded literals across the reports.
- `ZCL_ABAP_PROJECTS` as the single entry point for the reusable methods
  (`COUNT_SINGLE_MULTIPLE_VALUES`, `ALPHA_CONVERSION`, `SPLIT_TABLE`), with the
  `LTC_EXTERNAL_METHODS` test class.
- MIT licence.

### Changed

- Repository restructured for abapGit (`PREFIX` folder logic, sources under
  `/src/`), replacing the previous numbered plain-text folders.
- `Z_SPLIT_TABLE` call reworked for readability.

## [0.6.0] - 2025-09-04

### Added

- **Project 5 — Dynamic Split of Table into Smaller Ones** (`Z_SPLIT_TABLE`).
- **Project 4 — Dynamic Input/Output Conversion** (`Z_DYNAMIC_CONVERSION`).
- **Project 3 — Dynamic Texts Export** (`Z_DYNAMIC_TEXTS_EXPORT`), downloading
  any SAP text object to XLSX.
- **Project 2 — Dynamic Count of Unique/Multiple Values**
  (`ZCOUNT_SINGLE_MULTIPLE_VALUES`).
- **Project 1 — Dynamic SALV Console** (`Z_SALV_ALV`), displaying any table or
  Excel file through `CL_SALV_TABLE` with a custom toolbar, an SE16N-style detail
  popup and empty-column toggling.
- `abaplint.json` configuration.

### Removed

- Dynamic XML to Internal Table utility.

## [0.1.0] - 2021-01-18

### Added

- Initial repository.

[Unreleased]: https://github.com/greltel/abap-projects/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/greltel/abap-projects/releases/tag/v1.0.0
[0.6.0]: https://github.com/greltel/abap-projects/compare/v0.1.0...v0.6.0
[0.1.0]: https://github.com/greltel/abap-projects/releases/tag/v0.1.0
