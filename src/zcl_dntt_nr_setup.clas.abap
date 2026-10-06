"! Tạo interval 01 cho number range ZNR_DNTT (Document SequenceNo).
"! Chạy 1 lần ở MỖI client (DEV 080, CUS 100, PRD): mở class trong ADT -> F9.
CLASS zcl_dntt_nr_setup DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS:
      c_object      TYPE c LENGTH 10 VALUE 'ZNR_DNTT',
      c_interval    TYPE c LENGTH 2  VALUE '01',
      " Đúng bằng độ dài domain của number range (ZD_DNTT_SEQNO - NUMC 10)
      c_from_number TYPE c LENGTH 10 VALUE '1000000000',
      c_to_number   TYPE c LENGTH 10 VALUE '1999999999'.
ENDCLASS.



CLASS zcl_dntt_nr_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA lt_interval TYPE cl_numberrange_intervals=>nr_interval.

    lt_interval = VALUE #( ( nrrangenr  = c_interval
                             fromnumber = c_from_number
                             tonumber   = c_to_number
                             procind    = 'I' ) ).
    TRY.
        cl_numberrange_intervals=>create( EXPORTING interval  = lt_interval
                                                    object    = c_object
                                                    subobject = ' '
                                          IMPORTING error     = DATA(lv_error)
                                                    error_inf = DATA(ls_error_inf)
                                                    error_iv  = DATA(lt_error_iv)
                                                    warning   = DATA(lv_warning) ).
        IF lv_error = abap_true.
          out->write( |Lỗi tạo interval { c_object }/{ c_interval }:| ).
          out->write( ls_error_inf ).
          out->write( lt_error_iv ).
        ELSE.
          out->write( |Đã tạo interval { c_object }/{ c_interval }: { c_from_number } - { c_to_number }| ).
          IF lv_warning = abap_true.
            out->write( `(có cảnh báo - interval có thể đã tồn tại)` ).
          ENDIF.
        ENDIF.
      CATCH cx_root INTO DATA(lx_error).
        out->write( |Lỗi: { lx_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.

