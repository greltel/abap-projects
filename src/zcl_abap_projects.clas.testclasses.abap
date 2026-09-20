CLASS ltc_count_values DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_row,
             id   TYPE i,
             text TYPE string,
           END OF ty_row.
    TYPES ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    METHODS count_of
      IMPORTING !table        TYPE REF TO data
                !value        TYPE string
      RETURNING VALUE(result) TYPE i.

    METHODS given_mixed_then_splits_counts FOR TESTING RAISING cx_static_check.
    METHODS given_lowercase_col_then_works FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_col_then_raises  FOR TESTING RAISING cx_static_check.
    METHODS given_empty_tab_then_no_values FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_count_values IMPLEMENTATION.

  METHOD count_of.

    FIELD-SYMBOLS <rows> TYPE ANY TABLE.

    ASSIGN table->* TO <rows>.

    LOOP AT <rows> ASSIGNING FIELD-SYMBOL(<row>).
      ASSIGN COMPONENT 'TEXT'  OF STRUCTURE <row> TO FIELD-SYMBOL(<text>).
      ASSIGN COMPONENT 'COUNT' OF STRUCTURE <row> TO FIELD-SYMBOL(<count>).
      IF <text> = value.
        result = <count>.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD given_mixed_then_splits_counts.

    DATA(rows) = VALUE ty_rows( ( id = 1 text = `A` )
                                ( id = 2 text = `B` )
                                ( id = 3 text = `A` )
                                ( id = 4 text = `C` )
                                ( id = 5 text = `A` ) ).

    zcl_abap_projects=>count_single_multiple_values(
      EXPORTING im_table           = rows
                im_column_name     = `TEXT`
      IMPORTING ex_unique_values   = DATA(unique)
                ex_multiple_values = DATA(multiple) ).

    ASSIGN unique->*   TO FIELD-SYMBOL(<unique>).
    ASSIGN multiple->* TO FIELD-SYMBOL(<multiple>).

    cl_abap_unit_assert=>assert_equals(
      act = lines( <unique> )
      exp = 2
      msg = `B and C occur once each, so two unique values are expected` ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( <multiple> )
      exp = 1
      msg = `Only A repeats, so one multiple value is expected` ).

    cl_abap_unit_assert=>assert_equals(
      act = count_of( table = multiple value = `A` )
      exp = 3
      msg = `A occurs three times and the COUNT column must say so` ).

  ENDMETHOD.


  METHOD given_lowercase_col_then_works.

    DATA(rows) = VALUE ty_rows( ( id = 1 text = `A` )
                                ( id = 2 text = `B` ) ).

    zcl_abap_projects=>count_single_multiple_values(
      EXPORTING im_table           = rows
                im_column_name     = `text`
      IMPORTING ex_unique_values   = DATA(unique)
                ex_multiple_values = DATA(multiple) ).

    ASSIGN unique->* TO FIELD-SYMBOL(<unique>).

    cl_abap_unit_assert=>assert_equals(
      act = lines( <unique> )
      exp = 2
      msg = `A lower case column name must be accepted, not silently ignored` ).

  ENDMETHOD.


  METHOD given_unknown_col_then_raises.

    DATA(rows) = VALUE ty_rows( ( id = 1 text = `A` ) ).

    TRY.
        zcl_abap_projects=>count_single_multiple_values(
          EXPORTING im_table           = rows
                    im_column_name     = `DOES_NOT_EXIST`
          IMPORTING ex_unique_values   = DATA(unique)
                    ex_multiple_values = DATA(multiple) ).

        cl_abap_unit_assert=>fail(
          msg = `An unknown column must be reported, not returned as two unbound refs` ).

      CATCH zcx_abap_projects INTO DATA(error).
        cl_abap_unit_assert=>assert_equals(
          act = error->if_t100_message~t100key-msgno
          exp = zcx_abap_projects=>unknown_column-msgno
          msg = `Expected unknown_column rather than another failure` ).
    ENDTRY.

  ENDMETHOD.


  METHOD given_empty_tab_then_no_values.

    DATA rows TYPE ty_rows.

    zcl_abap_projects=>count_single_multiple_values(
      EXPORTING im_table           = rows
                im_column_name     = `TEXT`
      IMPORTING ex_unique_values   = DATA(unique)
                ex_multiple_values = DATA(multiple) ).

    cl_abap_unit_assert=>assert_bound(
      act = unique
      msg = `An empty input must still return a usable, empty result table` ).

    ASSIGN unique->* TO FIELD-SYMBOL(<unique>).

    cl_abap_unit_assert=>assert_initial(
      act = <unique>
      msg = `An empty input has no unique values` ).

  ENDMETHOD.

ENDCLASS.


CLASS ltc_alpha_conversion DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS given_alpha_in_then_padded    FOR TESTING RAISING cx_static_check.
    METHODS given_alpha_out_then_stripped FOR TESTING RAISING cx_static_check.
    METHODS given_same_var_then_converted FOR TESTING RAISING cx_static_check.
    METHODS given_no_exit_then_unchanged  FOR TESTING RAISING cx_static_check.
    METHODS given_structure_then_raises   FOR TESTING RAISING cx_static_check.
    METHODS given_dir_other_then_raises   FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_alpha_conversion IMPLEMENTATION.

  METHOD given_alpha_in_then_padded.

    DATA order TYPE vbeln.

    zcl_abap_projects=>alpha_conversion(
      EXPORTING iv_input  = CONV vbeln( '123' )
                im_alpha  = zcl_abap_projects=>s_alpha_conversion-in
      IMPORTING ev_output = order ).

    cl_abap_unit_assert=>assert_equals(
      act = order
      exp = '0000000123'
      msg = `ALPHA INPUT must left pad the value with zeros` ).

  ENDMETHOD.


  METHOD given_alpha_out_then_stripped.

    DATA order TYPE vbeln.

    zcl_abap_projects=>alpha_conversion(
      EXPORTING iv_input  = CONV vbeln( '0000000123' )
                im_alpha  = zcl_abap_projects=>s_alpha_conversion-out
      IMPORTING ev_output = order ).

    cl_abap_unit_assert=>assert_equals(
      act = order
      exp = '123'
      msg = `ALPHA OUTPUT must strip the leading zeros` ).

  ENDMETHOD.


  METHOD given_same_var_then_converted.

    DATA(order) = CONV vbeln( '123' ).

    zcl_abap_projects=>alpha_conversion(
      EXPORTING iv_input  = order
                im_alpha  = zcl_abap_projects=>s_alpha_conversion-in
      IMPORTING ev_output = order ).

    cl_abap_unit_assert=>assert_equals(
      act = order
      exp = '0000000123'
      msg = `One variable used as input and output must still convert correctly` ).

  ENDMETHOD.


  METHOD given_no_exit_then_unchanged.

    DATA result TYPE string.

    zcl_abap_projects=>alpha_conversion(
      EXPORTING iv_input  = `TEST`
                im_alpha  = zcl_abap_projects=>s_alpha_conversion-in
      IMPORTING ev_output = result ).

    cl_abap_unit_assert=>assert_equals(
      act = result
      exp = `TEST`
      msg = `A type without a conversion exit must come back untouched` ).

  ENDMETHOD.


  METHOD given_structure_then_raises.

    DATA result TYPE string.

    TRY.
        zcl_abap_projects=>alpha_conversion(
          EXPORTING iv_input  = VALUE t000( )
                    im_alpha  = zcl_abap_projects=>s_alpha_conversion-in
          IMPORTING ev_output = result ).

        cl_abap_unit_assert=>fail(
          msg = `A structure has no conversion exit and must be refused, not dumped` ).

      CATCH zcx_abap_projects INTO DATA(error).
        cl_abap_unit_assert=>assert_equals(
          act = error->if_t100_message~t100key-msgno
          exp = zcx_abap_projects=>not_an_elementary_type-msgno
          msg = `Expected not_an_elementary_type` ).
    ENDTRY.

  ENDMETHOD.


  METHOD given_dir_other_then_raises.

    DATA result TYPE vbeln.

    TRY.
        zcl_abap_projects=>alpha_conversion(
          EXPORTING iv_input  = CONV vbeln( '123' )
                    im_alpha  = zcl_abap_projects=>s_alpha_conversion-other
          IMPORTING ev_output = result ).

        cl_abap_unit_assert=>fail(
          msg = `Direction other must not silently fall back to INPUT` ).

      CATCH zcx_abap_projects INTO DATA(error).
        cl_abap_unit_assert=>assert_equals(
          act = error->if_t100_message~t100key-msgno
          exp = zcx_abap_projects=>unknown_direction-msgno
          msg = `Expected unknown_direction` ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.


CLASS ltc_split_table DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_row,
             id TYPE i,
           END OF ty_row.
    TYPES ty_rows        TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    TYPES ty_sorted_rows TYPE SORTED TABLE OF ty_row WITH NON-UNIQUE KEY id.

    METHODS rows_in
      IMPORTING !chunk        TYPE REF TO data
      RETURNING VALUE(result) TYPE i.

    METHODS given_exact_div_then_n_chunks FOR TESTING RAISING cx_static_check.
    METHODS given_rest_then_last_is_short FOR TESTING RAISING cx_static_check.
    METHODS given_zero_segment_then_raise FOR TESTING RAISING cx_static_check.
    METHODS given_sorted_tab_then_splits  FOR TESTING RAISING cx_static_check.
    METHODS given_empty_tab_then_no_chunk FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_split_table IMPLEMENTATION.

  METHOD rows_in.

    FIELD-SYMBOLS <rows> TYPE ANY TABLE.

    ASSIGN chunk->* TO <rows>.
    result = lines( <rows> ).

  ENDMETHOD.


  METHOD given_exact_div_then_n_chunks.

    DATA(rows) = VALUE ty_rows( FOR i = 1 WHILE i <= 9 ( id = i ) ).

    DATA(chunks) = zcl_abap_projects=>split_table( im_table         = rows
                                                   im_split_segment = 3 ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( chunks )
      exp = 3
      msg = `Nine rows in segments of three must give exactly three chunks` ).

    cl_abap_unit_assert=>assert_equals(
      act = rows_in( chunks[ 3 ] )
      exp = 3
      msg = `An exact division must not leave a short last chunk` ).

  ENDMETHOD.


  METHOD given_rest_then_last_is_short.

    DATA(rows) = VALUE ty_rows( FOR i = 1 WHILE i <= 10 ( id = i ) ).

    DATA(chunks) = zcl_abap_projects=>split_table( im_table         = rows
                                                   im_split_segment = 3 ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( chunks )
      exp = 4
      msg = `Ten rows in segments of three must give four chunks` ).

    cl_abap_unit_assert=>assert_equals(
      act = rows_in( chunks[ 4 ] )
      exp = 1
      msg = `The remainder belongs in the last chunk` ).

  ENDMETHOD.


  METHOD given_zero_segment_then_raise.

    DATA(rows) = VALUE ty_rows( ( id = 1 ) ).

    TRY.
        zcl_abap_projects=>split_table( im_table         = rows
                                        im_split_segment = 0 ).

        cl_abap_unit_assert=>fail(
          msg = `A segment size of zero used to raise CX_SY_ZERODIVIDE` ).

      CATCH zcx_abap_projects INTO DATA(error).
        cl_abap_unit_assert=>assert_equals(
          act = error->if_t100_message~t100key-msgno
          exp = zcx_abap_projects=>invalid_segment_size-msgno
          msg = `Expected invalid_segment_size` ).
    ENDTRY.

  ENDMETHOD.


  METHOD given_sorted_tab_then_splits.

    DATA(rows) = VALUE ty_sorted_rows( FOR i = 1 WHILE i <= 5 ( id = i ) ).

    DATA(chunks) = zcl_abap_projects=>split_table( im_table         = rows
                                                   im_split_segment = 2 ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( chunks )
      exp = 3
      msg = `A sorted input must be split, not walk into an unassigned field symbol` ).

    cl_abap_unit_assert=>assert_equals(
      act = rows_in( chunks[ 1 ] )
      exp = 2
      msg = `The first chunk of a sorted input must hold a full segment` ).

  ENDMETHOD.


  METHOD given_empty_tab_then_no_chunk.

    DATA rows TYPE ty_rows.

    DATA(chunks) = zcl_abap_projects=>split_table( im_table         = rows
                                                   im_split_segment = 3 ).

    cl_abap_unit_assert=>assert_initial(
      act = chunks
      msg = `An empty input produces no chunks` ).

  ENDMETHOD.

ENDCLASS.


CLASS ltc_build_varkey DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    CONSTANTS test_material TYPE matnr VALUE '000000000000010001'.

    METHODS given_mara_then_key_not_empty FOR TESTING RAISING cx_static_check.
    METHODS given_matnr_then_key_holds_it FOR TESTING RAISING cx_static_check.
    METHODS given_absent_key_then_initial FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_build_varkey IMPLEMENTATION.

  METHOD given_mara_then_key_not_empty.

    DATA(varkey) = zcl_abap_projects=>build_varkey(
                     iv_table_name = 'MARA'
                     iv_data       = VALUE mara( matnr = test_material ) ).

    cl_abap_unit_assert=>assert_not_initial(
      act = varkey
      msg = `The length guard was inverted, so the key came back empty and nothing was locked` ).

  ENDMETHOD.


  METHOD given_matnr_then_key_holds_it.

    DATA(varkey) = zcl_abap_projects=>build_varkey(
                     iv_table_name = 'MARA'
                     iv_data       = VALUE mara( matnr = test_material ) ).

    cl_abap_unit_assert=>assert_equals(
      act = condense( CONV string( varkey ) )
      exp = CONV string( test_material )
      msg = `MATNR is the only non client key field, so it is the whole lock argument` ).

  ENDMETHOD.


  METHOD given_absent_key_then_initial.

    TYPES: BEGIN OF ty_no_key,
             ersda TYPE ersda,
           END OF ty_no_key.

    DATA(varkey) = zcl_abap_projects=>build_varkey( iv_table_name = 'MARA'
                                                    iv_data       = VALUE ty_no_key( ) ).

    cl_abap_unit_assert=>assert_initial(
      act = varkey
      msg = `A key field absent from the structure leaves its slot blank` ).

  ENDMETHOD.

ENDCLASS.
