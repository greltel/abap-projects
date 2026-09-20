"! <p class="shorttext synchronized" lang="EN">Reusable dynamic ABAP utilities</p>
"!
"! Table analysis, DDIC conversion and generic table locking, all driven by
"! runtime type information so they work on any table.
"!
"! Programming errors are raised as <em>zcx_abap_projects</em>. A lock that
"! simply could not be taken is a routine outcome, not an error, and comes
"! back in the result structure instead.
CLASS zcl_abap_projects DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES: BEGIN OF t_lock_result,
             success   TYPE abap_boolean,
             locked_by TYPE syst-uname,
             msg_text  TYPE string,
           END OF t_lock_result.

    TYPES:
      BEGIN OF ENUM t_alpha_conversion STRUCTURE s_alpha_conversion BASE TYPE char1,
        in    VALUE 1,
        out   VALUE 2,
        other VALUE IS INITIAL,
      END OF ENUM t_alpha_conversion STRUCTURE s_alpha_conversion.

    TYPES t_splitted_table TYPE STANDARD TABLE OF REF TO data WITH EMPTY KEY.

    "! <p class="shorttext synchronized" lang="EN">Count unique and repeated values</p>
    "!
    "! Splits the distinct values of one column into those occurring exactly
    "! once and those occurring more than once. Both exported tables are
    "! hashed, keyed by the column, and carry an additional COUNT component.
    "! One pass over the source; the input table is never copied.
    "!
    "! @parameter im_table           | Any internal table with a flat row type.
    "! @parameter im_column_name     | Column to count by. Case is irrelevant.
    "! @parameter ex_unique_values   | Values seen exactly once, COUNT always 1.
    "! @parameter ex_multiple_values | Values seen more than once, with their count.
    "! @raising   zcx_abap_projects  | The column is missing from the row type,
    "!                                 or it is a structure or table rather than
    "!                                 an elementary field.
    CLASS-METHODS count_single_multiple_values
      IMPORTING !im_table           TYPE ANY TABLE
                !im_column_name     TYPE string
      EXPORTING !ex_unique_values   TYPE REF TO data
                !ex_multiple_values TYPE REF TO data
      RAISING   zcx_abap_projects.

    "! <p class="shorttext synchronized" lang="EN">Apply a field DDIC conversion exit</p>
    "!
    "! Converts a value between its internal and external representation using
    "! the conversion exit of its data element, ALPHA or any other. A type
    "! without a conversion exit comes back unchanged, which is the expected
    "! outcome rather than a failure.
    "!
    "! The input is passed by value, so the same variable may safely be used
    "! for both input and output.
    "!
    "! @parameter iv_input          | Value to convert.
    "! @parameter im_alpha          | Direction. Passing <em>other</em> is refused
    "!                                rather than treated as INPUT.
    "! @parameter ev_output         | Converted value, or the input unchanged.
    "!                                Left equal to the input if the exit fails.
    "! @raising   zcx_abap_projects | The input is not an elementary field, the
    "!                                direction is <em>other</em>, or the
    "!                                conversion exit rejected the value.
    CLASS-METHODS alpha_conversion
      IMPORTING VALUE(iv_input) TYPE any
                !im_alpha       TYPE t_alpha_conversion
      EXPORTING !ev_output      TYPE any
      RAISING   zcx_abap_projects.

    "! <p class="shorttext synchronized" lang="EN">Split a table into fixed size chunks</p>
    "!
    "! Useful for handing equal portions of work to parallel processes. The
    "! chunks are standard tables whatever the kind of the source table.
    "!
    "! @parameter im_table                | Table to split. Any table kind.
    "! @parameter im_split_segment        | Rows per chunk. Must be positive.
    "! @parameter re_splitted_table       | One data reference per chunk, in
    "!                                      source order. Empty for an empty input.
    "! @raising   zcx_abap_projects       | Segment size is zero or negative.
    CLASS-METHODS split_table
      IMPORTING !im_table                TYPE ANY TABLE
                !im_split_segment        TYPE i DEFAULT 100
      RETURNING VALUE(re_splitted_table) TYPE t_splitted_table
      RAISING   zcx_abap_projects.

    "! <p class="shorttext synchronized" lang="EN">Lock argument for ENQUEUE_E_TABLE</p>
    "!
    "! Writes the key field values of a table one after another into the 120
    "! character lock argument that the generic table enqueue expects. Public
    "! so it can be used directly against ENQUEUE_E_TABLE, and so it can be
    "! tested without reaching into the class.
    "!
    "! A key field that is absent from the supplied structure leaves its slot
    "! blank, which widens the lock to every value of that field.
    "!
    "! @parameter iv_table_name     | Table whose key layout is used.
    "! @parameter iv_data           | Structure holding the key values. Extra
    "!                                components are ignored, so a full table
    "!                                row can be passed as is.
    "! @parameter re_varkey         | The assembled lock argument.
    "! @raising   zcx_abap_projects | A key field is not character like and
    "!                                cannot be placed in the argument, or the
    "!                                key does not fit in 120 characters.
    CLASS-METHODS build_varkey
      IMPORTING !iv_table_name   TYPE tabname
                !iv_data         TYPE any
      RETURNING VALUE(re_varkey) TYPE rstable-varkey
      RAISING   zcx_abap_projects.

    "! <p class="shorttext synchronized" lang="EN">Lock the records matching the key</p>
    "!
    "! Pass the same mode, scope and lock flavour to <em>unlock_table</em>, or
    "! the lock will not be released.
    "!
    "! @parameter iv_table_name           | Table to lock.
    "! @parameter iv_data                 | Structure holding the key values.
    "! @parameter iv_scope                | 1 this program, 2 the update task,
    "!                                      3 both. Scope 2 is released by the
    "!                                      update task, not by unlock_table.
    "! @parameter iv_wait                 | Retry for the configured period
    "!                                      instead of failing immediately.
    "! @parameter iv_enqmode              | E exclusive, S shared, X cumulative.
    "! @parameter iv_enable_specific_lock | Use the lock object of the table.
    "!                                      Switch off to use the generic
    "!                                      ENQUEUE_E_TABLE instead.
    "! @parameter re_result               | Whether the lock is held, and which
    "!                                      user holds it if it is not.
    CLASS-METHODS lock_table
      IMPORTING !iv_table_name           TYPE tabname
                !iv_data                 TYPE any
                !iv_scope                TYPE char1        DEFAULT '1'
                !iv_wait                 TYPE abap_boolean DEFAULT abap_false
                !iv_enqmode              TYPE enqmode      DEFAULT 'E'
                !iv_enable_specific_lock TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(re_result)         TYPE t_lock_result.

    "! <p class="shorttext synchronized" lang="EN">Release a lock taken by lock_table</p>
    "!
    "! Mode, scope and lock flavour must match the call that took the lock.
    "!
    "! @parameter iv_table_name           | Table to unlock.
    "! @parameter iv_data                 | Structure holding the key values.
    "! @parameter iv_enqmode              | Must match the mode used to lock.
    "! @parameter iv_scope                | Must match the scope used to lock.
    "! @parameter iv_enable_specific_lock | Must match the lock call.
    "! @parameter re_result               | Whether the lock was released.
    CLASS-METHODS unlock_table
      IMPORTING !iv_table_name           TYPE tabname
                !iv_data                 TYPE any
                !iv_enqmode              TYPE enqmode      DEFAULT 'E'
                !iv_scope                TYPE char1        DEFAULT '1'
                !iv_enable_specific_lock TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(re_result)         TYPE t_lock_result.

  PRIVATE SECTION.

    CONSTANTS varkey_length TYPE i VALUE 120.

    CLASS-METHODS key_fields
      IMPORTING !iv_table_name   TYPE tabname
      RETURNING VALUE(re_fields) TYPE ddfields.

    CLASS-METHODS execute_specific_lock
      IMPORTING !iv_table_name   TYPE tabname
                !iv_data         TYPE any
                !iv_scope        TYPE char1
                !iv_enqmode      TYPE enqmode
                !iv_wait         TYPE abap_boolean DEFAULT abap_false
                !iv_unlock       TYPE abap_boolean DEFAULT abap_false
      RETURNING VALUE(re_result) TYPE t_lock_result.

    CLASS-METHODS message_text
      IMPORTING !textid        LIKE if_t100_message=>t100key
                !object_name   TYPE string
                !detail        TYPE string OPTIONAL
      RETURNING VALUE(re_text) TYPE string.

ENDCLASS.

CLASS zcl_abap_projects IMPLEMENTATION.

  METHOD count_single_multiple_values.

    CONSTANTS count_column TYPE abap_compname VALUE 'COUNT'.

    FIELD-SYMBOLS <unique>   TYPE HASHED TABLE.
    FIELD-SYMBOLS <multiple> TYPE HASHED TABLE.
    FIELD-SYMBOLS <counters> TYPE HASHED TABLE.
    FIELD-SYMBOLS <count>    TYPE i.

    DATA counters    TYPE REF TO data.
    DATA counter_row TYPE REF TO data.

    DATA(column) = to_upper( im_column_name ).

    DATA(row_type) = CAST cl_abap_structdescr(
                       CAST cl_abap_tabledescr(
                         cl_abap_tabledescr=>describe_by_data( im_table ) )->get_table_line_type( ) ).

    IF NOT line_exists( row_type->components[ name = column ] ).
      RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>unknown_column
                                             object_name = column ).
    ENDIF.

    DATA(column_type) = row_type->get_component_type( column ).

    " A structure or table column cannot carry the hashed key of the result.
    IF column_type->kind <> cl_abap_typedescr=>kind_elem.
      RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>not_an_elementary_type
                                             object_name = column ).
    ENDIF.

    TRY.
        DATA(result_row) = cl_abap_structdescr=>create(
          VALUE cl_abap_structdescr=>component_table(
            ( name = column       type = column_type )
            ( name = count_column type = cl_abap_elemdescr=>get_i( ) ) ) ).

        DATA(result_table) = cl_abap_tabledescr=>create(
          p_line_type  = result_row
          p_table_kind = cl_abap_tabledescr=>tablekind_hashed
          p_unique     = abap_true
          p_key        = VALUE abap_keydescr_tab( ( name = column ) )
          p_key_kind   = cl_abap_tabledescr=>keydefkind_user ).

      CATCH cx_sy_struct_creation cx_sy_table_creation INTO DATA(type_error).
        RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>not_an_elementary_type
                                               previous    = type_error
                                               object_name = column ).
    ENDTRY.

    CREATE DATA ex_unique_values   TYPE HANDLE result_table.
    CREATE DATA ex_multiple_values TYPE HANDLE result_table.
    CREATE DATA counters           TYPE HANDLE result_table.
    CREATE DATA counter_row        TYPE HANDLE result_row.

    ASSIGN ex_unique_values->*   TO <unique>.
    ASSIGN ex_multiple_values->* TO <multiple>.
    ASSIGN counters->*           TO <counters>.
    ASSIGN counter_row->*        TO FIELD-SYMBOL(<counter_row>).

    ASSIGN COMPONENT column       OF STRUCTURE <counter_row> TO FIELD-SYMBOL(<new_value>).
    ASSIGN COMPONENT count_column OF STRUCTURE <counter_row> TO FIELD-SYMBOL(<new_count>).

    " One pass with hashed counters. The previous version copied the whole
    " source table once per row and then deleted from the copy row by row.
    LOOP AT im_table ASSIGNING FIELD-SYMBOL(<row>).

      ASSIGN COMPONENT column OF STRUCTURE <row> TO FIELD-SYMBOL(<value>).

      READ TABLE <counters> ASSIGNING FIELD-SYMBOL(<counter>)
           WITH TABLE KEY (column) = <value>.

      IF sy-subrc = 0.
        ASSIGN COMPONENT count_column OF STRUCTURE <counter> TO <count>.
        <count> = <count> + 1.
      ELSE.
        <new_value> = <value>.
        <new_count> = 1.
        INSERT <counter_row> INTO TABLE <counters>.
      ENDIF.

    ENDLOOP.

    LOOP AT <counters> ASSIGNING <counter>.

      ASSIGN COMPONENT count_column OF STRUCTURE <counter> TO <count>.

      IF <count> = 1.
        INSERT <counter> INTO TABLE <unique>.
      ELSE.
        INSERT <counter> INTO TABLE <multiple>.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD alpha_conversion.

    " The input is the right answer for a type with no conversion exit, and
    " the value to fall back to when the exit rejects it.
    ev_output = iv_input.

    DATA(type) = cl_abap_typedescr=>describe_by_data( iv_input ).

    " Guarded: casting straight to cl_abap_elemdescr used to dump with
    " CX_SY_MOVE_CAST_ERROR when handed a structure or a table.
    IF type->kind <> cl_abap_typedescr=>kind_elem.
      RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>not_an_elementary_type
                                             object_name = |{ type->absolute_name }| ).
    ENDIF.

    DATA(suffix) = SWITCH string( im_alpha
                                  WHEN s_alpha_conversion-in  THEN `INPUT`
                                  WHEN s_alpha_conversion-out THEN `OUTPUT`
                                  ELSE `` ).

    " Converting the wrong way round is worse than being told the direction
    " is missing, which is what the previous ELSE branch did.
    IF suffix IS INITIAL.
      RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>unknown_direction
                                             object_name = |{ im_alpha }| ).
    ENDIF.

    DATA(element) = CAST cl_abap_elemdescr( type ).
    IF element->is_ddic_type( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(conversion_exit) = element->get_ddic_field( )-convexit.
    IF conversion_exit IS INITIAL.
      RETURN.
    ENDIF.

    DATA(function) = to_upper( |CONVERSION_EXIT_{ conversion_exit }_{ suffix }| ).

    TRY.
        CALL FUNCTION function
          EXPORTING
            input         = iv_input
          IMPORTING
            output        = ev_output
          EXCEPTIONS
            error_message = 1
            OTHERS        = 2.

        " sy-subrc was never checked, so a rejected value left whatever the
        " function module had written half way through.
        IF sy-subrc <> 0.
          ev_output = iv_input.
          RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>conversion_failed
                                                 object_name = function
                                                 detail      = |sy-subrc = { sy-subrc }| ).
        ENDIF.

      CATCH cx_sy_dyn_call_error INTO DATA(call_error).
        ev_output = iv_input.
        RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>conversion_failed
                                               previous    = call_error
                                               object_name = function
                                               detail      = call_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD split_table.

    FIELD-SYMBOLS <chunk> TYPE STANDARD TABLE.

    DATA chunk TYPE REF TO data.

    " MOD 0 used to raise CX_SY_ZERODIVIDE on the first row.
    IF im_split_segment <= 0.
      RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>invalid_segment_size
                                             object_name = |{ im_split_segment }| ).
    ENDIF.

    IF im_table IS INITIAL.
      RETURN.
    ENDIF.

    " The chunks are standard tables whatever the source is, so a sorted or
    " hashed input no longer walks into an unassigned field symbol.
    TRY.
        DATA(chunk_type) = cl_abap_tabledescr=>create(
          p_line_type  = CAST cl_abap_tabledescr(
                           cl_abap_tabledescr=>describe_by_data( im_table ) )->get_table_line_type( )
          p_table_kind = cl_abap_tabledescr=>tablekind_std ).

      CATCH cx_sy_table_creation INTO DATA(type_error).
        RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>not_an_elementary_type
                                               previous    = type_error
                                               object_name = |{ im_split_segment }| ).
    ENDTRY.

    DATA(row_number) = 0.

    LOOP AT im_table ASSIGNING FIELD-SYMBOL(<row>).

      IF row_number MOD im_split_segment = 0.
        CREATE DATA chunk TYPE HANDLE chunk_type.
        INSERT chunk INTO TABLE re_splitted_table.
        ASSIGN chunk->* TO <chunk>.
      ENDIF.

      INSERT <row> INTO TABLE <chunk>.
      row_number = row_number + 1.

    ENDLOOP.

  ENDMETHOD.


  METHOD build_varkey.

    DATA(offset) = 0.

    LOOP AT key_fields( iv_table_name ) INTO DATA(field).

      DATA(length) = CONV i( field-leng ).

      " A packed or integer key would silently misalign every field after
      " it, so it is refused rather than producing a wrong lock argument.
      IF field-inttype NA `CNDT`.
        RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>unsupported_key_type
                                               object_name = |{ iv_table_name }-{ field-fieldname }| ).
      ENDIF.

      IF offset + length > varkey_length.
        RAISE EXCEPTION NEW zcx_abap_projects( textid      = zcx_abap_projects=>key_too_long
                                               object_name = |{ iv_table_name }| ).
      ENDIF.

      ASSIGN COMPONENT field-fieldname OF STRUCTURE iv_data TO FIELD-SYMBOL(<value>).
      IF sy-subrc = 0.
        " The comparison here used to be GE, so the value was written only
        " when it would overrun the field, never for a key that fits.
        re_varkey+offset(length) = <value>.
      ENDIF.

      offset = offset + length.

    ENDLOOP.

  ENDMETHOD.


  METHOD key_fields.

    " describe_by_name and get_ddic_field_list both signal through classic
    " exceptions rather than class based ones, so sy-subrc is what has to be
    " read. Called functionally they would short dump on an unknown name.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING  p_name         = iv_table_name
      RECEIVING  p_descr_ref    = DATA(type)
      EXCEPTIONS type_not_found = 1
                 OTHERS         = 2 ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    TRY.
        DATA(structure) = CAST cl_abap_structdescr( type ).
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.

    structure->get_ddic_field_list(
      RECEIVING  p_field_list = DATA(ddic_fields)
      EXCEPTIONS not_found    = 1
                 no_ddic_type = 2
                 OTHERS       = 3 ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Excluded by data type, not by the name MANDT: the client field is not
    " part of a lock argument and is not always called MANDT.
    re_fields = VALUE #( FOR field IN ddic_fields
                         WHERE ( keyflag = abap_true AND datatype <> 'CLNT' )
                         ( field ) ).

  ENDMETHOD.


  METHOD message_text.

    re_text = NEW zcx_abap_projects( textid      = textid
                                     object_name = object_name
                                     detail      = detail )->get_text( ).

  ENDMETHOD.


  METHOD lock_table.

    IF iv_enable_specific_lock = abap_true.
      re_result = execute_specific_lock( iv_table_name = iv_table_name
                                         iv_data       = iv_data
                                         iv_scope      = iv_scope
                                         iv_wait       = iv_wait
                                         iv_enqmode    = iv_enqmode
                                         iv_unlock     = abap_false ).
      RETURN.
    ENDIF.

    TRY.
        DATA(varkey) = build_varkey( iv_table_name = iv_table_name
                                     iv_data       = iv_data ).
      CATCH zcx_abap_projects INTO DATA(key_error).
        re_result = VALUE #( success  = abap_false
                             msg_text = key_error->get_text( ) ).
        RETURN.
    ENDTRY.

    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = iv_enqmode
        tabname        = iv_table_name
        varkey         = varkey
        _scope         = iv_scope
        _wait          = iv_wait
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        error_message  = 3
        OTHERS         = 4.

    re_result = COND #(
      WHEN sy-subrc = 0
        THEN VALUE #( success = abap_true )
      WHEN sy-subrc = 1
        THEN VALUE #( success   = abap_false
                      locked_by = sy-msgv1
                      msg_text  = message_text( textid      = zcx_abap_projects=>foreign_lock
                                                object_name = |{ iv_table_name }|
                                                detail      = |{ sy-msgv1 }| ) )
      ELSE VALUE #( success  = abap_false
                    msg_text = message_text( textid      = zcx_abap_projects=>lock_failed
                                             object_name = |{ iv_table_name }| ) ) ).

  ENDMETHOD.


  METHOD unlock_table.

    IF iv_enable_specific_lock = abap_true.
      " iv_enqmode was not forwarded here, so the dequeue ran with a blank
      " mode and never released a lock taken in mode E.
      re_result = execute_specific_lock( iv_table_name = iv_table_name
                                         iv_data       = iv_data
                                         iv_scope      = iv_scope
                                         iv_enqmode    = iv_enqmode
                                         iv_unlock     = abap_true ).
      RETURN.
    ENDIF.

    TRY.
        DATA(varkey) = build_varkey( iv_table_name = iv_table_name
                                     iv_data       = iv_data ).
      CATCH zcx_abap_projects INTO DATA(key_error).
        re_result = VALUE #( success  = abap_false
                             msg_text = key_error->get_text( ) ).
        RETURN.
    ENDTRY.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable  = iv_enqmode
        tabname       = iv_table_name
        varkey        = varkey
        _scope        = iv_scope
      EXCEPTIONS
        error_message = 1
        OTHERS        = 2.

    re_result = COND #(
      WHEN sy-subrc = 0
        THEN VALUE #( success = abap_true )
      ELSE VALUE #( success  = abap_false
                    msg_text = message_text( textid      = zcx_abap_projects=>unlock_failed
                                             object_name = |{ iv_table_name }| ) ) ).

  ENDMETHOD.


  METHOD execute_specific_lock.

    CONSTANTS active_object    TYPE as4local VALUE 'A'.
    CONSTANTS lock_object_type TYPE aggtype  VALUE 'E'.

    DATA parameters      TYPE abap_func_parmbind_tab.
    DATA exception_table TYPE abap_func_excpbind_tab.

    " A root table may carry more than one lock object. ORDER BY makes the
    " choice deterministic rather than whatever the database returns first.
    SELECT FROM dd25l
      FIELDS viewname
      WHERE roottab  = @iv_table_name
        AND as4local = @active_object
        AND aggtype  = @lock_object_type
      ORDER BY viewname
      INTO TABLE @DATA(lock_objects)
      UP TO 1 ROWS.

    " INTO TABLE @DATA( ) builds a table of one-component structures, so the
    " component has to be named even though only one field was selected.
    DATA(lock_object) = VALUE #( lock_objects[ 1 ]-viewname OPTIONAL ).

    IF lock_object IS INITIAL.
      re_result = VALUE #( success  = abap_false
                           msg_text = message_text( textid      = zcx_abap_projects=>no_lock_object
                                                    object_name = |{ iv_table_name }| ) ).
      RETURN.
    ENDIF.

    DATA(function) = |{ COND string( WHEN iv_unlock = abap_true
                                     THEN `DEQUEUE_`
                                     ELSE `ENQUEUE_` ) }{ lock_object }|.

    LOOP AT key_fields( iv_table_name ) INTO DATA(field).

      ASSIGN COMPONENT field-fieldname OF STRUCTURE iv_data TO FIELD-SYMBOL(<value>).
      CHECK sy-subrc = 0.

      " Every supplied key field is passed, including an initial one. The
      " previous version skipped initial values, which turned them into
      " wildcards and locked more records than the caller asked for.
      INSERT VALUE #( name  = field-fieldname
                      kind  = abap_func_exporting
                      value = REF #( <value> ) ) INTO TABLE parameters.

    ENDLOOP.

    INSERT VALUE #( name  = '_SCOPE'
                    kind  = abap_func_exporting
                    value = REF #( iv_scope ) ) INTO TABLE parameters.

    INSERT VALUE #( name  = |MODE_{ iv_table_name }|
                    kind  = abap_func_exporting
                    value = REF #( iv_enqmode ) ) INTO TABLE parameters.

    " DEQUEUE function modules declare neither FOREIGN_LOCK nor
    " SYSTEM_FAILURE. Listing an exception a function module does not have
    " is itself an error.
    IF iv_unlock = abap_false.
      INSERT VALUE #( name  = '_WAIT'
                      kind  = abap_func_exporting
                      value = REF #( iv_wait ) ) INTO TABLE parameters.

      exception_table = VALUE #( ( name = 'FOREIGN_LOCK'   value = 1 )
                                 ( name = 'SYSTEM_FAILURE' value = 2 )
                                 ( name = 'ERROR_MESSAGE'  value = 3 )
                                 ( name = 'OTHERS'         value = 4 ) ).
    ELSE.
      exception_table = VALUE #( ( name = 'ERROR_MESSAGE' value = 3 )
                                 ( name = 'OTHERS'        value = 4 ) ).
    ENDIF.

    TRY.
        CALL FUNCTION function
          PARAMETER-TABLE parameters
          EXCEPTION-TABLE exception_table.

        re_result = COND #(
          WHEN sy-subrc = 0
            THEN VALUE #( success = abap_true )
          WHEN sy-subrc = 1
            THEN VALUE #( success   = abap_false
                          locked_by = sy-msgv1
                          msg_text  = message_text( textid      = zcx_abap_projects=>foreign_lock
                                                    object_name = |{ iv_table_name }|
                                                    detail      = |{ sy-msgv1 }| ) )
          ELSE VALUE #( success  = abap_false
                        msg_text = message_text(
                                     textid      = COND #( WHEN iv_unlock = abap_true
                                                           THEN zcx_abap_projects=>unlock_failed
                                                           ELSE zcx_abap_projects=>lock_failed )
                                     object_name = |{ iv_table_name }| ) ) ).

      CATCH cx_sy_dyn_call_error INTO DATA(call_error).
        re_result = VALUE #( success  = abap_false
                             msg_text = call_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
