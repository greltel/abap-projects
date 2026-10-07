# Off-stack DDIC stubs

Minimal abapGit-format definitions of the two SAP standard DDIC objects the
unit tests reference that open-abap-core does not ship: `MARA` and `RSTABLE`.
They exist only so the transpiler can resolve these types when the tests run
off-stack; on a real system the standard objects are used.

The data elements the tests use (`VBELN`, `MATNR`, `MANDT`, `ERSDA`) come from
open-abap-core, which only ships objects released for ABAP Cloud (checked
against the SAP cloudification repository). These two stay local because they
are not released:

- `MARA` is `notToBeReleased`, successor `I_PRODUCT`.
- `RSTABLE` is not listed in the cloudification repository.

- Deliberately outside `/src/`, so abapGit never deploys them and abaplint
  never analyses them.
- Loaded as a local library via `libs` in `abap_transpile.json`.
- Each stub carries only what the tests need (key fields, lengths).
