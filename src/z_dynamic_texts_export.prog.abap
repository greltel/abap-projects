************************************************************************
*   Program name: Z_DYNAMIC_TEXTS_EXPORT
*   Description : Download Texts to XLSX File Dynamically
*
*   Created   by: George Drakos
*
************************************************************************
REPORT z_dynamic_texts_export.

*&---------------------------------------------------------------------*
*& GLOBAL DATA DEFINITION
*&---------------------------------------------------------------------*
TABLES:stxh,sscrfields.

CLASS: lcx_texts      DEFINITION DEFERRED,
       lcl_texts      DEFINITION DEFERRED,
       lcl_utilities  DEFINITION DEFERRED,
       lcl_sel_screen DEFINITION DEFERRED.

*&---------------------------------------------------------------------*
*& Class LCX_TEXTS DEFINITION
*&---------------------------------------------------------------------*
CLASS lcx_texts DEFINITION INHERITING FROM cx_static_check.

  PUBLIC SECTION.

    METHODS:
      constructor IMPORTING text TYPE string,
      get_text REDEFINITION.

  PRIVATE SECTION.

    DATA local_text TYPE string.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Class LCL_TEXTS DEFINITION
*&---------------------------------------------------------------------*
CLASS lcl_texts DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS:

      get_data IMPORTING im_object          TYPE STANDARD TABLE
                         im_tdname          TYPE STANDARD TABLE
                         im_tdid            TYPE STANDARD TABLE
                         im_spras           TYPE STANDARD TABLE
               RETURNING VALUE(re_instance) TYPE REF TO lcl_texts
               RAISING   lcx_texts,

      download_texts  IMPORTING im_filename               TYPE file_table-filename
                                im_field_labels_as_header TYPE abap_bool DEFAULT space
                      RAISING   lcx_texts.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF t_texts,
        tdobject   TYPE tdobject,
        tdname     TYPE tdobname,
        tdid       TYPE tdid,
        tdspras    TYPE spras,
        tdtxtlines TYPE tdtxtlines,
        text       TYPE string,
      END OF t_texts,

      tt_texts TYPE STANDARD TABLE OF t_texts WITH DEFAULT KEY INITIAL SIZE 0.

    DATA:lt_texts TYPE tt_texts.

    METHODS:
      populate_texts.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Class LCL_UTILITIES DEFINITION
*&---------------------------------------------------------------------*
CLASS lcl_utilities DEFINITION.

  PUBLIC SECTION.

    CLASS-METHODS get_export_filepath CHANGING ch_filepath TYPE file_table-filename.

ENDCLASS.

*----------------------------------------------------------------------*
* CLASS lcl_sel_screen DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_sel_screen DEFINITION FINAL CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS get_instance RETURNING VALUE(re_instance) TYPE REF TO lcl_sel_screen.

    METHODS:
      screen_initialization,
      screen_pbo,
      screen_pai IMPORTING im_system_command TYPE syst-ucomm.

  PRIVATE SECTION.

    CLASS-DATA lo_instance TYPE REF TO lcl_sel_screen.

ENDCLASS.

*&---------------------------------------------------------------------*
*& SELECTION SCREEN DESIGN
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b0 WITH FRAME TITLE t_title0.
  PARAMETERS p_file TYPE file_table-filename OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b0.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t_title1.

  SELECT-OPTIONS: s_obj    FOR stxh-tdobject OBLIGATORY DEFAULT 'TEXT',
                  s_tdname FOR stxh-tdname   OBLIGATORY DEFAULT 'SAPSCRIPT-TEST_01',
                  s_tdid   FOR stxh-tdid     OBLIGATORY DEFAULT 'ST',
                  s_spras  FOR stxh-tdspras  OBLIGATORY DEFAULT syst-langu.

  SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t_title2.
    PARAMETERS p_header AS CHECKBOX DEFAULT abap_true.
  SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& INITIALIZATION OF SELECTION SCREEN ELEMENTS
*&---------------------------------------------------------------------*
INITIALIZATION.
  lcl_sel_screen=>get_instance( )->screen_initialization( ).

*&---------------------------------------------------------------------*
*& AT SELECTION SCREEN MODIFICATION (PBO)
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
  lcl_sel_screen=>get_instance( )->screen_pbo( ).

*&---------------------------------------------------------------------*
*& AT SELECTION SCREEN ON VALUE REQUESTS (F4)
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  lcl_utilities=>get_export_filepath( CHANGING ch_filepath = p_file ).

*&---------------------------------------------------------------------*
*& AT SELECTION SCREEN Actions(PAI)
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  lcl_sel_screen=>get_instance( )->screen_pai( sscrfields-ucomm ).

*&---------------------------------------------------------------------*
*& EXECUTABLE CODE
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  TRY.

      NEW lcl_texts( )->get_data( im_object = s_obj[]
                                  im_spras  = s_spras[]
                                  im_tdid   = s_tdid[]
                                  im_tdname = s_tdname[] )->download_texts( im_filename               = p_file
                                                                            im_field_labels_as_header = p_header ).


    CATCH lcx_texts INTO DATA(lo_exception).
      MESSAGE lo_exception->get_text( ) TYPE cl_cms_common=>con_msg_typ_i DISPLAY LIKE cl_cms_common=>con_msg_typ_e.
  ENDTRY.

END-OF-SELECTION.

*----------------------------------------------------------------------*
* CLASS lcl_sel_screen IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_sel_screen IMPLEMENTATION.

  METHOD get_instance.

    IF lo_instance IS NOT BOUND.
      lo_instance = NEW #( ).
    ENDIF.

    re_instance = lo_instance.

  ENDMETHOD.

  METHOD screen_initialization.

    t_title0                   = TEXT-001.
    t_title1                   = TEXT-002.
    t_title2                   = TEXT-003.

    syst-title               = TEXT-004.
    %_p_file_%_app_%-text    = icon_xls         && TEXT-005.
    %_s_obj_%_app_%-text     = icon_object_list && TEXT-006.
    %_s_tdname_%_app_%-text  = icon_text_field  && TEXT-007.
    %_s_tdid_%_app_%-text    = icon_text_ina    && TEXT-008.
    %_s_spras_%_app_%-text   = icon_eu          && TEXT-009.
    %_p_header_%_app_%-text  = TEXT-010.

  ENDMETHOD.

  METHOD screen_pbo.

    LOOP AT SCREEN INTO DATA(ls_screen).

      MODIFY SCREEN FROM ls_screen.

    ENDLOOP.

  ENDMETHOD.

  METHOD screen_pai.

    CASE im_system_command.

      WHEN ''.

    ENDCASE.

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Class LCL_UTILITIES IMPLEMENTATION
*&---------------------------------------------------------------------*
CLASS lcl_utilities IMPLEMENTATION.

  METHOD get_export_filepath.

    DATA filename    TYPE string.
    DATA path        TYPE string.
    DATA fullpath    TYPE string.
    DATA user_action TYPE i.

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        window_title              = CONV #( TEXT-011 )
        default_extension         = cl_gui_frontend_services=>filetype_excel
        prompt_on_overwrite       = abap_true
        default_file_name         = 'Exported_Texts.XLSX'
        file_filter               = 'All Files(*.*)|*.*|' && 'Excel Files (*.xlsx)|*.xlsx|' && 'Excel Files (*.xls)|*.xls|'
      CHANGING
        filename                  = filename
        path                      = path
        fullpath                  = fullpath
        user_action               = user_action
      EXCEPTIONS
        cntl_error                = 1
        error_no_gui              = 2
        not_supported_by_gui      = 3
        invalid_default_file_name = 4
        OTHERS                    = 5 ).

    ch_filepath = COND #( WHEN syst-subrc IS INITIAL AND user_action EQ cl_gui_frontend_services=>action_ok THEN fullpath ).

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Class LCL_TEXTS IMPLEMENTATION
*&---------------------------------------------------------------------*
CLASS lcl_texts IMPLEMENTATION.

  METHOD get_data.

    CLEAR me->lt_texts.
    SELECT FROM stxh
      FIELDS stxh~tdobject, stxh~tdname, stxh~tdid, stxh~tdspras, stxh~tdtxtlines
      WHERE tdobject IN  @im_object
        AND tdname   IN  @im_tdname
        AND tdid     IN  @im_tdid
        AND tdspras  IN  @im_spras
        INTO CORRESPONDING FIELDS OF TABLE @me->lt_texts.

    IF syst-subrc IS NOT INITIAL OR lt_texts IS INITIAL.
      RAISE EXCEPTION TYPE lcx_texts EXPORTING text = CONV #( TEXT-012 ).
    ENDIF.

    me->populate_texts( ).

    re_instance = me.

  ENDMETHOD.

  METHOD populate_texts.

    DATA lt_text_table TYPE  text_lh.
    DATA lt_error_table TYPE  text_lh.

    LOOP AT me->lt_texts ASSIGNING FIELD-SYMBOL(<fs_line>).

      CALL FUNCTION 'READ_MULTIPLE_TEXTS'
        EXPORTING
          client                  = syst-mandt
          name                    = <fs_line>-tdname
          object                  = <fs_line>-tdobject
          id                      = <fs_line>-tdid
          language                = <fs_line>-tdspras
        IMPORTING
          text_table              = lt_text_table
          error_table             = lt_error_table
        EXCEPTIONS
          wrong_access_to_archive = 1
          error_message           = 2
          OTHERS                  = 3.

      IF syst-subrc IS INITIAL AND lt_text_table IS NOT INITIAL.

        DATA(lt_text) = VALUE #( lt_text_table[ 1 ]-lines OPTIONAL ).

        CALL FUNCTION 'IDMX_DI_TLINE_INTO_STRING'
          EXPORTING
            it_tline       = lt_text
          IMPORTING
            ev_text_string = <fs_line>-text
          EXCEPTIONS
            error_message  = 1
            OTHERS         = 2.

      ENDIF.

      CLEAR:lt_text,lt_text_table,lt_error_table.

    ENDLOOP.

  ENDMETHOD.

  METHOD download_texts.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_salv) CHANGING t_table = me->lt_texts ).
        DATA(lt_fieldcatalog) = cl_salv_controller_metadata=>get_lvc_fieldcatalog( r_columns = lo_salv->get_columns( ) r_aggregations = lo_salv->get_aggregations( ) ).
      CATCH cx_salv_msg INTO DATA(lo_exception).
        RAISE EXCEPTION TYPE lcx_texts EXPORTING text = lo_exception->get_text( ).
    ENDTRY.

    IF im_field_labels_as_header EQ abap_true.

      LOOP AT lt_fieldcatalog ASSIGNING FIELD-SYMBOL(<fs_line>).

        <fs_line>-fix_column = abap_true.
        CASE <fs_line>-fieldname.
          WHEN 'TEXT'.
            <fs_line>-coltext = CONV #( TEXT-013 ).
        ENDCASE.

      ENDLOOP.

    ENDIF.

    "Get XSTRING
    cl_salv_bs_tt_util=>if_salv_bs_tt_util~transform( EXPORTING xml_type      = if_salv_bs_xml=>c_type_xlsx
                                                                xml_version   = cl_salv_bs_a_xml_base=>get_version( )
                                                                r_result_data = cl_salv_ex_util=>factory_result_data_table( r_data         = REF #( me->lt_texts )
                                                                                                                            t_fieldcatalog = lt_fieldcatalog )
                                                                xml_flavour   = if_salv_bs_c_tt=>c_tt_xml_flavour_export
                                                                gui_type      = if_salv_bs_xml=>c_gui_type_gui
                                                      IMPORTING xml           = DATA(lv_xstring) ).

    CHECK lv_xstring IS NOT INITIAL.

    "XString to SOLIX
    cl_scp_change_db=>xstr_to_xtab( EXPORTING im_xstring = lv_xstring
                                    IMPORTING ex_xtab    = DATA(lt_binary_content)
                                              ex_size    = DATA(lv_bin_size) ).

    CHECK lt_binary_content IS NOT INITIAL.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize            = lv_bin_size
        filename                = |{ im_filename }|
        filetype                = 'BIN'
        confirm_overwrite       = abap_true
      CHANGING
        data_tab                = lt_binary_content
      EXCEPTIONS
        file_write_error        = 1
        no_batch                = 2
        gui_refuse_filetransfer = 3
        invalid_type            = 4
        no_authority            = 5
        unknown_error           = 6
        header_not_allowed      = 7
        separator_not_allowed   = 8
        filesize_not_allowed    = 9
        header_too_long         = 10
        dp_error_create         = 11
        dp_error_send           = 12
        dp_error_write          = 13
        unknown_dp_error        = 14
        access_denied           = 15
        dp_out_of_memory        = 16
        disk_full               = 17
        dp_timeout              = 18
        file_not_found          = 19
        dataprovider_exception  = 20
        control_flush_error     = 21
        not_supported_by_gui    = 22
        error_no_gui            = 23
        OTHERS                  = 24 ).

    IF syst-subrc IS NOT INITIAL.
      RAISE EXCEPTION TYPE lcx_texts EXPORTING text = CONV #( TEXT-014 ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Class LCX_TEXTS IMPLEMENTATION
*&---------------------------------------------------------------------*
CLASS lcx_texts IMPLEMENTATION.

  METHOD constructor.

    super->constructor( textid = CONV #( text ) ).
    local_text = text.

  ENDMETHOD.

  METHOD get_text.

    result = me->local_text.

  ENDMETHOD.

ENDCLASS.
