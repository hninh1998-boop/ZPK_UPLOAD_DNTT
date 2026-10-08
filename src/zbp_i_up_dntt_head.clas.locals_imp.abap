"! Đưa chứng từ Checked / Error về Draft khi có chỉnh sửa (Posted / Draft giữ nguyên)
CLASS lcl_status DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_doc_no TYPE STANDARD TABLE OF ztb_up_dntt_head-document_sequence_no WITH EMPTY KEY.
    CLASS-METHODS set_draft
      IMPORTING it_doc_no TYPE tt_doc_no.
ENDCLASS.

CLASS lcl_status IMPLEMENTATION.
  METHOD set_draft.
    CHECK it_doc_no IS NOT INITIAL.

    READ ENTITIES OF zi_up_dntt_head IN LOCAL MODE
      ENTITY Head
        FIELDS ( Status ) WITH VALUE #( FOR lv_doc IN it_doc_no
                                        ( %is_draft          = if_abap_behv=>mk-off
                                          DocumentSequenceNo = lv_doc ) )
      RESULT DATA(lt_head).

    DELETE lt_head WHERE NOT ( Status = zcl_dntt_excel_upload=>c_status-checked
                            OR Status = zcl_dntt_excel_upload=>c_status-error ).
    CHECK lt_head IS NOT INITIAL.

    MODIFY ENTITIES OF zi_up_dntt_head IN LOCAL MODE
      ENTITY Head
        UPDATE FIELDS ( Status Message )
        WITH VALUE #( FOR ls_head IN lt_head
                      ( %tky    = ls_head-%tky
                        Status  = zcl_dntt_excel_upload=>c_status-draft
                        Message = `` ) ).
  ENDMETHOD.
ENDCLASS.

"! Kiểm tra field bắt buộc khi lưu: field ( mandatory ) trong BDEF chỉ hiện dấu * trên UI, không tự chặn
CLASS lcl_mandatory DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_field,
        name  TYPE string,  " Tên element CDS viết hoa
        label TYPE string,
      END OF ty_field,
      tt_field TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.

    "! Các field trong it_fields đang để trống ở is_data
    CLASS-METHODS get_empty_fields
      IMPORTING is_data          TYPE any
                it_fields        TYPE tt_field
      RETURNING VALUE(rt_fields) TYPE tt_field.

    CLASS-METHODS get_text
      IMPORTING iv_label       TYPE string
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS lcl_mandatory IMPLEMENTATION.
  METHOD get_empty_fields.
    LOOP AT it_fields INTO DATA(ls_field).
      ASSIGN COMPONENT ls_field-name OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_value>).
      IF sy-subrc = 0 AND <lv_value> IS INITIAL.
        APPEND ls_field TO rt_fields.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_text.
    " Message RAP bị cắt ở 50 ký tự -> câu ngắn
    rv_text = |{ iv_label } không được để trống|.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_head DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Head RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Head RESULT result.

    METHODS earlynumbering_cba_Item FOR NUMBERING
      IMPORTING entities FOR CREATE Head\_Item.

    METHODS setStatusDraft FOR DETERMINE ON SAVE
      IMPORTING keys FOR Head~setStatusDraft.

    METHODS validateMandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR Head~validateMandatory.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Head~validateDates.
ENDCLASS.

CLASS lhc_head IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_up_dntt_head IN LOCAL MODE
      ENTITY Head
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      FAILED failed.

    " Posted -> không cho xóa, không cho sửa (Edit). Draft / Checked / Error -> cho phép
    LOOP AT lt_head INTO DATA(ls_head).
      APPEND VALUE #( %tky = ls_head-%tky ) TO result ASSIGNING FIELD-SYMBOL(<ls_result>).
      <ls_result>-%delete      = COND #( WHEN to_upper( ls_head-Status ) = to_upper( zcl_dntt_excel_upload=>c_status-posted )
                                         THEN if_abap_behv=>fc-o-disabled
                                         ELSE if_abap_behv=>fc-o-enabled ).
      <ls_result>-%action-Edit = <ls_result>-%delete.
    ENDLOOP.
  ENDMETHOD.

  METHOD setStatusDraft.
    lcl_status=>set_draft( VALUE #( FOR ls_key IN keys ( ls_key-DocumentSequenceNo ) ) ).
  ENDMETHOD.

  METHOD validateMandatory.
    READ ENTITIES OF zi_up_dntt_head IN LOCAL MODE
      ENTITY Head
        FIELDS ( CompanyCode PostingDate Currency Supplier PaymentMethod ProfitCenter DueOn )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    " Đúng danh sách field ( mandatory ) của Head trong BDEF
    DATA(lt_fields) = VALUE lcl_mandatory=>tt_field( ( name = 'COMPANYCODE'   label = `Company code` )
                                                     ( name = 'PAYMENTMETHOD' label = `Payment Method` )
                                                     ( name = 'POSTINGDATE'   label = `Posting date` )
                                                     ( name = 'DUEON'         label = `Due On` )
                                                     ( name = 'CURRENCY'      label = `Currency` )
                                                     ( name = 'SUPPLIER'      label = `Supplier` )
                                                     ( name = 'PROFITCENTER'  label = `Profit Center` ) ).

    " Message không dùng %state_area: state message không về được màn hình (chỉ ra câu chung
    " "Resolve data inconsistencies") -> trả message thường, đi kèm response của lần Save bị chặn
    LOOP AT lt_head INTO DATA(ls_head).
      LOOP AT lcl_mandatory=>get_empty_fields( is_data = ls_head it_fields = lt_fields ) INTO DATA(ls_field).
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-head.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lcl_mandatory=>get_text( ls_field-label ) ) )
               TO reported-head ASSIGNING FIELD-SYMBOL(<ls_reported>).
        " Đánh dấu field lỗi trên màn hình
        ASSIGN COMPONENT ls_field-name OF STRUCTURE <ls_reported>-%element TO FIELD-SYMBOL(<lv_flag>).
        IF sy-subrc = 0.
          <lv_flag> = if_abap_behv=>mk-on.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    READ ENTITIES OF zi_up_dntt_head IN LOCAL MODE
      ENTITY Head
        FIELDS ( PostingDate DueOn )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    DATA(lt_fields) = VALUE lcl_mandatory=>tt_field( ( name = 'POSTINGDATE' label = `Posting date` )
                                                     ( name = 'DUEON'       label = `Due On` ) ).

    LOOP AT lt_head INTO DATA(ls_head).
      LOOP AT lt_fields INTO DATA(ls_field).
        ASSIGN COMPONENT ls_field-name OF STRUCTURE ls_head TO FIELD-SYMBOL(<lv_value>).
        " Để trống -> validateMandatory báo. Cùng quy tắc với lúc upload: dd/mm/yyyy và ngày phải tồn tại
        IF sy-subrc <> 0 OR <lv_value> IS INITIAL
           OR zcl_dntt_excel_upload=>to_date( condense( CONV string( <lv_value> ) ) ) IS NOT INITIAL.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-head.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |{ ls_field-label } phải là ngày dd/mm/yyyy| ) )
               TO reported-head ASSIGNING FIELD-SYMBOL(<ls_reported>).
        ASSIGN COMPONENT ls_field-name OF STRUCTURE <ls_reported>-%element TO FIELD-SYMBOL(<lv_flag>).
        IF sy-subrc = 0.
          <lv_flag> = if_abap_behv=>mk-on.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_cba_Item.
    DATA lv_max TYPE n LENGTH 5.

    READ ENTITIES OF zi_up_dntt_head IN LOCAL MODE
      ENTITY Head BY \_Item
        FIELDS ( Item ) WITH CORRESPONDING #( entities )
      RESULT DATA(lt_item).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
      CLEAR lv_max.

      LOOP AT lt_item INTO DATA(ls_item)
           WHERE DocumentSequenceNo = <ls_entity>-DocumentSequenceNo
             AND %is_draft          = <ls_entity>-%is_draft.
        IF ls_item-Item > lv_max.
          lv_max = ls_item-Item.
        ENDIF.
      ENDLOOP.

      LOOP AT <ls_entity>-%target INTO DATA(ls_target) WHERE Item IS NOT INITIAL.
        IF ls_target-Item > lv_max.
          lv_max = ls_target-Item.
        ENDIF.
      ENDLOOP.

      LOOP AT <ls_entity>-%target INTO ls_target.
        IF ls_target-Item IS INITIAL.
          lv_max += 1.
          ls_target-Item = lv_max.
        ENDIF.

        APPEND VALUE #( %cid               = ls_target-%cid
                        %is_draft          = ls_target-%is_draft
                        DocumentSequenceNo = <ls_entity>-DocumentSequenceNo
                        Item               = ls_target-Item ) TO mapped-item.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setStatusDraft FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~setStatusDraft.

    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItem.
ENDCLASS.

CLASS lhc_item IMPLEMENTATION.
  METHOD setStatusDraft.
    DATA lt_doc_no TYPE lcl_status=>tt_doc_no.
    lt_doc_no = VALUE #( FOR ls_key IN keys ( ls_key-DocumentSequenceNo ) ).
    SORT lt_doc_no.
    DELETE ADJACENT DUPLICATES FROM lt_doc_no.
    lcl_status=>set_draft( lt_doc_no ).
  ENDMETHOD.

  METHOD validateItem.
    READ ENTITIES OF zi_up_dntt_head IN LOCAL MODE
      ENTITY Item
        FIELDS ( TrgSpecGlInd Amount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    " Đúng danh sách field ( mandatory ) của Item trong BDEF
    DATA(lt_fields) = VALUE lcl_mandatory=>tt_field( ( name = 'TRGSPECGLIND' label = `Trg. Spec. G/L Ind` )
                                                     ( name = 'AMOUNT'       label = `Amount` ) ).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(lv_prefix) = |Item { CONV i( ls_item-Item ) }: |.

      LOOP AT lcl_mandatory=>get_empty_fields( is_data = ls_item it_fields = lt_fields ) INTO DATA(ls_field).
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lcl_mandatory=>get_text( lv_prefix && ls_field-label ) ) )
               TO reported-item.
      ENDLOOP.

      " Amount lưu dạng text -> phải tự kiểm tra là số (cùng quy tắc với lúc upload)
      IF ls_item-Amount IS NOT INITIAL
         AND zcl_dntt_excel_upload=>is_valid_amount( condense( CONV string( ls_item-Amount ) ) ) = abap_false.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky            = ls_item-%tky
                        %element-Amount = if_abap_behv=>mk-on
                        %msg            = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                                 text     = |{ lv_prefix }Amount phải là số| ) )
               TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

