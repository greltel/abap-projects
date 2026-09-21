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
- `Z_SALV_ALV=>SCREEN_PBO` had both pairs of modification groups inverted. `P_DB`
  activated `ID3` (the Excel block) and `P_FILE` activated `ID4` (the database
  block); `P_R1` activated `ID2` and `ID5`, which only the Fiori version uses,
  while `P_R2` activated `ID1`, which only the SAP GUI version uses. Each choice
  now activates its own group, and `ID5` is shown only when a popup is requested.
- `Z_SALV_ALV=>SCREEN_PBO` set `SCREEN-ACTIVE`, `SCREEN-REQUEST` and
  `SCREEN-DISPLAY_3D` from `COND #( )` expressions with no `ELSE`, so every
  element that matched no branch — including every parameter without a `MODIF ID`
  — was reset to the initial value on each PBO. Elements outside the five managed
  groups are now left untouched, and `REQUEST`/`DISPLAY_3D` are set on `T_HITS`
  only.
- All dependencies on foreign application components are gone. `/ACCGO/` (two
  interfaces), `CL_CMS_COMMON` (7 call sites) and `CL_MMIM_MAA_2` (4 call sites)
  were supplying nothing but the literals `'S'`, `'I'`, `'E'`, `8` and `1`, and
  are replaced by named constants in each report. The repository now activates on
  a plain S/4HANA system.
- `LCL_SALV_EDIT=>SET_EDITABLE` and `GET_CONTROL` had their bodies commented out,
  so the edit button and double-click-to-edit did nothing. Both are implemented
  again, against the `IM_` parameter names. `GET_CONTROL` now covers only the
  fullscreen and grid adapters — the two `CL_SALV_TABLE` actually produces here —
  and returns an initial reference for anything else, which `SET_EDITABLE`
  reports instead of failing silently.
- `P_FIEL`, `CHECK_FIELD_EXISTS_IN_TABLE` and `DYNAMIC_WHERE_CLAUSE` typed their
  field parameter as `CHAR5`, silently truncating field names and dropping the
  filter for most fields. All three, and `GET_DATA`'s `IM_FIELD`, are now
  `FIELDNAME`.
- `LCL_SEL_SCREEN=>FIELDS_F4` ran one `SELECT SINGLE` on `DD04T` per component and
  reused an inline `@DATA(scrtext_l)` that was never cleared, so a field without a
  text inherited the previous field's description. The texts are read in one
  `SELECT`, the description comes from a table expression with `OPTIONAL`, and
  components without a data element are kept out of the `FOR ALL ENTRIES` driver
  table — an initial `ROLLNAME` there would have read the whole of `DD04T`. The
  window title is a text symbol instead of a literal.
- `LCL_TEXTS=>POPULATE_TEXTS` called `READ_MULTIPLE_TEXTS` for every text header,
  including the ones `STXH` already reported as having no lines, and discarded
  every failure without a word. Empty headers are skipped outright, and texts that
  could not be read are counted and reported, so an export with blank rows no
  longer looks complete.

### Known issues

- `Z_SALV_ALV` reads any table by name through a fully dynamic
  `SELECT * FROM (table)` and performs no `AUTHORITY-CHECK`. This is deliberate:
  the report is a developer console, and the table name is already restricted by
  whoever can start the program. Anyone installing it on a system with real users
  should restrict the program or its transaction accordingly, the same way `SE16`
  itself is restricted.
- `LOCK_TABLE` and `UNLOCK_TABLE` have no unit tests, also deliberately. The
  reasoning is in `CONTRIBUTING.md` under *Unit tests*.

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
