"! <p class="shorttext synchronized" lang="EN">Failure in an ABAP Projects utility</p>
"!
"! Raised for programming errors: a column that does not exist, a segment
"! size of zero, a value with no conversion exit to apply. A lock that could
"! not be taken is a routine outcome, not an error, and is reported in the
"! result structure of the locking methods instead.
CLASS zcx_abap_projects DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.

    CONSTANTS:
      BEGIN OF no_lock_object,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '010',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_lock_object.

    CONSTANTS:
      BEGIN OF foreign_lock,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '011',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE 'DETAIL',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF foreign_lock.

    CONSTANTS:
      BEGIN OF lock_failed,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '012',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF lock_failed.

    CONSTANTS:
      BEGIN OF unlock_failed,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '013',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF unlock_failed.

    CONSTANTS:
      BEGIN OF not_an_elementary_type,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '020',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF not_an_elementary_type.

    CONSTANTS:
      BEGIN OF unknown_direction,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '021',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF unknown_direction.

    CONSTANTS:
      BEGIN OF conversion_failed,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '022',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE 'DETAIL',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF conversion_failed.

    CONSTANTS:
      BEGIN OF unknown_column,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '030',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF unknown_column.

    CONSTANTS:
      BEGIN OF invalid_segment_size,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '031',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_segment_size.

    CONSTANTS:
      BEGIN OF unsupported_key_type,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '032',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF unsupported_key_type.

    CONSTANTS:
      BEGIN OF key_too_long,
        msgid TYPE symsgid      VALUE 'ZABAP_PROJECTS',
        msgno TYPE symsgno      VALUE '033',
        attr1 TYPE scx_attrname VALUE 'OBJECT_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF key_too_long.

    "! What the failure was about: a column, a type or a function module.
    DATA object_name TYPE string READ-ONLY.
    "! Technical reason, for the long text and the log.
    DATA detail      TYPE string READ-ONLY.

    "! @parameter textid      | One of the message constants of this class.
    "! @parameter previous    | Exception being wrapped, if any.
    "! @parameter object_name | Column, type or function module involved.
    "! @parameter detail      | Technical reason.
    METHODS constructor
      IMPORTING textid      LIKE if_t100_message=>t100key OPTIONAL
                previous    LIKE previous                 OPTIONAL
                object_name TYPE string                   OPTIONAL
                detail      TYPE string                   OPTIONAL.

ENDCLASS.


CLASS zcx_abap_projects IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( previous = previous ).

    me->object_name = object_name.
    me->detail      = detail.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
