************************************************************************
*   Program name: Z_DYNAMIC_CONVERSION
*   Description : Dynamic Alpha Conversion
*
*   Created   by: George Drakos
*
************************************************************************
REPORT z_dynamic_conversion.

PARAMETERS p_vbeln TYPE vbak-vbeln OBLIGATORY DEFAULT '12345'.

*&---------------------------------------------------------------------*
*& EXECUTABLE CODE
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  TRY.
      DATA internal TYPE vbak-vbeln.
      zcl_abap_projects=>alpha_conversion(
        EXPORTING iv_input  = p_vbeln
                  im_alpha  = zcl_abap_projects=>s_alpha_conversion-in
        IMPORTING ev_output = internal ).

      DATA external TYPE vbak-vbeln.
      zcl_abap_projects=>alpha_conversion(
        EXPORTING iv_input  = internal
                  im_alpha  = zcl_abap_projects=>s_alpha_conversion-out
        IMPORTING ev_output = external ).

      WRITE: / 'Entered :', p_vbeln,
             / 'Internal:', internal,
             / 'External:', external.

    CATCH zcx_abap_projects INTO DATA(error).
      MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
