************************************************************************
*   Program name: Z_SALV_ALV
*   Description : Dynamic SALV Console
*
*   Created   by: George Drakos
*
************************************************************************
REPORT z_salv_alv NO STANDARD PAGE HEADING LINE-COUNT 255.

*&---------------------------------------------------------------------*
*& DICTIONARY TABLES-TYPE POOLS
*&---------------------------------------------------------------------*

TABLES sscrfields.
*&---------------------------------------------------------------------*
*& INTEFACES/CLASSES
*&---------------------------------------------------------------------*
INTERFACE: lif_data   DEFERRED,
           lif_output DEFERRED.

CLASS: lcl_main_salv       DEFINITION DEFERRED,
       lcl_utilities       DEFINITION DEFERRED,
       lcl_salv_edit       DEFINITION DEFERRED,
       lcl_sel_screen      DEFINITION DEFERRED,
       lcx_exception       DEFINITION DEFERRED.

*&---------------------------------------------------------------------*
*& GLOBAL DATA DECLARATION
*&---------------------------------------------------------------------*
FIELD-SYMBOLS <fs_table> TYPE INDEX TABLE.

*&---------------------------------------------------------------------*
*& GLOBAL CONSTANTS
*&---------------------------------------------------------------------*
CONSTANTS:
  "MESSAGE TYPES - PREVIOUSLY BORROWED FROM CL_CMS_COMMON
  gc_msg_type_status  TYPE syst-msgty VALUE 'S',
  gc_msg_type_info    TYPE syst-msgty VALUE 'I',
  gc_msg_type_error   TYPE syst-msgty VALUE 'E',
  "GENERATED COLUMN WIDTHS - PREVIOUSLY BORROWED FROM CL_MMIM_MAA_2
  gc_icon_column_len  TYPE i          VALUE 8,
  gc_check_column_len TYPE i          VALUE 1.

*&----------------------------------------------------------------------*
*& CLASS LCX_EXCEPTION DEFINITION
*&----------------------------------------------------------------------*
CLASS lcx_exception DEFINITION INHERITING FROM cx_static_check FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS:
      constructor IMPORTING im_text     TYPE bapiret2-message OPTIONAL
                            im_textid   TYPE texid OPTIONAL
                            im_previous TYPE REF TO  cx_root OPTIONAL,
      get_text            REDEFINITION,
      get_longtext        REDEFINITION.

  PRIVATE SECTION.

    DATA:
         mv_message TYPE bapiret2-message.

ENDCLASS.

*----------------------------------------------------------------------*
* INTEFACE LIF_DATA
*----------------------------------------------------------------------*
INTERFACE lif_data.

  TYPES:

    BEGIN OF ENUM en_alv_version,
      t_gui,
      t_fiori,
    END OF ENUM en_alv_version,

    BEGIN OF ENUM en_alv_container,
      t_standard,
      t_bottom,
      t_splitter,
      t_dialog,
      t_context,
    END OF ENUM en_alv_container,

    BEGIN OF ENUM en_data_source,
      t_excel,
      t_database,
    END OF ENUM en_data_source,

    BEGIN OF ty_popup_dimensions,
      column_start TYPE i,
      column_end   TYPE i,
      line_start   TYPE i,
      line_end     TYPE i,
    END OF ty_popup_dimensions.

  METHODS:
    get_data IMPORTING im_data_source               TYPE en_data_source
                       im_table                     TYPE tabname             OPTIONAL
                       im_filepath                  TYPE file_table-filename OPTIONAL
                       im_sheet_name                TYPE char20              OPTIONAL
                       im_number_of_lines           TYPE syst_tabix          DEFAULT 100
                       im_field                     TYPE fieldname           OPTIONAL
                       im_comp                      TYPE ddoption            OPTIONAL
                       im_val                       TYPE string              OPTIONAL
                       im_checkbox_column           TYPE abap_bool           DEFAULT abap_true
                       im_icon_column               TYPE abap_bool           DEFAULT abap_true
                       im_head                      TYPE abap_bool           DEFAULT abap_false
             RETURNING VALUE(re_main_salv_instance) TYPE REF TO lif_data
             RAISING   lcx_exception,

    process_data RETURNING VALUE(re_main_salv_instance) TYPE REF TO lif_output
                 RAISING   lcx_exception.

ENDINTERFACE.


*----------------------------------------------------------------------*
* INTEFACE LIF_OUTPUT
*----------------------------------------------------------------------*
INTERFACE lif_output.

  METHODS:
    display_data RAISING lcx_exception.

ENDINTERFACE.

*----------------------------------------------------------------------*
* CLASS LCL_SEL_SCREEN
*----------------------------------------------------------------------*
CLASS lcl_sel_screen DEFINITION CREATE PRIVATE FINAL.

  PUBLIC SECTION.

    CLASS-METHODS:
      get_instance RETURNING VALUE(re_instance) TYPE REF TO lcl_sel_screen.

    METHODS:

      screen_initialization,

      screen_pbo,

      color_f4 IMPORTING im_fieldname TYPE help_info-dynprofld,

      fields_f4 IMPORTING im_fieldname TYPE help_info-dynprofld,

      screen_pai IMPORTING im_user_command TYPE syst-ucomm.

  PRIVATE SECTION.

    TYPES:BEGIN OF ty_color,
            color       TYPE lvc_col,
            color_descr TYPE as4text,
          END OF ty_color,

          tt_color TYPE STANDARD TABLE OF ty_color WITH EMPTY KEY.

    CLASS-DATA lo_instance TYPE REF TO lcl_sel_screen.

    DATA t_color TYPE tt_color.

ENDCLASS.

*----------------------------------------------------------------------*
*       CLASS LCL_MAIN_SALV
*----------------------------------------------------------------------*
CLASS lcl_main_salv DEFINITION CREATE PUBLIC FINAL FRIENDS lcl_utilities lcl_salv_edit.

  PUBLIC SECTION.

    INTERFACES:
      if_alv_rm_grid_friend,
      lif_output,
      lif_data.

    ALIASES display_data FOR lif_output~display_data.
    ALIASES get_data     FOR lif_data~get_data.
    ALIASES process_data FOR lif_data~process_data.

    METHODS:

      constructor IMPORTING im_version                TYPE lif_data~en_alv_version
                            im_popup                  TYPE abap_bool          OPTIONAL
                            im_container              TYPE lif_data~en_alv_container   OPTIONAL
                            im_layout                 TYPE disvariant-variant OPTIONAL
                            im_status                 TYPE rsmpe-status       OPTIONAL
                            im_technical_names        TYPE flag               OPTIONAL
                            im_hotspot_field          TYPE lvc_fname          OPTIONAL
                            im_hotspot_color          TYPE lvc_col            OPTIONAL
                            im_line_color             TYPE lvc_col            OPTIONAL
                            im_handle_gui_grid_events TYPE flag               DEFAULT abap_false
                            im_popup_dimensions       TYPE lif_data~ty_popup_dimensions OPTIONAL.

  PROTECTED SECTION.

    CONSTANTS: lc_checkbox     TYPE char30 VALUE 'CHECK',
               lc_icon_column  TYPE char30 VALUE 'ICON',
               lc_cell_style   TYPE char30 VALUE 'CELL_STYLE',
               lc_color_column TYPE char30 VALUE 'LVC_COLOR'.

  PRIVATE SECTION.

    TYPES:BEGIN OF t_empty_column,
            column_name TYPE lvc_fname,
          END OF t_empty_column.


    DATA: lr_table                  TYPE REF TO data,
          lv_layout                 TYPE disvariant-variant,
          lv_technical_names        TYPE flag,
          lv_hotspot_field          TYPE lvc_fname,
          lv_hotspot_color          TYPE lvc_col,
          lv_line_color             TYPE lvc_col,
          lv_status                 TYPE rsmpe-status,
          lv_version                TYPE lif_data~en_alv_version,
          lv_handle_gui_grid_events TYPE flag,
          lv_data_source            TYPE lif_data~en_data_source,
          lv_container              TYPE lif_data~en_alv_container,
          ls_popup_dimensions       TYPE lif_data~ty_popup_dimensions,
          lv_popup                  TYPE abap_bool,
          lt_filter_selopt          TYPE salv_t_selopt_ref,
          lo_salv_alv               TYPE REF TO cl_salv_table,
          handler_added             TYPE abap_bool VALUE abap_false,
          lt_empty_columns          TYPE STANDARD TABLE OF t_empty_column WITH DEFAULT KEY,
          lv_show_hide              TYPE abap_bool VALUE abap_false,
          lv_editable               TYPE abap_bool VALUE abap_false.

    METHODS:
      create_alv              RAISING lcx_exception,
      get_docking_container   RETURNING VALUE(re_container) TYPE REF TO cl_gui_docking_container,
      get_splitter_container  RETURNING VALUE(re_container) TYPE REF TO cl_gui_container,
      get_dialog_container    RETURNING VALUE(re_container) TYPE REF TO cl_gui_dialogbox_container,
      get_context_menu_container RETURNING VALUE(re_container) TYPE REF TO cl_gui_container,
      field_catalog           RAISING lcx_exception,
      column_properties       RAISING lcx_exception,
      display_settings_header RAISING lcx_exception,
      header_creation         RAISING lcx_exception,
      header_creation_fiori   RAISING lcx_exception,
      footer_creation         RAISING lcx_exception,
      toolbar_status          RAISING lcx_exception,
      handle_gui_grid_events  RAISING lcx_exception,
      event_handling          RAISING lcx_exception,
      display_alv             RAISING lcx_exception,
      return_salv_instance    RETURNING VALUE(re_salv) TYPE REF TO cl_salv_table,
      show_hide_empty_columns,
      display_documentation,
      display_details_of_selection,
      get_text_label_of_rollname IMPORTING im_rollname          TYPE rollname
                                 RETURNING VALUE(re_text_label) TYPE scrtext_l,
      set_hotspot IMPORTING im_field TYPE lvc_fname
                            im_alv   TYPE REF TO cl_salv_table
                  RAISING   lcx_exception.

    "SALV EVENTS
    METHODS:
      handle_double_click    FOR EVENT double_click        OF cl_salv_events_table IMPORTING row column,
      handle_hotspot         FOR EVENT link_click          OF cl_salv_events_table IMPORTING row column,
      on_user_command        FOR EVENT added_function      OF cl_salv_events_table IMPORTING e_salv_function,
      on_end_of_page         FOR EVENT end_of_page         OF cl_salv_events_table IMPORTING r_end_of_page page,
      on_top_of_page         FOR EVENT top_of_page         OF cl_salv_events_table IMPORTING r_top_of_page page,
      on_after_salv_function FOR EVENT after_salv_function OF cl_salv_events       IMPORTING e_salv_function.

    "GUI GRID EVENTS
    METHODS:
      on_function_selected FOR EVENT function_selected OF cl_gui_toolbar  IMPORTING fcode sender,
      event_after_refresh  FOR EVENT after_refresh     OF cl_gui_alv_grid IMPORTING sender,
      on_toolbar           FOR EVENT toolbar           OF cl_gui_alv_grid IMPORTING e_object e_interactive sender.

ENDCLASS.

*----------------------------------------------------------------------*
*       CLASS lcl_utilities DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_utilities DEFINITION CREATE PUBLIC FRIENDS lcl_main_salv.

  PUBLIC SECTION.

    CLASS-METHODS:

      dynamic_where_clause IMPORTING im_field                TYPE fieldname
                                     im_comp                 TYPE ddoption DEFAULT if_fsbp_const_range=>option_equal
                                     im_val                  TYPE string
                                     im_table_name           TYPE tabname
                           RETURNING VALUE(re_select_clause) TYPE hrtb_cond,

      open_dialog_excel  RETURNING VALUE(re_filepath)  TYPE file_table-filename,

      check_field_exists_in_table IMPORTING im_field         TYPE fieldname
                                            im_table         TYPE tabname30
                                  RETURNING VALUE(re_exists) TYPE abap_bool,

      f4_salv CHANGING cv_layout TYPE disvariant-variant,

      get_structured_table_from_gen IMPORTING im_table            TYPE ANY TABLE
                                              im_map_by_structure TYPE abap_bool OPTIONAL
                                              im_structure_line   TYPE i DEFAULT 1
                                              im_start_line       TYPE i DEFAULT 2
                                    EXPORTING ex_table            TYPE ANY TABLE,

      upload_excel IMPORTING im_filepath     TYPE file_table-filename
                             im_sheet_name   TYPE char20 OPTIONAL
                             im_sheet_number TYPE i OPTIONAL
                   EXPORTING ex_table        TYPE REF TO data
                   RAISING   lcx_exception.

  PROTECTED SECTION.


    TYPES:
      BEGIN OF ENUM t_alpha_conversion STRUCTURE s_alpha_conversion BASE TYPE char1,
        in    VALUE 1,
        out   VALUE 2,
        other VALUE IS INITIAL,
      END OF ENUM t_alpha_conversion STRUCTURE s_alpha_conversion.

    CLASS-METHODS:


      alpha_conversion IMPORTING VALUE(iv_input)  TYPE any
                                 im_alpha         TYPE lcl_utilities=>t_alpha_conversion DEFAULT s_alpha_conversion-in
                       EXPORTING VALUE(ev_output) TYPE any,

      date_external_to_internal IMPORTING im_date                 TYPE string
                                RETURNING VALUE(re_date_internal) TYPE tumls_date.

ENDCLASS.

*----------------------------------------------------------------------*
*       CLASS lcl_salv_edit DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_salv_edit DEFINITION INHERITING FROM cl_salv_model_base CREATE PRIVATE FINAL.

  PUBLIC SECTION.

    CLASS-METHODS:

      set_editable     IMPORTING VALUE(im_fieldname) TYPE csequence OPTIONAL
                                 im_salv_table       TYPE REF TO cl_salv_table
                                 VALUE(im_editable)  TYPE abap_bool DEFAULT abap_true
                                 VALUE(im_refresh)   TYPE abap_bool DEFAULT abap_true.

  PRIVATE SECTION.


    CLASS-METHODS: get_control IMPORTING im_salv        TYPE REF TO cl_salv_table
                               RETURNING VALUE(re_grid) TYPE REF TO cl_gui_alv_grid.

ENDCLASS."lcl_salv_edit DEFINITION

*&---------------------------------------------------------------------*
*& SELECTION SCREEN DESIGN
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b0 WITH FRAME TITLE t_title0.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_db FOR FIELD p_db.
    PARAMETERS: p_db RADIOBUTTON GROUP rb0 DEFAULT 'X' USER-COMMAND dummy.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_file FOR FIELD p_file.
    PARAMETERS:p_file RADIOBUTTON GROUP rb0.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b0.

SELECTION-SCREEN BEGIN OF BLOCK b05 WITH FRAME TITLE t_title5.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_excel FOR FIELD p_excel MODIF ID id3.
    PARAMETERS: p_excel TYPE file_table-filename MODIF ID id3.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_sheet FOR FIELD p_sheet MODIF ID id3.
    PARAMETERS: p_sheet TYPE char20 MODIF ID id3 LOWER CASE.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_head FOR FIELD p_head MODIF ID id3.
    PARAMETERS: p_head AS CHECKBOX DEFAULT  '' MODIF ID id3.
    SELECTION-SCREEN COMMENT 27(42) t_hdesc MODIF ID id3.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b05.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t_title1.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_table FOR FIELD p_table MODIF ID id4.
    PARAMETERS: p_table TYPE tabname OBLIGATORY DEFAULT 'BSEG' MATCHCODE OBJECT dd_dbtb_16 MODIF ID id4.
    SELECTION-SCREEN COMMENT 57(55) t_descr MODIF ID id4.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS: p_editf TYPE lvc_fname NO-DISPLAY.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_hotsp FOR FIELD p_hotsp MODIF ID id4.
    PARAMETERS: p_hotsp TYPE lvc_fname MODIF ID id4.
    SELECTION-SCREEN COMMENT 57(55) t_descr2 MODIF ID id4.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_colh FOR FIELD p_colh MODIF ID id4.
    PARAMETERS: p_colh TYPE lvc_col DEFAULT 6 MODIF ID id4.
    SELECTION-SCREEN COMMENT 38(50) t_desch MODIF ID id4.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_coll FOR FIELD p_coll.
    PARAMETERS: p_coll TYPE lvc_col DEFAULT space.
    SELECTION-SCREEN COMMENT 38(50) t_descl.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_layout FOR FIELD p_layout MODIF ID id4.
    PARAMETERS: p_layout TYPE disvariant-variant VISIBLE LENGTH 11 MODIF ID id4.
    SELECTION-SCREEN COMMENT 38(50) t_ldescr MODIF ID id4.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) t_hits FOR FIELD p_hits MODIF ID id4.
    PARAMETERS: p_hits TYPE syst_tabix DEFAULT 10 MODIF ID id4.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_names FOR FIELD p_names MODIF ID id4.
    PARAMETERS: p_names AS CHECKBOX DEFAULT space MODIF ID id4.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_check FOR FIELD p_check.
    PARAMETERS: p_check AS CHECKBOX DEFAULT space.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_icon FOR FIELD p_icon.
    PARAMETERS: p_icon AS CHECKBOX DEFAULT space.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_r1 FOR FIELD p_r1.
    PARAMETERS: p_r1 RADIOBUTTON GROUP rb1 DEFAULT 'X' USER-COMMAND dummy.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_r2 FOR FIELD p_r2.
    PARAMETERS: p_r2 RADIOBUTTON GROUP rb1.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE t_title4.

  SELECTION-SCREEN BEGIN OF LINE.

    PARAMETERS: p_fiel TYPE fieldname MODIF ID id4,
                p_comp TYPE ddoption DEFAULT if_fsbp_const_range=>option_equal MODIF ID id4,
                p_val  TYPE string MODIF ID id4.

  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b4.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t_title2.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_stand FOR FIELD p_stand MODIF ID id1.
    PARAMETERS: p_stand RADIOBUTTON GROUP rb2 DEFAULT 'X' MODIF ID id1 .
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_doc FOR FIELD p_doc MODIF ID id1.
    PARAMETERS: p_doc RADIOBUTTON GROUP rb2  MODIF ID id1 .
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_split FOR FIELD p_split MODIF ID id1.
    PARAMETERS: p_split RADIOBUTTON GROUP rb2 MODIF ID id1 .
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_dial FOR FIELD p_dial MODIF ID id1.
    PARAMETERS: p_dial RADIOBUTTON GROUP rb2 MODIF ID id1 .
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_cont FOR FIELD p_cont MODIF ID id1.
    PARAMETERS: p_cont RADIOBUTTON GROUP rb2 MODIF ID id1 .
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN SKIP 1.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_event FOR FIELD p_event MODIF ID id1.
    PARAMETERS: p_event AS CHECKBOX MODIF ID id1 .
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE t_title3.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_popup FOR FIELD p_popup MODIF ID id2.
    PARAMETERS: p_popup AS CHECKBOX DEFAULT space MODIF ID id2 USER-COMMAND dummy.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_col_s FOR FIELD p_col_s MODIF ID id5.
    PARAMETERS: p_col_s TYPE i DEFAULT 1 MODIF ID id5.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_col_e FOR FIELD p_col_e MODIF ID id5.
    PARAMETERS: p_col_e TYPE i DEFAULT 140 MODIF ID id5.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_lin_s FOR FIELD p_lin_s MODIF ID id5.
    PARAMETERS: p_lin_s TYPE i DEFAULT 1 MODIF ID id5.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_lin_e FOR FIELD p_lin_e MODIF ID id5.
    PARAMETERS: p_lin_e TYPE i DEFAULT 30 MODIF ID id5.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(26) t_status FOR FIELD p_status MODIF ID id2.
    PARAMETERS: p_status TYPE rsmpe-status MODIF ID id2.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b3.

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
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_layout.
  lcl_utilities=>f4_salv( CHANGING cv_layout = p_layout ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_hotsp.
  lcl_sel_screen=>get_instance( )->fields_f4( 'P_HOTSP' ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_fiel.
  lcl_sel_screen=>get_instance( )->fields_f4( 'P_FIEL' ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_coll.
  lcl_sel_screen=>get_instance( )->color_f4( 'P_COLL' ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_colh.
  lcl_sel_screen=>get_instance( )->color_f4( 'P_COLH' ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_excel.
  p_excel = lcl_utilities=>open_dialog_excel( ).

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
      NEW lcl_main_salv( im_version                 = COND #( WHEN p_r1 EQ abap_true THEN lcl_main_salv=>lif_data~t_gui
                                                              WHEN p_r2 EQ abap_true THEN lcl_main_salv=>lif_data~t_fiori
                                                              ELSE lcl_main_salv=>lif_data~t_fiori )
                         im_popup                   = p_popup
                         im_container               = COND #( WHEN p_stand EQ abap_true THEN lcl_main_salv=>lif_data~t_standard
                                                              WHEN p_doc   EQ abap_true THEN lcl_main_salv=>lif_data~t_bottom
                                                              WHEN p_split EQ abap_true THEN lcl_main_salv=>lif_data~t_splitter
                                                              WHEN p_dial  EQ abap_true THEN lcl_main_salv=>lif_data~t_dialog
                                                              WHEN p_cont  EQ abap_true THEN lcl_main_salv=>lif_data~t_context
                                                              ELSE lcl_main_salv=>lif_data~t_standard )
                         im_layout                  = p_layout
                         im_technical_names         = p_names
                         im_status                  = p_status
                         im_hotspot_field           = p_hotsp
                         im_hotspot_color           = p_colh
                         im_line_color              = p_coll
                         im_handle_gui_grid_events  = p_event
                         im_popup_dimensions        = VALUE #( column_start = p_col_s
                                                               column_end   = p_col_e
                                                               line_start   = p_lin_s
                                                               line_end     = p_lin_e )
                       )->get_data( im_data_source     = COND #( WHEN p_db   EQ abap_true THEN lcl_main_salv=>lif_data~t_database
                                                                 WHEN p_file EQ abap_true THEN lcl_main_salv=>lif_data~t_excel
                                                                 ELSE THROW lcx_exception( im_text = CONV #( TEXT-057 ) )  )
                                    im_filepath        = p_excel
                                    im_sheet_name      = p_sheet
                                    im_head            = p_head
                                    im_table           = p_table
                                    im_number_of_lines = p_hits
                                    im_comp            = p_comp
                                    im_field           = p_fiel
                                    im_val             = p_val
                                    im_checkbox_column = p_check
                                    im_icon_column     = p_icon
                        )->process_data(
                        )->display_data( ).

    CATCH lcx_exception INTO DATA(lo_exception).
      MESSAGE lo_exception->get_text( ) TYPE gc_msg_type_info DISPLAY LIKE gc_msg_type_error.
  ENDTRY.

END-OF-SELECTION.
*&---------------------------------------------------------------------*
*& END OF EXECUTABLE CODE
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
*CLASS LCL_MAIN_SALV IMPLEMENTATION
*----------------------------------------------------------------------*

CLASS lcl_main_salv IMPLEMENTATION.

  METHOD constructor.

    "SET VALUES TO INSTANCE ATTRIBUTES
    me->lv_layout                 = im_layout.
    me->lv_technical_names        = im_technical_names.
    me->lv_hotspot_field          = im_hotspot_field.
    me->lv_hotspot_color          = im_hotspot_color.
    me->lv_line_color             = im_line_color.
    me->lv_handle_gui_grid_events = im_handle_gui_grid_events.
    me->lv_version                = im_version.
    me->lv_container              = im_container.
    me->lv_status                 = im_status.
    me->ls_popup_dimensions       = im_popup_dimensions.
    me->lv_popup                  = im_popup.

  ENDMETHOD.

  METHOD get_data.

    re_main_salv_instance = me.

    IF im_data_source EQ lcl_main_salv=>lif_data~t_excel AND im_filepath IS NOT INITIAL.

      me->lv_data_source = lcl_main_salv=>lif_data~t_excel.

      lcl_utilities=>upload_excel(
        EXPORTING
          im_filepath   = im_filepath
          im_sheet_name = im_sheet_name
        IMPORTING
          ex_table      = DATA(lo_data_ref) ).

      "Create Dynamic Internal Table with Column Heading
      DATA(lt_component) = VALUE cl_abap_structdescr=>component_table(
                            ( name = lc_cell_style  type  = CAST #( cl_abap_elemdescr=>describe_by_name( 'salv_t_int4_column' ) ) )
                            ( name = lc_color_column type = CAST #( cl_abap_elemdescr=>describe_by_name( 'lvc_t_scol' ) ) ) ).

      IF im_icon_column EQ abap_true.
        APPEND VALUE abap_componentdescr( name = lc_icon_column type = cl_abap_elemdescr=>get_c( gc_icon_column_len ) ) TO lt_component.
      ENDIF.

      IF im_checkbox_column EQ abap_true.
        APPEND VALUE abap_componentdescr( name = lc_checkbox type = cl_abap_elemdescr=>get_c( gc_check_column_len ) ) TO lt_component.
      ENDIF.

      FIELD-SYMBOLS: <fs_tab> TYPE STANDARD TABLE.
      ASSIGN lo_data_ref->* TO <fs_tab>.

      DO.

        ASSIGN COMPONENT syst-index OF STRUCTURE <fs_tab>[ 1 ] TO FIELD-SYMBOL(<fs>).
        IF <fs> IS NOT INITIAL AND
           syst-subrc IS INITIAL.

          IF im_head EQ abap_true.
            CONDENSE <fs> NO-GAPS.
            APPEND VALUE #( name = |{ <fs> }| type = cl_abap_elemdescr=>get_c( 30 ) ) TO lt_component.
          ELSE.
            APPEND VALUE #( name = |column_{ syst-index }| type = cl_abap_elemdescr=>get_c( 30 ) ) TO lt_component.
          ENDIF.

        ELSE.

          EXIT.

        ENDIF.

      ENDDO.

      "Table type
      TRY.
          DATA(lo_new_table) = cl_abap_tabledescr=>create(
                               p_line_type  = cl_abap_structdescr=>create( lt_component )
                               p_table_kind = cl_abap_tabledescr=>tablekind_std
                               p_unique     = abap_false ).
        CATCH cx_sy_struct_attributes cx_sy_struct_comp_name INTO DATA(lo_exception). "#EC NO_HANDLER
          RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( lo_exception->get_text( ) ).
      ENDTRY.

      "Data to handle the new table type
      CREATE DATA me->lr_table TYPE HANDLE lo_new_table.

      "New internal table in fieldsymbol
      ASSIGN me->lr_table->* TO <fs_table>.

      "MAP VALUE TABLE TO STRUCTURED TABLE
      lcl_utilities=>get_structured_table_from_gen(
        EXPORTING
          im_map_by_structure = COND #( WHEN im_head EQ abap_true  THEN abap_false
                                        WHEN im_head EQ abap_false THEN abap_true )
          im_start_line       = COND #( WHEN im_head EQ abap_true  THEN 2
                                        WHEN im_head EQ abap_false THEN 1 )
          im_table            = <fs_tab>
        IMPORTING
          ex_table            = <fs_table> ).


    ELSEIF im_data_source EQ lcl_main_salv=>lif_data~t_database AND im_table IS NOT INITIAL.

      me->lv_data_source = lcl_main_salv=>lif_data~t_database.

      "Build Components of Dynamic Table
      DATA(lt_tot_comp) = VALUE cl_abap_structdescr=>component_table(
                            ( name = lc_cell_style  type = CAST #( cl_abap_elemdescr=>describe_by_name( 'salv_t_int4_column' ) ) )
                            ( name = lc_color_column type = CAST #( cl_abap_elemdescr=>describe_by_name( 'lvc_t_scol' ) ) ) ).

      IF im_icon_column EQ abap_true.
        APPEND VALUE abap_componentdescr( name = lc_icon_column type = cl_abap_elemdescr=>get_c( gc_icon_column_len ) ) TO lt_tot_comp.
      ENDIF.

      IF im_checkbox_column EQ abap_true.
        APPEND VALUE abap_componentdescr( name = lc_checkbox  type = cl_abap_elemdescr=>get_c( gc_check_column_len ) ) TO lt_tot_comp.
      ENDIF.

      DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( im_table ) ).
      DATA(lt_comp)  =  lo_struct->get_components( ).
      APPEND LINES OF lt_comp TO lt_tot_comp.

      DELETE lt_tot_comp WHERE suffix IS NOT INITIAL.

      "Table type
      TRY.
          DATA(lo_new_tab) = cl_abap_tabledescr=>create(
                             p_line_type  = cl_abap_structdescr=>create( lt_tot_comp )
                             p_table_kind = cl_abap_tabledescr=>tablekind_std
                             p_unique     = abap_false ).
        CATCH cx_sy_struct_attributes cx_sy_struct_comp_name INTO DATA(lo_exception2). "#EC NO_HANDLER
          RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( lo_exception2->get_text( ) ).
      ENDTRY.

      "Data to handle the new table type
      CREATE DATA me->lr_table TYPE HANDLE lo_new_tab.

      "New internal table in fieldsymbol
      ASSIGN me->lr_table->* TO <fs_table>.

      "Build Dynamic Where Clause
      IF ( im_field IS NOT INITIAL ) AND ( im_comp IS NOT INITIAL ) AND ( im_val IS NOT INITIAL ) .
        DATA(lt_select_clause) = lcl_utilities=>dynamic_where_clause( im_comp       = im_comp
                                                                      im_field      = im_field
                                                                      im_val        = im_val
                                                                      im_table_name = im_table ).
      ENDIF.

      IF <fs_table> IS ASSIGNED.

        SELECT *
        FROM (im_table)
        INTO CORRESPONDING FIELDS OF TABLE @<fs_table>
        UP TO @im_number_of_lines ROWS
        WHERE (lt_select_clause).

        IF <fs_table> IS INITIAL.
          RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = | { TEXT-040 } { im_table } |.
        ENDIF.

      ELSE.
        RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( TEXT-041 ).
      ENDIF.

    ELSE.
      RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( TEXT-042 ).
    ENDIF.

  ENDMETHOD.

  METHOD process_data.

    re_main_salv_instance = me.

    LOOP AT <fs_table> ASSIGNING FIELD-SYMBOL(<fs_structure>).

      ASSIGN COMPONENT lc_icon_column  OF STRUCTURE <fs_structure> TO FIELD-SYMBOL(<lv_icon_value>).
      ASSIGN COMPONENT lc_color_column OF STRUCTURE <fs_structure> TO FIELD-SYMBOL(<lv_color_value>).
      ASSIGN COMPONENT lc_cell_style   OF STRUCTURE <fs_structure> TO FIELD-SYMBOL(<lv_cell_style>).

      "Color Hotspot Field
      IF me->lv_hotspot_field IS NOT INITIAL AND
         me->lv_hotspot_color IS NOT INITIAL AND
          <lv_color_value>    IS ASSIGNED.

        <lv_color_value> = VALUE lvc_t_scol( ( fname     = lv_hotspot_field
                                               color-col = lv_hotspot_color
                                               color-int = 0
                                               color-inv = 0 ) ).

      ENDIF.

      "Color of Lines
      IF me->lv_line_color IS NOT INITIAL AND
         <lv_color_value>  IS ASSIGNED.

        <lv_color_value> = VALUE lvc_t_scol( ( color-col = lv_line_color
                                               color-int = 0
                                               color-inv = 0 ) ).

      ENDIF.

      "Set Cell Style
      IF <lv_cell_style> IS ASSIGNED.
        <lv_cell_style> = VALUE salv_t_int4_column( ( columnname = 'COLUMN_NAME'
                                                     value      = if_salv_c_cell_type=>button ) ).
      ENDIF.

      "Icons
      IF <lv_icon_value> IS ASSIGNED.

        <lv_icon_value> = SWITCH #( syst-tabix MOD 4
                                    WHEN 1 THEN icon_green_light
                                    WHEN 2 THEN icon_cancel
                                    WHEN 3 THEN icon_locked
                                    ELSE icon_address ).

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD display_data.

    me->create_alv( ).
    me->field_catalog( ).
    me->column_properties( ).
    me->display_settings_header( ).
    me->header_creation( ).
    me->footer_creation( ).
    me->toolbar_status( ).
    me->handle_gui_grid_events( ).
    me->event_handling( ).
    me->display_alv( ).

  ENDMETHOD.

  METHOD create_alv.

    CASE me->lv_version.

      WHEN lcl_main_salv=>lif_data~t_gui.

        TRY.
            cl_salv_table=>factory( EXPORTING r_container   = SWITCH #( me->lv_container
                                                                        WHEN lcl_main_salv=>lif_data~t_bottom   THEN me->get_docking_container( )
                                                                        WHEN lcl_main_salv=>lif_data~t_standard THEN cl_gui_container=>default_screen
                                                                        WHEN lcl_main_salv=>lif_data~t_splitter THEN me->get_splitter_container( )
                                                                        WHEN lcl_main_salv=>lif_data~t_dialog   THEN me->get_dialog_container( )
                                                                        WHEN lcl_main_salv=>lif_data~t_context  THEN me->get_context_menu_container( ) )
                                              list_display  = if_salv_c_bool_sap=>false
                                    IMPORTING r_salv_table  = me->lo_salv_alv
                                    CHANGING  t_table       = <fs_table> ).
          CATCH cx_salv_msg.                            "#EC NO_HANDLER
        ENDTRY.

      WHEN lcl_main_salv=>lif_data~t_fiori.

        TRY.
            cl_salv_table=>factory( EXPORTING list_display  = if_salv_c_bool_sap=>false
                                    IMPORTING r_salv_table  = me->lo_salv_alv
                                    CHANGING  t_table       = <fs_table> ).
          CATCH cx_salv_msg.                            "#EC NO_HANDLER
        ENDTRY.

        IF me->lv_popup EQ abap_true.

          me->lo_salv_alv->set_screen_popup( start_column = me->ls_popup_dimensions-column_start
                                             end_column   = me->ls_popup_dimensions-column_end
                                             start_line   = me->ls_popup_dimensions-line_start
                                             end_line     = me->ls_popup_dimensions-line_end ).

        ENDIF.

    ENDCASE.

    IF me->lo_salv_alv IS NOT BOUND.
      RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( TEXT-043 ).
    ENDIF.

  ENDMETHOD.

  METHOD get_docking_container.

    re_container = NEW #( no_autodef_progid_dynnr = abap_true
                          side                    = cl_gui_docking_container=>dock_at_bottom
                          ratio                   = 90 ).

  ENDMETHOD.

  METHOD get_splitter_container.

    DATA(o_splitter_container) = NEW cl_gui_splitter_container( parent                  = cl_gui_container=>default_screen
                                                                no_autodef_progid_dynnr = abap_true
                                                                rows                    = 1
                                                                columns                 = 2 ).

    re_container = o_splitter_container->get_container( row = 1 column = 1 ).

  ENDMETHOD.

  METHOD get_dialog_container.

    re_container = NEW #( no_autodef_progid_dynnr = abap_true
                          caption = TEXT-058
                          top     = 20
                          left    = 20
                          width   = 1280
                          height  = 400 ).

  ENDMETHOD.

  METHOD get_context_menu_container.

    "CREATE SPLITTER
    DATA(o_splitter) = NEW cl_gui_splitter_container( parent = cl_gui_container=>default_screen
                                            no_autodef_progid_dynnr = abap_true
                                            rows = 2
                                            columns = 1 ).

    "ABSOLUTE ROW HEIGHT
    o_splitter->set_row_mode( mode = cl_gui_splitter_container=>mode_absolute ).

    "ABSOLUTE HEIGHT 24 PIXELS FOR SPLITTER ABOVE
    o_splitter->set_row_height( id = 1 height = 24 ).

    "Splitter for top container fixed and hidden
    o_splitter->set_row_sash( id    = 1
                              type  = cl_gui_splitter_container=>type_movable
                              value = cl_gui_splitter_container=>false ).

    o_splitter->set_row_sash( id    = 1
                              type  = cl_gui_splitter_container=>type_sashvisible
                              value = cl_gui_splitter_container=>false ).

    "Create Top and Bottom Custom Container
    DATA(o_container_top)    = o_splitter->get_container( row = 1 column = 1 ).
    re_container = o_splitter->get_container( row = 2 column = 1 ).

    "Horizontal Toolbar
    DATA(o_tool) = NEW cl_gui_toolbar( parent       = o_container_top
                                       display_mode = cl_gui_toolbar=>m_mode_horizontal ).

    "Register of Event Types.Must be registered Separately
    TYPES: ty_it_events TYPE STANDARD TABLE OF cntl_simple_event WITH DEFAULT KEY.
    DATA(it_events) = VALUE ty_it_events( ( eventid = cl_gui_toolbar=>m_id_function_selected
                                  appl_event = abap_true ) ).

    o_tool->set_registered_events( events = it_events ).

    "Add toolbar buttons. Button types are defined in type group CNTB
    o_tool->add_button( fcode       = 'BTN_MENU'
                        icon        = icon_activate
                        butn_type   = cntb_btype_menu
                        text        = CONV text40( TEXT-059 )
                        quickinfo   = CONV iconquick( TEXT-059 )
                        is_checked  = abap_false
                        is_disabled = abap_false ).

    DATA(o_menu) = NEW cl_ctmenu( ).
    o_menu->add_function( fcode   = 'F1'
                          checked = abap_false
                          text    = TEXT-060 ).

    o_menu->add_function( fcode   = 'F2'
                          checked = abap_false
                          text    = TEXT-061 ).


    DATA(it_ctxmenu) = VALUE ttb_btnmnu( ( function = 'BTN_MENU'
                                           ctmenu   = o_menu ) ).

    o_tool->assign_static_ctxmenu_table( it_ctxmenu ).

    "Separator
    o_tool->add_button( fcode       = ''
                        icon        = ''
                        butn_type   = cntb_btype_sep
                        text        = ''
                        quickinfo   = ''
                        is_checked  = abap_false
                        is_disabled = abap_false ).

    "Add Exit Button
    o_tool->add_button( fcode       = 'BTN_CLOSE'
                        icon        = icon_close
                        butn_type   = cntb_btype_button
                        text        = TEXT-062
                        quickinfo   = TEXT-062
                        is_checked  = abap_false
                        is_disabled = abap_false ).


  ENDMETHOD.

  METHOD field_catalog.

    IF me->lv_data_source EQ lcl_main_salv=>lif_data~t_database.

      "Set information regarding currency and quantity.It is not set automatically
      TRY.
          "Quantity
          CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( 'CHANGE' ) )->set_quantity_column( 'MEINS' )."Quantity Column and Unit of Measure

          "Currency
          CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( 'CHANGE' ) )->set_currency_column( 'WAERS' ). "Currency Value and Currency Key

        CATCH cx_salv_not_found cx_salv_data_error.     "#EC NO_HANDLER
      ENDTRY.

      "Show technical and regular column names at the same time as column names
      IF me->lv_technical_names EQ abap_true.
        LOOP AT me->lo_salv_alv->get_columns( )->get( ) ASSIGNING FIELD-SYMBOL(<c>).
          <c>-r_column->set_short_text( |{ <c>-r_column->get_columnname( ) } [{ <c>-r_column->get_short_text( ) }]| ).
          <c>-r_column->set_medium_text( |{ <c>-r_column->get_columnname( ) } [{ <c>-r_column->get_medium_text( ) }]| ).
          <c>-r_column->set_long_text( |{ <c>-r_column->get_columnname( ) } [{ <c>-r_column->get_long_text( ) }]| ).
        ENDLOOP.
      ENDIF.

      "For each column if Field Label is Initial set Column Name as Text

      LOOP AT me->lo_salv_alv->get_columns( )->get( ) ASSIGNING FIELD-SYMBOL(<fs_cols>).

        IF <fs_cols>-r_column->get_short_text( ) IS INITIAL.
          <fs_cols>-r_column->set_short_text( CONV #( <fs_cols>-columnname ) ).
        ENDIF.

        IF <fs_cols>-r_column->get_medium_text( ) IS INITIAL.
          <fs_cols>-r_column->set_medium_text( CONV #( <fs_cols>-columnname ) ).
        ENDIF.

        IF <fs_cols>-r_column->get_long_text( ) IS INITIAL.
          <fs_cols>-r_column->set_long_text( CONV #( <fs_cols>-columnname ) ).
        ENDIF.

      ENDLOOP.

      "Specify the name of the Column with No Field Labels-Build Field Catalog
      TRY.
          me->lo_salv_alv->get_columns( )->get_column('CHANGE' :
           )->set_long_text('CHANGE'),
           )->set_medium_text('CHANGE'),
           )->set_short_text('CHANGE').
        CATCH cx_salv_not_found .                       "#EC NO_HANDLER
      ENDTRY.

    ELSEIF me->lv_data_source EQ lcl_main_salv=>lif_data~t_excel.

      LOOP AT me->lo_salv_alv->get_columns( )->get( ) ASSIGNING FIELD-SYMBOL(<fs_col>).

        IF <fs_col>-r_column->get_short_text( ) IS INITIAL.
          <fs_col>-r_column->set_short_text( CONV #( <fs_col>-columnname ) ).
        ENDIF.

        IF <fs_col>-r_column->get_medium_text( ) IS INITIAL.
          <fs_col>-r_column->set_medium_text( CONV #( <fs_col>-columnname ) ).
        ENDIF.

        IF <fs_col>-r_column->get_long_text( ) IS INITIAL.
          <fs_col>-r_column->set_long_text( CONV #( <fs_col>-columnname ) ).
        ENDIF.

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD column_properties.

    "Center Columns
    LOOP AT me->lo_salv_alv->get_columns( )->get( ) ASSIGNING FIELD-SYMBOL(<c>).
      <c>-r_column->set_alignment( if_salv_c_alignment=>centered  ).
    ENDLOOP.

    "Optimize Columns Width
    me->lo_salv_alv->get_columns( )->set_optimize( if_salv_c_bool_sap=>true ).

    "Hide Zeros from Specific Column
    TRY.
        me->lo_salv_alv->get_columns( )->get_column('CHANGE')->set_zero( space ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.

    "Set Edit Mask(Conversion Exit) for a field
    TRY.
        "Use and Conversion Exit Function Module or Create your Own
        me->lo_salv_alv->get_columns( )->get_column('CHANGE')->set_edit_mask( '==OUTPUT_CONVERSION' ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.

    "Set the Cell Type
    TRY.
        me->lo_salv_alv->get_columns( )->set_cell_type_column( lc_cell_style ).
      CATCH cx_salv_data_error.                         "#EC NO_HANDLER
    ENDTRY.

    "COLOR LINE
    TRY.
        "Instructions: Include in your alv table color TYPE lvc_t_scol. Then populate the specific table for
        "every row that you want to color.Populate the line of the table by looping and add this code
        "<fs_table_line>-color = VALUE #( ( color-col = 5 color-int = 0 color-inv = 0 ) ).
        me->lo_salv_alv->get_columns( )->set_color_column(  lc_color_column ).
      CATCH cx_salv_data_error cx_salv_invalid_input.   "#EC NO_HANDLER
    ENDTRY.

    "COLOR COLUMN
    TRY.
        CAST cl_salv_column_table( me->lo_salv_alv->get_columns( )->get_column( me->lv_hotspot_field ) )->set_color( VALUE lvc_s_colo( col = me->lv_hotspot_color
                                                                                                                                       int = 1
                                                                                                                                       inv = 1 ) ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.

    "Add Icon To Column ICON
    TRY.
        CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( lc_icon_column ):
          )->set_icon( if_salv_c_bool_sap=>true ),
          )->set_alignment( if_salv_c_alignment=>centered ),
          )->set_short_text( 'Icon' ),
          )->set_medium_text( 'Icon Status' ),
          )->set_long_text( 'Icon Status' ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.

    "Add Checkbox Column
    TRY.
        CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( lc_checkbox  ):
         )->set_cell_type( if_salv_c_cell_type=>checkbox_hotspot ),
         )->set_output_length( 10 ),
         )->set_short_text( 'Checkbox' ),
         )->set_medium_text( 'Checkbox' ),
         )->set_long_text( 'Checkbox' ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.

    "Add Tooltips to Icons
    TRY.
        lo_salv_alv->get_functional_settings( )->get_tooltips( )->add_tooltip( type = cl_salv_tooltip=>c_type_icon
                                                                               value = |{ icon_green_light }|
                                                                               tooltip = CONV #( TEXT-044 ) ).
      CATCH cx_salv_existing.                           "#EC NO_HANDLER
    ENDTRY.

    "Add Tooltips to Fields
    TRY.
        lo_salv_alv->get_columns( )->get_column('CHANGE')->set_tooltip( 'Tooltip Text' ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.

    "Hide Specified Column
    TRY.
        lo_salv_alv->get_columns( )->get_column( 'CHANGE' )->set_visible( abap_false ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.

    "Display and fix column as key column
    TRY.
        "Define Column as Key Column
        CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( 'CHANGE' ) )->set_key( abap_true ).

        "Fix Key Columns
        lo_salv_alv->get_columns( )->set_key_fixation( abap_true ).
      CATCH cx_root.                                    "#EC NO_HANDLER
    ENDTRY.


    "Apply Filter for Column
    TRY.

        lo_salv_alv->get_filters(:
        )->remove_filter( 'CHANGE' ),"Remove Filter
        )->add_filter( columnname = 'CHANGE' sign = if_fsbp_const_range=>sign_include option = if_fsbp_const_range=>option_equal low = '100' ). "Add new Filter for Specific Column.

        "Save Filter to Table
        lt_filter_selopt  = lo_salv_alv->get_filters( )->get_filter( 'CHANGE' )->get( ).

      CATCH cx_salv_existing cx_salv_data_error cx_salv_not_found. "#EC NO_HANDLER
    ENDTRY.

    "AGGREGATIONS-TOTALS-----------------------------------------------------------------------
    TRY.
        "To add totals we need to use GET_AGGREGATIONS, once we get aggregations instance,
        "we need to add aggregation by passing column name and aggregation type to method ADD_AGGREGATION.

        lo_salv_alv->get_aggregations(:
        )->add_aggregation( columnname  = 'CHANGE'   "aggregation column name
                           aggregation = if_salv_c_aggregation=>total ),"aggregation type
        )->set_aggregation_before_items( value = abap_true )."Bring Aggregation to Top

      CATCH cx_salv_existing cx_salv_not_found cx_salv_data_error. "#EC NO_HANDLER
    ENDTRY.

    "SORTS-SUBTOTALS----------------------------------------------------------------------
    TRY.
        "To add subtotals, we need to add sort to the columns and then we have to use SET_SUBTOTAL method to display subtotals.

        "SORT
        DATA(lr_sort_column) = lo_salv_alv->get_sorts( )->add_sort( columnname = 'CHANGE'
                                                               "POSITION   =
                                                               "SEQUENCE   = IF_SALV_C_SORT=>SORT_UP
                                                               "SUBTOTAL   = IF_SALV_C_BOOL_SAP=>true
                                                               "GROUP      = IF_SALV_C_SORT=>GROUP_NONE
                                                               "OBLIGATORY = IF_SALV_C_BOOL_SAP=>FALSE
                                                               ).
        "SUBTOTALS
        lr_sort_column->set_subtotal( value = if_salv_c_bool_sap=>true ).

      CATCH cx_salv_existing cx_salv_not_found cx_salv_data_error . "#EC NO_HANDLER
    ENDTRY.

    "COLUMN SPECIFIC GROUPING----------------------------------------------------------------

    "Create Groups
    TRY.
        lo_salv_alv->get_functional_settings( )->get_specific_groups(:
                                                                )->add_specific_group( id   = 'AMOU' text = TEXT-063 ),
                                                                )->add_specific_group( id   = 'DATE' text = TEXT-064 ),
                                                                )->add_specific_group( id   = 'NCHA' text = TEXT-065 ),
                                                                )->add_specific_group( id   = 'CHAR' text = TEXT-066 ).

      CATCH cx_salv_existing.                           "#EC NO_HANDLER
    ENDTRY.


    "Dynamic Assignment of Columns to Groups
    LOOP AT CAST cl_abap_structdescr( CAST cl_abap_tabledescr( cl_abap_tabledescr=>describe_by_data( <fs_table> ) )->get_table_line_type( ) )->components ASSIGNING FIELD-SYMBOL(<ls_components>).

      CASE <ls_components>-type_kind.

        WHEN cl_abap_structdescr=>typekind_date.

          TRY.
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_specific_group( id = 'DATE' ).
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_visible( abap_true ).
            CATCH cx_salv_not_found.
          ENDTRY.

        WHEN cl_abap_structdescr=>typekind_packed.

          TRY.
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_specific_group( id = 'AMOU' ).
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_visible( abap_true ).
            CATCH cx_salv_not_found.
          ENDTRY.

        WHEN cl_abap_structdescr=>typekind_num.

          TRY.
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_specific_group( id = 'NCHA' ).
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_visible( abap_true ).
            CATCH cx_salv_not_found.
          ENDTRY.

        WHEN cl_abap_structdescr=>typekind_char.

          TRY.
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_specific_group( id = 'CHAR' ).
              CAST cl_salv_column_table( lo_salv_alv->get_columns( )->get_column( <ls_components>-name ) )->set_visible( abap_true ).
            CATCH cx_salv_not_found.
          ENDTRY.

      ENDCASE.

    ENDLOOP.


  ENDMETHOD.

  METHOD display_settings_header.

    "Enable Multiple Selection in the ALV Layout and Enable Left Column for Selection
    lo_salv_alv->get_selections( )->set_selection_mode( if_salv_c_selection_mode=>row_column )."cl_salv_selections=>multiple

    "Change Display Settings to Stripped and Activate/deactivate horizontal and vertical lines
    lo_salv_alv->get_display_settings(:
                                      )->set_striped_pattern( abap_true ),
                                      )->set_horizontal_lines( abap_true ),
                                      )->set_vertical_lines( abap_true ).
    "Layout Settings
    lo_salv_alv->get_layout(:
                            )->set_key( value = VALUE salv_s_layout_key( report = syst-repid ) ),
                            )->set_default( abap_true ),
                            )->set_save_restriction( if_salv_c_layout=>restrict_none ),
                            )->set_initial_layout( COND #( WHEN lv_layout IS NOT INITIAL THEN lv_layout ) ).


  ENDMETHOD.

  METHOD header_creation.

    CASE lv_version.
      WHEN lcl_main_salv=>lif_data~t_gui.

        lo_salv_alv->get_display_settings( :
           )->set_list_header_size( cl_salv_display_settings=>c_header_size_medium ),
           )->set_list_header( |{ TEXT-045 } { syst-uname  } { TEXT-047 } { syst-datum  DATE = USER } { syst-uzeit  TIME = USER }{ TEXT-048 }{ lines( <fs_table> ) } | ).

      WHEN lcl_main_salv=>lif_data~t_fiori.

        lo_salv_alv->get_display_settings(:
          )->set_list_header_size( cl_salv_display_settings=>c_header_size_medium ),
          )->set_list_header( |{ TEXT-046 } { lines( <fs_table> ) } | ).

        me->header_creation_fiori( ).

    ENDCASE.

  ENDMETHOD.

  METHOD header_creation_fiori.

    DATA(lo_header) = NEW cl_salv_form_layout_grid( ).

    "Information in Bold
    lo_header->create_label( row = 1 column = 1 )->set_text( TEXT-049 ).

    "Information in tabular format
    lo_header->create_flow( row = 2 column = 1 )->create_text( text = |{ TEXT-045 } { syst-uname } { TEXT-047 } { syst-datum  DATE = USER } { syst-uzeit  TIME = USER } | ).

    "Set the top of list using the header for Online
    lo_salv_alv->set_top_of_list( lo_header ).

    "Set the top of list using the header for Print
    lo_salv_alv->set_top_of_list_print( lo_header ).

  ENDMETHOD.

  METHOD footer_creation.

    DATA(lo_footer) = NEW cl_salv_form_layout_grid( ).

    DATA(lo_f_label) = lo_footer->create_label( row = 1 column = 1 )  .
    lo_f_label->set_text( TEXT-053 ).

    DATA(lo_f_flow) = lo_footer->create_flow( row = 2 column = 1 ).

    lo_f_flow->create_text( text = COND #( WHEN lv_data_source EQ lcl_main_salv=>lif_data~t_database THEN |{ TEXT-050 }|
                                           WHEN lv_data_source EQ lcl_main_salv=>lif_data~t_excel    THEN  |{ TEXT-051 }|
                                           ELSE |{ TEXT-052 }| ) ).
    lo_salv_alv->set_end_of_list( lo_footer ).
    lo_salv_alv->set_end_of_list_print( lo_footer ).

  ENDMETHOD.

  METHOD toolbar_status.

    IF lv_status IS NOT INITIAL AND lv_version EQ lcl_main_salv=>lif_data~t_fiori.

      TRY.
          lo_salv_alv->set_screen_status(
            pfstatus      = lv_status
            report        = syst-cprog
            set_functions = lo_salv_alv->c_functions_all ).
        CATCH cx_salv_method_not_supported cx_salv_object_not_found. "#EC NO_HANDLER
      ENDTRY.

    ELSEIF lv_version EQ lcl_main_salv=>lif_data~t_fiori.

      lo_salv_alv->get_functions( )->set_all( if_salv_c_bool_sap=>true ).

    ELSEIF lv_version EQ lcl_main_salv=>lif_data~t_gui.

      lo_salv_alv->get_functions( )->set_all( if_salv_c_bool_sap=>true ).

      "Add Custom Buttons
      TRY.

          lo_salv_alv->get_functions(:
                               )->add_function( name     = 'DETAILS'
                                                icon     = |{ icon_overview }|
                                                text     = CONV #( TEXT-067 )
                                                tooltip  = CONV #( TEXT-072 )
                                                position = if_salv_c_function_position=>right_of_salv_functions ),
                               )->add_function( name     = 'EDIT'
                                                icon     = |{ icon_operation }|
                                                text     = CONV #( TEXT-071 )
                                                tooltip  = CONV #( TEXT-070 )
                                                position = if_salv_c_function_position=>right_of_salv_functions ),
                               )->add_function( name     = 'COLUMNS'
                                                icon     = |{ icon_businav_sysorgi }|
                                                text     = ''
                                                tooltip  = CONV #( TEXT-069 )
                                                position = if_salv_c_function_position=>right_of_salv_functions ),
                               )->add_function( name     = 'DOCU'
                                                icon     = |{ icon_message_information_small }|
                                                text     = ''
                                                tooltip  = CONV #( TEXT-068 )
                                                position = if_salv_c_function_position=>right_of_salv_functions ).


        CATCH cx_salv_existing cx_salv_wrong_call cx_salv_method_not_supported. "#EC NO_HANDLER
      ENDTRY.

      "Suppress the toolbar of the list output
      cl_abap_list_layout=>suppress_toolbar( ).

    ENDIF.

  ENDMETHOD.

  METHOD handle_gui_grid_events.

    IF lv_handle_gui_grid_events EQ abap_true.

      SET HANDLER me->event_after_refresh FOR ALL INSTANCES.
      lo_salv_alv->refresh( ).

    ENDIF.

  ENDMETHOD.

  METHOD event_handling.

    "Handler for Double Click Event and User Command(Button) and Hotspot Handling
    SET HANDLER: me->handle_double_click    FOR lo_salv_alv->get_event( ) ACTIVATION abap_true,
                 me->on_user_command        FOR lo_salv_alv->get_event( ) ACTIVATION abap_true,
                 me->handle_hotspot         FOR lo_salv_alv->get_event( ) ACTIVATION abap_true,
                 me->on_end_of_page         FOR lo_salv_alv->get_event( ) ACTIVATION abap_true,
                 me->on_top_of_page         FOR lo_salv_alv->get_event( ) ACTIVATION abap_true,
                 me->on_after_salv_function FOR lo_salv_alv->get_event( ) ACTIVATION abap_true.

    "Set Desired Field Hotspot Enabled
    me->set_hotspot( im_alv   = me->lo_salv_alv
                     im_field = me->lv_hotspot_field ).

  ENDMETHOD.

  METHOD display_alv.

    lo_salv_alv->display( ).

    "Force Container Generation
    IF lv_version EQ lcl_main_salv=>lif_data~t_gui.
      WRITE:/ space.
    ENDIF.

  ENDMETHOD.

  METHOD return_salv_instance.

    re_salv = me->lo_salv_alv.

  ENDMETHOD.

  METHOD on_function_selected.

    CASE fcode.
      WHEN 'BTN_CLOSE'.
        LEAVE LIST-PROCESSING.
      WHEN 'F1'.
        MESSAGE fcode TYPE gc_msg_type_info DISPLAY LIKE gc_msg_type_status.
      WHEN 'F2'.
        MESSAGE fcode TYPE gc_msg_type_info DISPLAY LIKE gc_msg_type_status.
    ENDCASE.

  ENDMETHOD.

  METHOD on_after_salv_function.

    CHECK e_salv_function EQ '&ILT' OR  " Apply Filter
          e_salv_function EQ '&ILD'.    " Delete Filter

    "STATIC FILTERS.CHECK FOR FILTER CHANGE OR DELETION.IF THE FILTER
    "IS NOT THE SAME AS WHAT WE HAVE APPLIED INITIALLY THEN PUT BACK THE FILTER

    TRY.

        DATA(lo_filters) = lo_salv_alv->get_filters( ).
        DATA(lo_filter)  = lo_filters->get_filter( 'FILTER' ).

        "filter still there, check for the values
        DATA(lt_selopt) = lo_filter->get( ).
        IF lt_selopt NE me->lt_filter_selopt.

          TRY.
              lo_filters->add_filter( columnname = 'CHANGE'
                                      sign       = 'I'
                                      option     = 'EQ'
                                      low        = 'VALUE').

            CATCH cx_salv_not_found cx_salv_data_error  cx_salv_existing. "#EC NO_HANDLER

          ENDTRY.

        ENDIF.

      CATCH cx_salv_not_found.

        "when Filter is removed, this exception would be raised.
        "set it back
        TRY.
            lo_filters->add_filter( columnname = 'CHANGE'
                                    sign       = 'I'
                                    option     = 'EQ'
                                    low        = 'VALUE').

          CATCH cx_salv_not_found cx_salv_data_error  cx_salv_existing. "#EC NO_HANDLER

        ENDTRY.

    ENDTRY.

  ENDMETHOD.

  METHOD event_after_refresh.

    CHECK handler_added EQ abap_false.
    SET HANDLER me->on_toolbar FOR sender.

    SET HANDLER me->event_after_refresh  FOR ALL INSTANCES ACTIVATION space.

    sender->set_delay_change_selection(
      EXPORTING
        time   =  100  "Time in Milliseconds
      EXCEPTIONS
        error  = 1
        OTHERS = 2 ).

    sender->register_delayed_event( EXPORTING  i_event_id = sender->mc_evt_delayed_change_select
                                    EXCEPTIONS error      = 1
                                               OTHERS     = 2 ).

    sender->get_frontend_fieldcatalog(
      IMPORTING
        et_fieldcatalog = DATA(fcat) ).    " Field Catalog

    "setting editable field
    ASSIGN fcat[ fieldname = p_editf ] TO FIELD-SYMBOL(<fcat>).
    IF syst-subrc IS INITIAL.
      <fcat>-edit = abap_true.
    ENDIF.

    sender->set_frontend_fieldcatalog( it_fieldcatalog = fcat ).
    sender->register_edit_event(
      EXPORTING
        i_event_id = sender->mc_evt_modified    " Event ID
      EXCEPTIONS
        error      = 1
        OTHERS     = 2 ).


    sender->set_ready_for_input( i_ready_for_input = 1 ).

    handler_added = abap_true.
    sender->refresh_table_display( ).

  ENDMETHOD.

  METHOD on_toolbar.

    "Toolbar Seperator
    APPEND VALUE #( function   = cl_gui_alv_grid=>mc_fc_separator
                    butn_type  = 3 ) TO e_object->mt_toolbar.

    "Toolbar Button APPEND ROW
    APPEND VALUE #( function   = cl_gui_alv_grid=>mc_fc_loc_append_row
                    quickinfo  = TEXT-073
                    icon       = icon_create
                    disabled   = space ) TO e_object->mt_toolbar.

    "Toolbar Button INSERT ROW
    APPEND VALUE #( function   = cl_gui_alv_grid=>mc_fc_loc_insert_row
                    quickinfo  = TEXT-074
                    icon       = icon_insert_row
                    disabled   = space ) TO e_object->mt_toolbar.


    "Toolbar Button DELETE ROW
    APPEND VALUE #( function   = cl_gui_alv_grid=>mc_fc_loc_delete_row
                    quickinfo  = TEXT-075
                    icon       = icon_delete_row
                    disabled   = space ) TO e_object->mt_toolbar.

    "Toolbar Button COPY ROW
    APPEND VALUE #( function   = cl_gui_alv_grid=>mc_fc_loc_copy_row
                    quickinfo  = TEXT-076
                    icon       = icon_copy_object
                    disabled   = space ) TO e_object->mt_toolbar.

    "Toolbar Button UNDO
    APPEND VALUE #( function   = cl_gui_alv_grid=>mc_fc_loc_undo
                    quickinfo  = TEXT-077
                    icon       = icon_system_undo
                    disabled   = space ) TO e_object->mt_toolbar.

    "Toolbar Separator
    APPEND VALUE #( function   = cl_gui_alv_grid=>mc_fc_separator
                    butn_type  = 3 ) TO e_object->mt_toolbar.

  ENDMETHOD."on_toolbar

  METHOD display_details_of_selection.

    DATA(lt_selected_rows) = me->lo_salv_alv->get_selections( )->get_selected_rows( ).
    CHECK lt_selected_rows IS NOT INITIAL.

    TRY.

        ASSIGN <fs_table>[ VALUE #( lt_selected_rows[ 1 ] OPTIONAL ) ] TO FIELD-SYMBOL(<fs_data>).
        CHECK <fs_data> IS ASSIGNED.

        DATA(lo_struct) = CAST cl_abap_structdescr( CAST cl_abap_tabledescr( cl_abap_tabledescr=>describe_by_data( <fs_table> ) )->get_table_line_type( ) ).

        "Populate LT_DETAILS Table with the Values from the Row Selected
        DATA(lt_details) = VALUE se16n_selfields_t_in( ).
        LOOP AT lo_struct->components ASSIGNING FIELD-SYMBOL(<fs_component>).

          "Check if Column is Displayed in ALV
          TRY.
              IF NOT me->lo_salv_alv->get_columns( )->get_column( <fs_component>-name )->is_visible( ).
                CONTINUE.
              ENDIF.
            CATCH cx_salv_not_found.                    "#EC NO_HANDLER
              CONTINUE.
          ENDTRY.

          "FIELD VALUE AS PREVIEWED AND UNCONVERTED
          ASSIGN COMPONENT <fs_component>-name OF STRUCTURE <fs_data> TO FIELD-SYMBOL(<fs_value>).
          IF <fs_value> IS NOT ASSIGNED OR syst-subrc IS NOT INITIAL.
            CONTINUE.
          ENDIF.

          "Check that <fs_value> is not structure or table
          DATA(lo_type) = cl_abap_typedescr=>describe_by_data( <fs_value> ).
          IF lo_type->type_kind EQ cl_abap_typedescr=>typekind_struct1 OR
             lo_type->type_kind EQ cl_abap_typedescr=>typekind_table.
            CONTINUE.
          ENDIF.

          "Get Data Dictionary Type of the Component
          DATA(lo_element_def) = CAST cl_abap_elemdescr( lo_struct->get_component_type( <fs_component>-name ) ).

          APPEND VALUE #( low        = |{ <fs_value> ALPHA = OUT }|
                          low_noconv = |{ <fs_value> }|
                          scrtext_l  = COND #( WHEN NOT lo_element_def->is_ddic_type( ) THEN <fs_component>-name
                                               ELSE get_text_label_of_rollname( lo_element_def->get_ddic_field( )-rollname ) )
                          fieldname  = <fs_component>-name  ) TO lt_details.

          CLEAR: lo_element_def,lo_type.

        ENDLOOP.

        CALL FUNCTION 'TSWUSL_SHOW_DETAIL'
          TABLES
            it_selfields  = lt_details
          EXCEPTIONS
            error_message = 1
            OTHERS        = 2.

      CATCH cx_root INTO DATA(lo_exception).
        MESSAGE TEXT-039 TYPE gc_msg_type_info DISPLAY LIKE gc_msg_type_error.
    ENDTRY.

  ENDMETHOD.

  METHOD get_text_label_of_rollname.

    CHECK im_rollname IS NOT INITIAL.

    SELECT SINGLE scrtext_l
     FROM  dd04t
     INTO  @re_text_label
     WHERE rollname   EQ @im_rollname AND
           ddlanguage EQ @syst-langu.

    IF re_text_label IS INITIAL.

      SELECT SINGLE reptext
       FROM  dd04t
       INTO  @re_text_label
       WHERE rollname   EQ @im_rollname AND
             ddlanguage EQ @syst-langu.

    ENDIF.

  ENDMETHOD.

  METHOD display_documentation.

    "GOTO TRANSACTION SE61 AND CREATE DIALOG TEXT TO DISPLAY
    CALL FUNCTION 'POPUP_DISPLAY_TEXT'
      EXPORTING
        language       = syst-langu
        popup_title    = 'Documetation'
        start_column   = 10
        start_row      = 3
        text_object    = 'ALLGEM_DATEN'
      EXCEPTIONS
        text_not_found = 1
        error_message  = 2
        OTHERS         = 3.

    IF syst-subrc IS NOT INITIAL.
      MESSAGE TEXT-038 TYPE gc_msg_type_info DISPLAY LIKE gc_msg_type_error.
    ENDIF.

  ENDMETHOD.

  METHOD show_hide_empty_columns.

    "Get Empty Columns of ALV
    IF me->lt_empty_columns IS INITIAL.

      LOOP AT me->lo_salv_alv->get_columns( )->get( ) ASSIGNING FIELD-SYMBOL(<column>).

        DATA(lv_empty_indicator) = CONV abap_bool( abap_true ) ##OPERATOR[ABAP_BOOL].
        LOOP AT <fs_table> ASSIGNING FIELD-SYMBOL(<fs_structure>).

          ASSIGN COMPONENT <column>-columnname OF STRUCTURE <fs_structure> TO  FIELD-SYMBOL(<fs_value>).

          IF <fs_value> IS ASSIGNED AND syst-subrc IS INITIAL.

            IF <fs_value> IS INITIAL."EMPTY VALUE
              CONTINUE.
            ELSE."FILLED CELL
              lv_empty_indicator = abap_false.
              EXIT.
            ENDIF.

          ENDIF.

        ENDLOOP.

        IF lv_empty_indicator EQ abap_true.
          APPEND <column>-columnname TO me->lt_empty_columns.
        ENDIF.

      ENDLOOP.

    ENDIF.

    "Hide/Show Empty Columns
    LOOP AT me->lt_empty_columns ASSIGNING FIELD-SYMBOL(<fs_empty_column>).

      CASE lv_show_hide.

        WHEN abap_false.

          TRY.
              CAST cl_salv_column_table( me->lo_salv_alv->get_columns( )->get_column( <fs_empty_column>-column_name ) )->set_visible( if_salv_c_bool_sap=>false ).
            CATCH cx_salv_not_found.                    "#EC NO_HANDLER
          ENDTRY.

        WHEN abap_true.

          TRY.
              CAST cl_salv_column_table( me->lo_salv_alv->get_columns( )->get_column( <fs_empty_column>-column_name ) )->set_visible( if_salv_c_bool_sap=>true ).
            CATCH cx_salv_not_found.                    "#EC NO_HANDLER
          ENDTRY.

      ENDCASE.

    ENDLOOP.

    me->lv_show_hide = xsdbool( me->lv_show_hide EQ abap_false )."Flip Toggle TRUE-FALSE

  ENDMETHOD.

  METHOD on_top_of_page.

  ENDMETHOD.

  METHOD on_end_of_page.

  ENDMETHOD.

  METHOD handle_double_click.

    CASE column.

      WHEN '&&MARK&&'.

        me->display_details_of_selection( ).

      WHEN OTHERS.

        "Flip Toggle TRUE-FALSE
        me->lv_editable = xsdbool( me->lv_editable EQ abap_false ).

        "OPEN EDIT FOR SPECIFIC COLUMN THAT THE USER DOUBLE CLICKED
        lcl_salv_edit=>set_editable( im_fieldname  = column
                                     im_salv_table = me->lo_salv_alv
                                     im_editable   = me->lv_editable ).

    ENDCASE.

  ENDMETHOD. "handle_double_click

  METHOD on_user_command.

    CASE e_salv_function.

      WHEN 'EDIT'."BUTTON THAT THE USER PRESSES.

        me->lv_editable = xsdbool( me->lv_editable EQ abap_false )."Flip Toggle TRUE-FALSE
        lcl_salv_edit=>set_editable( im_salv_table = me->lo_salv_alv
                                     im_editable   = me->lv_editable )."OPEN ALV EDIT FOR WHOLE TABLE

      WHEN 'COLUMNS'.

        me->show_hide_empty_columns( ).
        me->lo_salv_alv->refresh( s_stable     = VALUE #( col = abap_true row = abap_true )
                                  refresh_mode = if_salv_c_refresh=>soft ).

      WHEN 'DETAILS'.

        me->display_details_of_selection( ).

      WHEN 'DOCU'.

        me->display_documentation( ).

      WHEN OTHERS.

    ENDCASE.

  ENDMETHOD. "on_user_command

  METHOD set_hotspot.

    CHECK im_field IS NOT INITIAL AND im_alv IS BOUND.

    TRY.
        CAST cl_salv_column_table( im_alv->get_columns( )->get_column( im_field ) )->set_cell_type( value = if_salv_c_cell_type=>hotspot ).
      CATCH cx_salv_not_found cx_salv_data_error cx_sy_ref_is_initial. "#EC NO_HANDLER
    ENDTRY.

  ENDMETHOD.

  METHOD handle_hotspot.

    ASSIGN <fs_table>[ row ]  TO FIELD-SYMBOL(<fs_structure>).
    CHECK syst-subrc IS INITIAL.

    ASSIGN COMPONENT column OF STRUCTURE <fs_structure> TO FIELD-SYMBOL(<fs_field_value>).
    CHECK syst-subrc IS INITIAL.

    CASE column.

      WHEN lcl_main_salv=>lc_checkbox .

        <fs_field_value> = COND #( WHEN <fs_field_value> IS INITIAL THEN abap_true
                                   ELSE abap_false ).

        me->lo_salv_alv->refresh( ).

      WHEN OTHERS.

        IF <fs_field_value> IS ASSIGNED.

          cl_demo_output=>new( mode = cl_demo_output=>text_mode
          )->write_text( |{ TEXT-054 } { column } { TEXT-055 } { row } |
          )->write_text( |{ TEXT-056 } { <fs_field_value> } |
          )->display( ).

        ENDIF.

    ENDCASE.

  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
*       CLASS lcl_utilities IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_utilities IMPLEMENTATION.

  METHOD upload_excel.

    DATA lt_records TYPE solix_tab.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = CONV #( im_filepath )
        filetype                = 'BIN'
      IMPORTING
        filelength              = DATA(lv_filelength)
        header                  = DATA(lv_headerxstring)
      CHANGING
        data_tab                = lt_records
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        dp_out_of_memory        = 14
        disk_full               = 15
        dp_timeout              = 16
        not_supported_by_gui    = 17
        error_no_gui            = 18
        OTHERS                  = 19 ).

    IF syst-subrc IS NOT INITIAL.
      RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( TEXT-037 ).
    ENDIF.

    CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
      EXPORTING
        input_length  = lv_filelength
      IMPORTING
        buffer        = lv_headerxstring
      TABLES
        binary_tab    = lt_records
      EXCEPTIONS
        failed        = 1
        error_message = 2
        OTHERS        = 3.

    IF syst-subrc IS NOT INITIAL.
      RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( TEXT-037 ).
    ENDIF.

    TRY.
        DATA(lo_excel_ref) = NEW cl_fdt_xl_spreadsheet(
                                document_name = CONV #( im_filepath )
                                xdocument     = lv_headerxstring ) .
      CATCH cx_fdt_excel_core INTO DATA(ex_ref).
        RAISE EXCEPTION TYPE lcx_exception EXPORTING im_text = CONV #( ex_ref->get_text( ) ).
    ENDTRY.

    lo_excel_ref->if_fdt_doc_spreadsheet~get_worksheet_names( IMPORTING worksheet_names = DATA(t_worksheets) ).

    ex_table = lo_excel_ref->if_fdt_doc_spreadsheet~get_itab_from_worksheet( COND #(  WHEN im_sheet_name IS NOT INITIAL AND line_exists( t_worksheets[ table_line = im_sheet_name  ]  )
                                                                                      THEN VALUE #( t_worksheets[ table_line = im_sheet_name  ] OPTIONAL )
                                                                                      ELSE VALUE #( t_worksheets[ 1 ] OPTIONAL )  ) ).

  ENDMETHOD.

  METHOD get_structured_table_from_gen.

    TYPES: BEGIN OF ty_column_structure,
             component TYPE string,
             column    TYPE i,
           END OF ty_column_structure.

    DATA: t_column TYPE TABLE OF ty_column_structure,
          v_index  TYPE i,
          v_column TYPE i,
          ref_wa   TYPE REF TO data.

    FIELD-SYMBOLS: <fs_itab> TYPE ANY TABLE,
                   <fs_wa>   TYPE any.

    "CHECK IMPORTING TABLE IS NOT INITIAL
    CHECK im_table IS NOT INITIAL.

    "CREATE A DYNAMIC TABLE WITH THE SAME STRUCTURE AS TARGETED TABLE
    ASSIGN ex_table  TO <fs_itab>.

    "DATA REFERENCE
    CREATE DATA ref_wa LIKE LINE OF <fs_itab>.
    ASSIGN ref_wa->* TO <fs_wa>.

    IF im_map_by_structure EQ abap_false."GET STRUCTURE FROM TABLE ROW

      "GET THE COLUMN NAMES FROM THE SPECIFIED ROW(IMPORTING PARAMETER)
      CLEAR t_column.
      CLEAR:v_index.
      LOOP AT im_table ASSIGNING FIELD-SYMBOL(<s_tab>).
        v_index = v_index + 1.

        IF v_index EQ im_structure_line."LOOP ONLY THE SPECIFIED STRUCTURE ROW
          CLEAR v_column.
          DO.
            v_column = v_column + 1.
            ASSIGN COMPONENT v_column OF STRUCTURE <s_tab> TO FIELD-SYMBOL(<fs_any>).
            IF syst-subrc IS INITIAL.
              APPEND VALUE #( component =  <fs_any> column = v_column ) TO t_column.
            ELSE.
              EXIT.
            ENDIF.
          ENDDO.
          EXIT.
        ENDIF.

      ENDLOOP.

    ELSEIF im_map_by_structure EQ abap_true."GET STRUCTURE FROM TABLE COMPONENTS

      DATA(lo_type_def)   = CAST cl_abap_tabledescr( cl_abap_tabledescr=>describe_by_data( ex_table ) ).
      DATA(lo_struct_def) = CAST cl_abap_structdescr( lo_type_def->get_table_line_type( ) ).

      CLEAR: v_column.
      LOOP AT lo_struct_def->components ASSIGNING FIELD-SYMBOL(<fs_components>) WHERE type_kind NE cl_abap_typedescr=>typekind_table AND
                                                                                      type_kind NE cl_abap_typedescr=>typekind_struct1 AND
                                                                                      name NE lcl_main_salv=>lc_checkbox AND
                                                                                      name NE lcl_main_salv=>lc_icon_column.
        v_column = v_column + 1.
        APPEND VALUE #( component =  <fs_components>-name column = v_column ) TO t_column.
      ENDLOOP.

    ENDIF.

    DELETE t_column WHERE component IS INITIAL.

    "PASS DATA TO TABLE
    CLEAR v_index.
    LOOP AT im_table ASSIGNING <s_tab>.
      v_index = v_index + 1.

      IF v_index LT im_start_line.
        CONTINUE.
      ENDIF.

      "START FROM DATA LINE(IMPORTING PARAMETER)
      CLEAR <fs_wa>.
      LOOP AT t_column INTO DATA(s_column).

        "GETS THE FIELD OF THE TABLE TO BE MAPPED
        ASSIGN COMPONENT s_column-component OF STRUCTURE <fs_wa> TO FIELD-SYMBOL(<fs_any_tab>).
        IF syst-subrc IS NOT INITIAL.
          CONTINUE.
        ENDIF.

        "GETS THE VALUE TO BE TRANSFERRED
        ASSIGN COMPONENT s_column-column OF STRUCTURE <s_tab> TO <fs_any>.
        IF syst-subrc IS NOT INITIAL.
          CONTINUE.
        ENDIF.

        "CONVERT FIELD TO CHARACTER
        DATA(lr_elem) =  cl_abap_elemdescr=>describe_by_data( <fs_any_tab> ).
        IF lr_elem->type_kind EQ lr_elem->typekind_date."CONVERT DATE TO INTERNAL FORMAT

          <fs_any_tab> = lcl_utilities=>date_external_to_internal( CONV #( <fs_any> ) ) .

        ELSEIF lr_elem->type_kind EQ lr_elem->typekind_packed AND <fs_any>  CP '*E*'."CONVERT PACKED TO CHARACTER.E IS THE LAST NUMBER OF DECIMALS

          CALL FUNCTION 'C14W_NUMBER_CHAR_CONVERSION'
            EXPORTING
              i_float       = CONV f( <fs_any> )
            IMPORTING
              e_dec         = <fs_any_tab>
            EXCEPTIONS
              error_message = 1
              OTHERS        = 2.

        ELSEIF lr_elem->type_kind EQ lr_elem->typekind_packed AND <fs_any> CP '-*'."CONVERT PACKED TO CHARACTER
          <fs_any_tab> = |{  <fs_any>+1 }| && '-'.
        ELSE."PASS THE VALUE AS IS
          <fs_any_tab> = <fs_any> .
        ENDIF.

      ENDLOOP.

      "APPEND TO EXPORTING TABLE
      INSERT <fs_wa> INTO TABLE ex_table .

    ENDLOOP.

  ENDMETHOD.

  METHOD f4_salv.

    cv_layout = cl_salv_layout_service=>f4_layouts( s_key    = VALUE salv_s_layout_key( report = syst-repid )
                                                    restrict = if_salv_c_layout=>restrict_none  )-layout.

  ENDMETHOD.

  METHOD date_external_to_internal.

    CLEAR re_date_internal.
    DATA(lv_convert_date) = CONV tumls_date( im_date ).

    CALL FUNCTION '/SAPDMC/LSM_DATE_CONVERT'
      EXPORTING
        date_in             = lv_convert_date
        date_format_in      = COND #( WHEN cl_abap_matcher=>create( pattern = '^\d{4}[/|-|.|-]\d{1,2}[/|-|.|-]\d{1,2}$' text = lv_convert_date )->match( ) EQ abap_true ##REGEX_POSIX
                                      THEN 'DYMD'"Date Format YYYY/MM/DD
                                      WHEN cl_abap_matcher=>create( pattern = '^\d{1,2}[/|-|.|-]\d{1,2}[/|-|.|-]\d{4}$' text = lv_convert_date )->match( ) EQ abap_true
                                      THEN 'DDMY'"Date Format DD/MM/YYYY
                                      ELSE 'DMDY'"DATE FORMAT MM/DD/YYYY
                                      )
        to_output_format    = abap_false
        to_internal_format  = abap_true
      IMPORTING
        date_out            = lv_convert_date
      EXCEPTIONS
        illegal_date        = 1
        illegal_date_format = 2
        no_user_date_format = 3
        error_message       = 4
        OTHERS              = 5.

    re_date_internal =  COND #( WHEN syst-subrc IS INITIAL THEN lv_convert_date
                        ELSE im_date ).

  ENDMETHOD.

  METHOD check_field_exists_in_table.

    SELECT SINGLE FROM dd03l
      FIELDS @abap_true
      WHERE tabname   EQ @im_table
        AND fieldname EQ @im_field
      INTO @re_exists.

  ENDMETHOD.

  METHOD alpha_conversion.

    "Initialize output value to input value.
    ev_output = iv_input.

    DATA(lo_elem) = CAST cl_abap_elemdescr( cl_abap_elemdescr=>describe_by_data( iv_input ) ).

    "If the data has no DDIC structure or no Conversion Routine then Exit
    IF NOT lo_elem->is_ddic_type( )
       OR lo_elem->get_ddic_field( )-convexit IS INITIAL.
      RETURN.
    ENDIF.

    "Alpha Conversion
    DATA(function_conversion) = to_upper( condense( |CONVERSION_EXIT_{ lo_elem->get_ddic_field( )-convexit }_{ SWITCH string( im_alpha
                                                                                                               WHEN lcl_utilities=>s_alpha_conversion-in  THEN 'INPUT'
                                                                                                               WHEN lcl_utilities=>s_alpha_conversion-out THEN 'OUTPUT'
                                                                                                               ELSE 'INPUT'"ELSE THROW EXCEPTION
                                                                                                              ) } | ) ).
    TRY.
        CALL FUNCTION function_conversion
          EXPORTING
            input         = iv_input
          IMPORTING
            output        = ev_output
          EXCEPTIONS
            error_message = 1
            OTHERS        = 2.
      CATCH cx_sy_dyn_call_illegal_type cx_sy_dyn_call_illegal_func.
    ENDTRY.

  ENDMETHOD.

  METHOD dynamic_where_clause.

    IF im_field IS NOT INITIAL AND im_comp IS NOT INITIAL AND im_val IS NOT INITIAL.

      "CHECK FIELD EXISTS IN CURRENT TABLE
      DATA(lv_field_exists) = lcl_utilities=>check_field_exists_in_table( im_field = im_field
                                                                          im_table = im_table_name ).
      CHECK lv_field_exists EQ abap_true.

      "Create Variable based on field Type
      DATA dref TYPE REF TO data.

      DATA(type)         = im_table_name && '-' && im_field.
      DATA(lv_data_type) =  cl_abap_typedescr=>describe_by_name( type )->type_kind.

      CASE lv_data_type.

        WHEN 'D'."DATE
          DATA(lv_internal) = lcl_utilities=>date_external_to_internal( im_val ).
        WHEN OTHERS.

          CREATE DATA dref TYPE (type).
          ASSIGN dref->* TO FIELD-SYMBOL(<fs_val>).

          IF <fs_val> IS ASSIGNED.
            <fs_val> = im_val.
            lcl_utilities=>alpha_conversion( EXPORTING iv_input  = <fs_val>
                                                       im_alpha  = lcl_utilities=>s_alpha_conversion-in
                                             IMPORTING ev_output = lv_internal ).
          ELSE.
            lv_internal = im_val.
          ENDIF.

      ENDCASE.

      DATA(lt_condtab) = VALUE hrtb_cond( ( field = im_field
                                            opera = im_comp
                                            low   = lv_internal ) ).

      CALL FUNCTION 'RH_DYNAMIC_WHERE_BUILD'
        EXPORTING
          dbtable         = im_table_name
        TABLES
          condtab         = lt_condtab
          where_clause    = re_select_clause
        EXCEPTIONS
          empty_condtab   = 1
          no_db_field     = 2
          unknown_db      = 3
          wrong_condition = 4
          error_message   = 5
          OTHERS          = 6.

    ENDIF.

  ENDMETHOD.

  METHOD open_dialog_excel.

    DATA: lt_file_table TYPE filetable,
          lv_return     TYPE i.

    CLEAR:lt_file_table.
    cl_gui_frontend_services=>file_open_dialog(
      EXPORTING
        window_title            = CONV #( TEXT-036 )
        default_extension       = cl_gui_frontend_services=>filetype_excel
        file_filter             = 'All Files(*.*)|*.*|' && 'Excel Files (*.xlsx)|*.xlsx|' && 'Excel Files (*.xls)|*.xls|'
      CHANGING
        file_table              = lt_file_table
        rc                      = lv_return
      EXCEPTIONS
        file_open_dialog_failed = 1
        cntl_error              = 2
        error_no_gui            = 3
        OTHERS                  = 4 ).

    CHECK syst-subrc IS INITIAL AND lt_file_table IS NOT INITIAL.

    re_filepath =  VALUE #( lt_file_table[ 1 ]-filename OPTIONAL ).

  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
*       CLASS lcl_salv_edit IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_salv_edit IMPLEMENTATION.

  METHOD get_control.

    IF im_salv IS NOT BOUND.
      RETURN.
    ENDIF.

    "FROM RELEASE 7.55 CL_SALV_TABLE NO LONGER CARRIES THE CONTROLLER ITSELF AND
    "THE ADAPTER CLASSES KEEP GET_GRID PROTECTED. THE MODEL BEHIND
    "EXTENDED_GRID_API DOES CARRY IT, AND IF_SALV_TABLE_DISPLAY_ADAPTER IS THE
    "RELEASED WAY DOWN TO THE UNDERLYING CL_GUI_ALV_GRID. INHERITING FROM
    "CL_SALV_MODEL_BASE IS WHAT MAKES R_CONTROLLER REACHABLE FROM HERE
    TRY.
        DATA(lo_model) = CAST cl_salv_model_base( im_salv->extended_grid_api( ) ).
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.

    IF lo_model->r_controller IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lo_adapter) = lo_model->r_controller->r_adapter.

    "A LIST OR TREE ADAPTER HAS NO GRID BEHIND IT. SET_EDITABLE REPORTS THE
    "INITIAL REFERENCE RATHER THAN FAILING SILENTLY
    IF lo_adapter IS NOT INSTANCE OF if_salv_table_display_adapter.
      RETURN.
    ENDIF.

    re_grid = CAST if_salv_table_display_adapter( lo_adapter )->get_grid( ).

  ENDMETHOD.

  METHOD set_editable.

    DATA(lo_grid) = get_control( im_salv_table ).

    IF lo_grid IS NOT BOUND.
      MESSAGE 'Editing is not available for this ALV'(079) TYPE gc_msg_type_info DISPLAY LIKE gc_msg_type_error.
      RETURN.
    ENDIF.

    IF im_fieldname IS SUPPLIED AND im_fieldname IS NOT INITIAL."EDIT SPECIFIC COLUMN

      lo_grid->get_frontend_fieldcatalog( IMPORTING et_fieldcatalog = DATA(lt_fieldcat) ).

      "ASSIGN ON A TABLE EXPRESSION SETS SY-SUBRC INSTEAD OF RAISING
      ASSIGN lt_fieldcat[ fieldname = im_fieldname ] TO FIELD-SYMBOL(<fs_fieldcat>).

      IF <fs_fieldcat> IS NOT ASSIGNED.
        RETURN.
      ENDIF.

      <fs_fieldcat>-edit = im_editable.
      lo_grid->set_frontend_fieldcatalog( lt_fieldcat ).

    ELSE."EDIT WHOLE ALV

      lo_grid->get_frontend_layout( IMPORTING es_layout = DATA(ls_layout) ).
      ls_layout-edit = im_editable.
      lo_grid->set_frontend_layout( is_layout = ls_layout ).

    ENDIF.

    IF im_refresh EQ abap_true.
      im_salv_table->refresh( ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* CLASS lcl_sel_screen IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_sel_screen IMPLEMENTATION.

  METHOD    get_instance.

    IF lo_instance IS NOT BOUND.
      lo_instance = NEW #( ).
    ENDIF.

    re_instance = lo_instance.

  ENDMETHOD.

  METHOD screen_initialization.

    me->t_color = VALUE #( ( color = 1  color_descr = 'Blue'       )
                           ( color = 2  color_descr = 'Light Grey' )
                           ( color = 3  color_descr = 'Yellow'     )
                           ( color = 4  color_descr = 'Light Blue' )
                           ( color = 5  color_descr = 'Green'      )
                           ( color = 6  color_descr = 'Red'        )
                           ( color = 7  color_descr = 'Orange'     ) ).

    t_title0   = TEXT-001.
    t_title5   = TEXT-002.
    t_title1   = TEXT-003.
    t_title2   = TEXT-004.
    t_title3   = TEXT-005.
    t_title4   = TEXT-006.

    t_col_s    = icon_draw_linear              && TEXT-007.
    t_col_e    = icon_draw_linear              && TEXT-008.
    t_lin_s    = icon_draw_linear              && TEXT-009.
    t_lin_e    = icon_draw_linear              && TEXT-010.
    t_db       = icon_database_table           && TEXT-011.
    t_file     = icon_xls                      && TEXT-012.
    t_excel    = icon_open_folder              && TEXT-013.
    t_sheet    = icon_xls                      && TEXT-014.
    t_hdesc    = TEXT-015.
    t_head     = TEXT-016.
    t_status   = icon_wd_toolbar_caption       && TEXT-017.
    t_layout   = icon_alv_variants             && TEXT-018.
    t_names    = icon_wd_input_field           && TEXT-019.
    t_hits     = TEXT-020.
    t_icon     = icon_status_open              && TEXT-021.
    t_popup    = icon_wd_window                && TEXT-022.
    t_check    = icon_checkbox                 && TEXT-023.
    t_hotsp    = icon_simple_field             && TEXT-024.
    t_doc      = icon_wd_view_set_t_layout_90  && TEXT-025.
    t_split    = icon_wd_view_set_t_layout_270 && TEXT-026.
    t_cont     = icon_context_menu             && TEXT-027.
    t_table    = icon_table_settings           && TEXT-028.
    t_stand    = icon_wd_view_container        && TEXT-029.
    t_dial     = icon_wd_window                && TEXT-030.
    t_r1       = icon_sap_gui_session          && TEXT-031.
    t_r2       = icon_wd_web_appl_project      && TEXT-032.
    t_colh     = icon_color                    && TEXT-033.
    t_coll     = icon_color                    && TEXT-034.
    t_event    = icon_wd_toolbar               && TEXT-035.

  ENDMETHOD.

  METHOD screen_pbo.

    "SCREEN-ACTIVE IS A ONE CHARACTER FLAG: '1' SHOWS THE ELEMENT, '0' HIDES IT
    CONSTANTS visible   TYPE c LENGTH 1 VALUE '1'.
    CONSTANTS invisible TYPE c LENGTH 1 VALUE '0'.

    "MODIFICATION GROUPS AND THE CHOICE THAT OWNS THEM:
    "  ID1 CONTAINER TYPE AND GRID EVENTS - SAP GUI VERSION ONLY
    "  ID2 POPUP FLAG AND GUI STATUS      - FIORI VERSION ONLY
    "  ID3 EXCEL FILE, SHEET, HEADER FLAG - FILE DATA SOURCE ONLY
    "  ID4 TABLE, LAYOUT, HOTSPOT, FILTER - DATABASE DATA SOURCE ONLY
    "  ID5 POPUP DIMENSIONS               - FIORI VERSION, AND ONLY FOR A POPUP
    "AN ELEMENT OUTSIDE THESE GROUPS IS LEFT UNTOUCHED
    LOOP AT SCREEN INTO DATA(ls_screen).

      CASE ls_screen-group1.

        WHEN 'ID1'.
          ls_screen-active = COND #( WHEN p_r1 EQ abap_true THEN visible ELSE invisible ).

        WHEN 'ID2'.
          ls_screen-active = COND #( WHEN p_r2 EQ abap_true THEN visible ELSE invisible ).

        WHEN 'ID3'.
          ls_screen-active = COND #( WHEN p_file EQ abap_true THEN visible ELSE invisible ).

        WHEN 'ID4'.
          ls_screen-active = COND #( WHEN p_db EQ abap_true THEN visible ELSE invisible ).

        WHEN 'ID5'.
          ls_screen-active = COND #( WHEN p_r2 EQ abap_true AND p_popup EQ abap_true THEN visible ELSE invisible ).

        WHEN OTHERS.
          CONTINUE.

      ENDCASE.

      IF ls_screen-name EQ 'T_HITS'.
        ls_screen-request    = '1'.
        ls_screen-display_3d = '1'.
      ENDIF.

      MODIFY SCREEN FROM ls_screen.

    ENDLOOP.

    IF p_table IS NOT INITIAL.

      SELECT SINGLE FROM dd02t
        FIELDS ddtext
        WHERE tabname EQ @p_table AND
              ddlanguage EQ @syst-langu
        INTO @t_descr.

      IF syst-subrc NE 0.
        CLEAR t_descr.
      ENDIF.

    ENDIF.

    IF p_hotsp IS NOT INITIAL AND p_table IS NOT INITIAL.

      DATA(lv_field_exists) = lcl_utilities=>check_field_exists_in_table( im_field = CONV #( p_hotsp ) im_table = p_table ).

      IF lv_field_exists EQ abap_true.

        DATA(lv_data_element) = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_name( |{ p_table CASE = UPPER }-{ p_hotsp CASE = UPPER }| ) )->get_ddic_field( )-rollname.

        SELECT SINGLE FROM dd04t
          FIELDS ddtext
          WHERE rollname   EQ @lv_data_element
            AND ddlanguage EQ @syst-langu
          INTO @t_descr2.

      ELSE.

        CLEAR t_descr2.

      ENDIF.

    ENDIF.

    IF p_coll IS NOT INITIAL.

      t_descl = COND #( WHEN line_exists( me->t_color[ color = p_coll ] )
                        THEN me->t_color[ color = p_coll ]-color_descr
                        ELSE space ).

    ENDIF.

    IF p_colh IS NOT INITIAL.

      t_desch = COND #( WHEN line_exists( me->t_color[ color = p_colh ] )
                        THEN me->t_color[ color = p_colh ]-color_descr
                        ELSE space ).

    ENDIF.

    IF p_layout IS NOT INITIAL.

      DATA(lt_layout) = cl_salv_layout_service=>get_layouts( s_key = VALUE salv_s_layout_key( report = syst-repid ) ).
      t_ldescr  = VALUE #( lt_layout[ layout = p_layout ]-text OPTIONAL ).

    ELSE.
      CLEAR t_ldescr.
    ENDIF.

  ENDMETHOD.

  METHOD color_f4.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield      = 'COLOR'
        dynpprog      = syst-repid
        dynpnr        = syst-dynnr
        dynprofield   = im_fieldname
        window_title  = 'Table Fields'
        value_org     = 'S'
      TABLES
        value_tab     = me->t_color
      EXCEPTIONS
        error_message = 1
        OTHERS        = 2.

  ENDMETHOD.

  METHOD fields_f4.

    TYPES: BEGIN OF ty_component,
             field    TYPE fieldname,
             rollname TYPE rollname,
           END OF ty_component.

    TYPES tt_component TYPE SORTED TABLE OF ty_component WITH UNIQUE KEY field.

    IF p_table IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_struct_def) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( p_table ) ).

    "COLLECT EVERY COMPONENT AND ITS DATA ELEMENT FIRST, SO THE TEXTS CAN BE
    "READ IN ONE SELECT INSTEAD OF ONE SELECT SINGLE PER COMPONENT
    DATA(lt_component) = VALUE tt_component( ).

    LOOP AT lo_struct_def->components ASSIGNING FIELD-SYMBOL(<fs_line>).

      DATA(lo_element_def) = CAST cl_abap_elemdescr( lo_struct_def->get_component_type( <fs_line>-name ) ).

      INSERT VALUE #( field    = <fs_line>-name
                      rollname = lo_element_def->get_ddic_field( )-rollname ) INTO TABLE lt_component.

    ENDLOOP.

    IF lt_component IS INITIAL.
      RETURN.
    ENDIF.

    "A COMPONENT BUILT AT RUNTIME HAS NO DATA ELEMENT, AND AN EMPTY ROLLNAME
    "IN THE DRIVER TABLE WOULD READ THE WHOLE OF DD04T
    DATA(lt_with_rollname) = lt_component.
    DELETE lt_with_rollname WHERE rollname IS INITIAL.

    IF lt_with_rollname IS NOT INITIAL.

      SELECT FROM dd04t
        FIELDS rollname, scrtext_l
        FOR ALL ENTRIES IN @lt_with_rollname
        WHERE rollname   EQ @lt_with_rollname-rollname
          AND ddlanguage EQ @syst-langu
        INTO TABLE @DATA(lt_text).

    ENDIF.

    DATA(lt_fields) = VALUE smt_wd_t_field_description( ).

    LOOP AT lt_component ASSIGNING FIELD-SYMBOL(<fs_component>).

      "OPTIONAL YIELDS AN EMPTY DESCRIPTION WHEN THERE IS NO TEXT, RATHER THAN
      "LEAVING THE PREVIOUS COMPONENT'S DESCRIPTION IN PLACE
      APPEND VALUE #( field       = <fs_component>-field
                      description = VALUE #( lt_text[ rollname = <fs_component>-rollname ]-scrtext_l OPTIONAL ) ) TO lt_fields.

    ENDLOOP.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield      = 'FIELD'
        dynpprog      = syst-repid
        dynpnr        = syst-dynnr
        dynprofield   = im_fieldname
        window_title  = 'Table Fields'(078)
        value_org     = 'S'
      TABLES
        value_tab     = lt_fields
      EXCEPTIONS
        error_message = 1
        OTHERS        = 2.

  ENDMETHOD.

  METHOD screen_pai.

    CASE im_user_command.
      WHEN 'BUT1'.

    ENDCASE.

  ENDMETHOD.

ENDCLASS.

*&----------------------------------------------------------------------*
*&CLASS LCX_EXCEPTION IMPLEMENTATION
*&----------------------------------------------------------------------*
CLASS lcx_exception IMPLEMENTATION.

  METHOD constructor.

    super->constructor( textid = CONV #( im_textid )
                        previous = CONV #( im_previous ) ) ##OPERATOR[REFERENCE].

    mv_message = COND #( WHEN im_text IS SUPPLIED AND im_text IS NOT INITIAL THEN im_text ).

  ENDMETHOD.

  METHOD get_text.

    result = super->get_text( ).

    IF me->mv_message IS NOT INITIAL.
      result = COND #( WHEN result IS INITIAL THEN  me->mv_message
                       WHEN result IS NOT INITIAL THEN |{ result }-{ me->mv_message } | ).
    ENDIF.

  ENDMETHOD.

  METHOD get_longtext.

    result = super->get_longtext( ).

    IF me->mv_message IS NOT INITIAL.
      result = COND #( WHEN result IS INITIAL THEN  me->mv_message
                       WHEN result IS NOT INITIAL THEN |{ result }-{ me->mv_message } | ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
