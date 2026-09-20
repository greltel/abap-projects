************************************************************************
*   Program name: Z_DYNAMIC_LOCK_UNLOCK
*   Description : Dynamic Lock and Unlock of Database Table
*
*   Created   by: George Drakos
*
************************************************************************
REPORT z_dynamic_lock_unlock.

PARAMETERS p_table TYPE tabname    OBLIGATORY DEFAULT 'MARA' MATCHCODE OBJECT dd_dbtb_16.
PARAMETERS p_matnr TYPE mara-matnr OBLIGATORY DEFAULT '000000000000010001'.

*&---------------------------------------------------------------------*
*& EXECUTABLE CODE
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  DATA(material) = VALUE mara( matnr = p_matnr ).

  DATA(lock) = zcl_abap_projects=>lock_table( iv_table_name = p_table
                                              iv_data       = material ).

  IF lock-success = abap_false.
    MESSAGE lock-msg_text TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  WRITE: / 'Locked  :', p_table, p_matnr.

  " ... work with the locked record here ...

  DATA(unlock) = zcl_abap_projects=>unlock_table( iv_table_name = p_table
                                                  iv_data       = material ).

  IF unlock-success = abap_false.
    MESSAGE unlock-msg_text TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  WRITE: / 'Unlocked:', p_table, p_matnr.
