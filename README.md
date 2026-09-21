# ABAP Projects

[![CI](https://github.com/greltel/abap-projects/actions/workflows/ci.yml/badge.svg?branch=Main)](https://github.com/greltel/abap-projects/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/greltel/abap-projects/blob/Main/LICENSE)
![ABAP 7.58](https://img.shields.io/badge/ABAP-7.58-brightgreen)
![S/4HANA 2023](https://img.shields.io/badge/S%2F4HANA-2023%20FPS03-0faaff)
[![Code Statistics](https://img.shields.io/badge/CodeStatistics-abaplint-blue)](https://abaplint.app/stats/greltel/abap-projects)

# Table of contents
1. [ABAP-Projects](#ABAP-Projects)
2. [License](#License)
3. [Contributors-Developers](#Contributors-Developers)
4. [Motivation for Creating the Repository](#Motivation-for-Creating-the-Repository)
5. [Design Goals-Features](#Design-Goals-Features)
6. [Development](#Development)
7. [Project 1 Dynamic SALV Console](#Project-1-Dynamic-SALV-Console)
8. [Project 2 Dynamic Count of Unique-Multiple Values of Internal Table](#Project-2-Dynamic-Count-of-Unique-Multiple-Values-of-Internal-Table)
9. [Project 3 Dynamic Texts Export](#Project-3-Dynamic-Texts-Export)
10. [Project 4 Dynamic Input-Output Convertion](#Project-4-Dynamic-Input-Output-Convertion)
11. [Project 5 Dynamic Split of Table into Smaller Ones](#Project-5-Dynamic-Split-of-Table-into-Smaller-Ones)
12. [Project 6 Dynamic Lock](#Project-6-Dynamic-Lock)

# ABAP-Projects

Repository for Projects based on ABAP.It contains a collection of modern, reusable ABAP utilities and dynamic tools designed to streamline daily development tasks.

# License
This project is licensed under the [MIT License](https://github.com/greltel/abap-projects/blob/Main/LICENSE).

# Contributors-Developers
The repository was created by [George Drakos](https://www.linkedin.com/in/george-drakos/).

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for the coding standards, the unit test and ABAP Doc requirements, and how to run the checks locally.

# Motivation for Creating the Repository

The primary motivation behind this repository is to share knowledge and foster growth within the ABAP community. My goal is to help fellow developers boost their productivity by providing reusable, modern, and clean code solutions.

Since the ABAP ecosystem is niche, I strongly believe in the power of open-source sharing to drive our collective progress. Contributions, suggestions for code optimization, or new project ideas are always welcome.

# Design Goals-Features

* Install via [ABAPGit](http://abapgit.org)
* Modern ABAP syntax, targeting **S/4HANA 2023 FPS03 (ABAP 7.58)**
* Failures are reported through `ZCX_ABAP_PROJECTS`, never swallowed
* ABAP Doc on every public method
* Unit tested — `ZCL_ABAP_PROJECTS` ships with its `LTC_*` test classes
* Static analysis on every push via [abaplint](https://abaplint.org)
* Passed ATC Check Variant S4HANA_READINESS_2023

# Development

Static analysis and the ABAP Unit tests both run on any machine with Node.js 22+, without a SAP system:

```bash
npm ci
npm run lint   # abaplint, targeting v758
npm test       # transpile to JavaScript and run ABAP Unit off-stack
```

`npm test` uses the [abaplint transpiler](https://github.com/abaplint/transpiler) with
[open-abap-core](https://github.com/open-abap/open-abap-core). A few tests cannot pass off-stack
because the runtime does not implement DDIC conversion exits or fill the full DDIC field list;
those are listed with their reason in `ci/offstack-known-gaps.json` and reported as `XFAIL`.
They all pass in ADT.

# Project 1 Dynamic SALV Console

Display any table using cl_salv_Table alv. Scope of this project is to create a cl_salv_table based alv which is
as dynamic as possible. There are no data declarations(wherever possible), no custom screen, no gui status etc.
Also many custom functions have been added to ALV toolbar like custom details screen( se16n inspired ), 
hide/show empty columns of table and edit button. The whole point of this project is to reveal the real potential of 
cl_salv_table based ALV even though there are limitations compared to cl_gui_alv_grid. We call this project Console because
you can use it as a utility to display any table of the system plus display your own Excel file.

<img width="700" height="600" alt="image" src="https://github.com/user-attachments/assets/9156db2a-1a89-41d9-b024-e76215229a77" />

# Project 2 Dynamic Count of Unique-Multiple Values of Internal Table

Use the Static Class Method to Retrieve Unique and Multiple values of Any Table.
Both exported tables are hashed and keyed by the column, with an additional `COUNT` component.
The source table is read in a single pass and never copied.

```abap
  SELECT FROM i_journalentry FIELDS i_journalentry~* INTO TABLE @DATA(lt_table) UP TO 10000 ROWS.

  TRY.
      zcl_abap_projects=>count_single_multiple_values(
        EXPORTING im_table           = lt_table
                  im_column_name     = 'ACCOUNTINGDOCCREATEDBYUSER'
        IMPORTING ex_unique_values   = DATA(unique_values)
                  ex_multiple_values = DATA(multiple_values) ).

      ASSIGN unique_values->*   TO FIELD-SYMBOL(<unique>).
      ASSIGN multiple_values->* TO FIELD-SYMBOL(<multiple>).

    CATCH zcx_abap_projects INTO DATA(error).
      MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
```

# Project 3 Dynamic Texts Export

Download any Text Object of SAP System into Excel File directly.

<img width="700" height="400" alt="image" src="https://github.com/user-attachments/assets/9b9c6bf9-3f41-4bb9-be72-35a9e12e161c" />

# Project 4 Dynamic Input-Output Convertion

Dynamically convert a DDIC value to Input/Output format using the conversion exit of its data element.
A type without a conversion exit is returned unchanged. The input is passed by value, so the same
variable may safely be used for input and output.

```abap
  TRY.
      DATA internal TYPE vbak-vbeln.
      zcl_abap_projects=>alpha_conversion(
        EXPORTING iv_input  = CONV vbak-vbeln( '12345' )
                  im_alpha  = zcl_abap_projects=>s_alpha_conversion-in
        IMPORTING ev_output = internal ).

      DATA external TYPE vbak-vbeln.
      zcl_abap_projects=>alpha_conversion(
        EXPORTING iv_input  = internal
                  im_alpha  = zcl_abap_projects=>s_alpha_conversion-out
        IMPORTING ev_output = external ).

    CATCH zcx_abap_projects INTO DATA(error).
      MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
```

# Project 5 Dynamic Split of Table into Smaller Ones

Split Internal Table into Smaller ones specifying split segments.
Especially useful for parallel processing tasks. The chunks are standard tables
whatever the kind of the source table.

```abap
  SELECT FROM i_companycode
    FIELDS i_companycode~*
    INTO TABLE @DATA(lt_data).

  TRY.
      DATA(chunks) = zcl_abap_projects=>split_table( im_table         = lt_data
                                                     im_split_segment = 25 ).

      LOOP AT chunks ASSIGNING FIELD-SYMBOL(<chunk>).

        ASSIGN <chunk>->* TO FIELD-SYMBOL(<rows>).

      ENDLOOP.

    CATCH zcx_abap_projects INTO DATA(error).
      MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
```

# Project 6 Dynamic Lock

A dynamic locking mechanism that uses RTTI to identify the primary key fields of any table and
locks through the table's own lock object. Switch `iv_enable_specific_lock` off to fall back to
the generic `ENQUEUE_E_TABLE`, in which case the lock argument is assembled by `build_varkey( )`.

A lock that could not be taken is a routine outcome rather than an error, so it comes back in the
result structure — `success` says whether the lock is held, `locked_by` who holds it instead.
Pass the same mode, scope and lock flavour to `unlock_table( )` or the lock will not be released.

```abap
  DATA(material) = VALUE mara( matnr = '000000000000010001' ).

  DATA(lock) = zcl_abap_projects=>lock_table( iv_table_name = 'MARA'
                                              iv_data       = material ).

  IF lock-success = abap_false.
    MESSAGE lock-msg_text TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " ... work with the locked record here ...

  DATA(unlock) = zcl_abap_projects=>unlock_table( iv_table_name = 'MARA'
                                                  iv_data       = material ).
```
