************************************************************************
*   Program name: ZCOUNT_SINGLE_MULTIPLE_VALUES
*   Description : Count Single and Multiple Values of Internal Table Dynamically
*
*   Created   by: George Drakos
*
************************************************************************
REPORT zcount_single_multiple_values.

PARAMETERS p_col  TYPE string OBLIGATORY DEFAULT 'ACCOUNTINGDOCCREATEDBYUSER' LOWER CASE.
PARAMETERS p_rows TYPE i      OBLIGATORY DEFAULT 10000.

*&---------------------------------------------------------------------*
*& EXECUTABLE CODE
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  SELECT FROM i_journalentry
    FIELDS i_journalentry~*
    INTO TABLE @DATA(journal_entries)
    UP TO @p_rows ROWS.

  TRY.
      zcl_abap_projects=>count_single_multiple_values(
        EXPORTING im_table           = journal_entries
                  im_column_name     = p_col
        IMPORTING ex_unique_values   = DATA(unique_values)
                  ex_multiple_values = DATA(multiple_values) ).

      ASSIGN unique_values->*   TO FIELD-SYMBOL(<unique>).
      ASSIGN multiple_values->* TO FIELD-SYMBOL(<multiple>).

      WRITE: / |Column { p_col } over { lines( journal_entries ) } rows|,
             / |Values occurring once      : { lines( <unique> ) }|,
             / |Values occurring more often: { lines( <multiple> ) }|.

    CATCH zcx_abap_projects INTO DATA(error).
      MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
