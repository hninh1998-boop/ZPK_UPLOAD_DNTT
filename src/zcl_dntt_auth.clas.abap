"! Phân quyền Upload DNTT theo Company Code (F_BKPF_BUK) và JE Type (F_BKPF_BLA - BRGRU)
"! Giống DCL của báo cáo đề nghị thanh toán: JE Type được dùng trực tiếp làm Authorization Group
CLASS zcl_dntt_auth DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_actvt,
        create  TYPE c LENGTH 2 VALUE '01',
        change  TYPE c LENGTH 2 VALUE '02',
        display TYPE c LENGTH 2 VALUE '03',
        delete  TYPE c LENGTH 2 VALUE '06',
      END OF c_actvt.

    "! abap_true nếu user có quyền với cả Company Code và JE Type
    CLASS-METHODS is_authorized
      IMPORTING iv_company_code      TYPE csequence
                iv_je_type           TYPE csequence
                iv_actvt             TYPE csequence
      RETURNING VALUE(rv_authorized) TYPE abap_bool.

    "! Text lỗi khi không có quyền
    CLASS-METHODS get_message
      IMPORTING iv_company_code TYPE csequence
                iv_je_type      TYPE csequence
                iv_action       TYPE csequence
      RETURNING VALUE(rv_text)  TYPE string.
ENDCLASS.



CLASS zcl_dntt_auth IMPLEMENTATION.

  METHOD is_authorized.
    DATA: lv_bukrs TYPE c LENGTH 4,
          lv_brgru TYPE c LENGTH 4,
          lv_actvt TYPE c LENGTH 2.

    lv_bukrs = iv_company_code.
    lv_brgru = iv_je_type.
    lv_actvt = iv_actvt.

    AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
      ID 'BUKRS' FIELD lv_bukrs
      ID 'ACTVT' FIELD lv_actvt.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'F_BKPF_BLA'
      ID 'BRGRU' FIELD lv_brgru
      ID 'ACTVT' FIELD lv_actvt.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv_authorized = abap_true.
  ENDMETHOD.


  METHOD get_message.
    rv_text = |Không có quyền { iv_action } cho Company code { iv_company_code } / JE Type { iv_je_type }|.
  ENDMETHOD.

ENDCLASS.

