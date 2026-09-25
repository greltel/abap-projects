# Off-stack DDIC stubs

Minimal abapGit-format definitions of the SAP standard DDIC objects the unit
tests reference (`VBELN`, `MATNR`, `MANDT`, `ERSDA`, `MARA`, `RSTABLE`).
They exist only so the transpiler can resolve these types when the tests run
off-stack; on a real system the standard objects are used.

- Deliberately outside `/src/`, so abapGit never deploys them and abaplint
  never analyses them.
- Loaded as a local library via `libs` in `abap_transpile.json`.
- Each stub carries only what the tests need (key fields, length, CONVEXIT).
