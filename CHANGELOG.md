# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Because this repository ships ABAP source rather than a binary, "breaking"
means a change that alters a method signature, removes an object, or changes
runtime behaviour in a way that requires callers to adapt.

## [Unreleased]

### Added

- Continuous integration on GitHub Actions (`.github/workflows/ci.yml`) with two
  jobs: `abaplint` static analysis, and off-stack ABAP Unit execution.
- Off-stack ABAP Unit pipeline built on the
  [abaplint transpiler](https://github.com/abaplint/transpiler) and
  [open-abap-core](https://github.com/open-abap/open-abap-core), so the tests run
  on any machine with Node.js and no SAP system:
  - `abap_transpile.json` — transpiler configuration.
  - `ci/run_ci.sh` — pipeline driver (`npm test`).
  - `ci/run_unit_tests.mjs` — test runner adding a `SYST` shim, per-test
    isolation, and xfail handling.
  - `ci/offstack-known-gaps.json` — tests that cannot pass off-stack, each with
    the reason. A listed test that fails is reported `XFAIL`; one that starts
    passing is reported `XPASS` and fails the build, so entries cannot rot.
  - `ci/ddic/` — minimal DDIC stubs (`RSTABLE`, `DD25L`, and the data elements
    and domains they need) for types the off-stack runtime has no dictionary for.
- `package.json` with `npm run lint`, `npm test`, `npm run transpile`.
- `CONTRIBUTING.md` — contribution guide covering the coding standards, the unit
  test and ABAP Doc requirements, how to run both checks locally, and the known
  limits of the off-stack runtime.
- `CHANGELOG.md` — this file.
- `.gitignore` for `node_modules/`, `ci/out/` and `/deps/`.

### Changed

- `abaplint.json` now targets **v758** instead of **v702**. At v702 none of the
  modern-syntax sources could be parsed, and because `parser_error` was not
  enabled the parse failures were discarded silently — the configuration
  reported a clean run while analysing nothing. `unused_variables` was switched
  on but found none of the seven unused variables that exist in the code.
- `abaplint.json` rule set extended and split by severity. `Error` rules block
  the build; `Warning` rules are the tracked cleanup backlog and are summarised
  in the CI job summary on every run. Current state: **0 errors, 193 warnings**.
- `ZCL_ABAP_PROJECTS=>COUNT_SINGLE_MULTIPLE_VALUES` — replaced
  `DELETE TABLE <temp> WITH TABLE KEY (im_column_name) = <fs_temp_value>` with
  the equivalent `DELETE TABLE <temp> FROM <fs_temp>`. The temporary table's only
  key is that column and `<fs_temp>` is the row being examined, so the two forms
  select the same row. The dynamic-key form cannot be parsed by abaplint at all
  and blocked both CI jobs.
- Test class `LTC_EXTERNAL_METHODS` — assertions moved from `CL_AUNIT_ASSERT` to
  `CL_ABAP_UNIT_ASSERT` (8 call sites, identical signatures). `CL_AUNIT_ASSERT`
  is obsolete, is not released for ABAP Cloud, and does not exist off-stack.

### Known issues

Open findings from the source review, not yet fixed. Listed newest-first by
severity so they can be picked up in order.

- `Z_SALV_ALV` performs a fully dynamic `SELECT * FROM (table)` driven by user
  input with no `AUTHORITY-CHECK`. Any user who can start the report can read any
  table in the system. Needs an `S_TABU_NAM` / `S_TABU_DIS` check before the
  select, as `SE16N` does.
- `Z_SALV_ALV` depends on three foreign application namespaces for constants that
  are plain literals: `/ACCGO/IF_CCK_DPQS_CONSTANTS` and `/ACCGO/IF_CAS_CONSTANTS`
  (SAP Agricultural Contract Management), `CL_CMS_COMMON` (Collateral Management)
  and `CL_MMIM_MAA_2` (Inventory Management). The `/ACCGO/` add-on is not present
  on a standard S/4HANA system, so the program cannot be activated there.
  `Z_DYNAMIC_TEXTS_EXPORT` uses `CL_CMS_COMMON` for the same purpose.
- `ZCL_ABAP_PROJECTS=>BUILD_VARKEY` has an inverted length guard
  (`IF ( offset + len ) GE varkey_length`). The key is written only when it would
  overflow, so for every normal table nothing is written, `LOCK_TABLE` hits its
  `CHECK varkey IS NOT INITIAL` and returns an initial result — reporting failure
  with no message, having taken no lock. The generic (`IV_ENABLE_SPECIFIC_LOCK =
  ABAP_FALSE`) locking path has therefore never worked.
- `ZCL_ABAP_PROJECTS=>UNLOCK_TABLE` does not forward `IV_ENQMODE` to
  `EXECUTE_SPECIFIC_LOCK`, so the dequeue runs with a blank lock mode and does not
  release a lock taken with mode `E`. The asymmetric scope defaults (`'2'` for
  lock, `'3'` for unlock) need review at the same time.
- `Z_SALV_ALV=>SCREEN_PBO` uses `COND #( … )` with no `ELSE` when setting
  `SCREEN-ACTIVE`, `SCREEN-REQUEST` and `SCREEN-DISPLAY_3D`, so every screen
  element that matches no branch is set to initial — blanking the 3D frame on the
  whole selection screen and hiding every field without a `MODIF ID`. The
  data-source branches are also swapped: selecting the database source activates
  the Excel group (`ID3`) and vice versa.
- `LCL_SALV_EDIT=>SET_EDITABLE` and `GET_CONTROL` are entirely commented out, so
  the edit button and the double-click-to-edit behaviour advertised in the README
  do nothing.
- `LCL_UTILITIES=>CHECK_FIELD_EXISTS_IN_TABLE` and `DYNAMIC_WHERE_CLAUSE` type
  their field parameter as `CHAR5`, and `P_FIEL` on the selection screen is
  `CHAR5` as well. Field names up to 30 characters are silently truncated, so the
  existence check fails and the filter is dropped for most fields.
- `ZCL_ABAP_PROJECTS=>COUNT_SINGLE_MULTIPLE_VALUES` copies the entire source table
  once per row and then deletes from it row by row — O(n²) in both time and
  memory. The example in the README passes 10,000 rows. A single pass over a
  hashed count table is O(n). The inner loop also deletes from the table it is
  looping over, which the ABAP documentation advises against.
- `LCL_SEL_SCREEN=>FIELDS_F4` issues a `SELECT SINGLE` on `DD04T` inside a loop
  over every component of the selected table, and the inline `@DATA(scrtext_l)`
  is not cleared between iterations, so a field without a text inherits the
  previous field's description.
- `LCL_TEXTS=>POPULATE_TEXTS` calls `READ_MULTIPLE_TEXTS` once per row rather than
  passing the whole key table in one call.
- No unit tests exist for `LOCK_TABLE`, `UNLOCK_TABLE` or `BUILD_VARKEY`, and no
  method in `ZCL_ABAP_PROJECTS` carries ABAP Doc.

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
