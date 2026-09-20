************************************************************************
*   Program name: Z_SPLIT_TABLE
*   Description : Dynamic Split of Table into Smaller Ones
*
*   Created   by: George Drakos
*
************************************************************************
REPORT z_split_table.

PARAMETERS p_seg TYPE i OBLIGATORY DEFAULT 25.

*&----------------------------------------------------------------------*
*& EXECUTABLE CODE
*&----------------------------------------------------------------------*
START-OF-SELECTION.

  SELECT FROM i_companycode
    FIELDS i_companycode~*
    INTO TABLE @DATA(company_codes).

  TRY.
      DATA(chunks) = zcl_abap_projects=>split_table( im_table         = company_codes
                                                     im_split_segment = p_seg ).

      WRITE: / |{ lines( company_codes ) } rows split into { lines( chunks ) } chunks of { p_seg }|.

      LOOP AT chunks ASSIGNING FIELD-SYMBOL(<chunk>).

        ASSIGN <chunk>->* TO FIELD-SYMBOL(<rows>).

        WRITE: / |Chunk { sy-tabix }: { lines( <rows> ) } rows|.

      ENDLOOP.

    CATCH zcx_abap_projects INTO DATA(error).
      MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
