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
ENDCLASS.

CLASS lhc_item IMPLEMENTATION.
  METHOD setStatusDraft.
    DATA lt_doc_no TYPE lcl_status=>tt_doc_no.
    lt_doc_no = VALUE #( FOR ls_key IN keys ( ls_key-DocumentSequenceNo ) ).
    SORT lt_doc_no.
    DELETE ADJACENT DUPLICATES FROM lt_doc_no.
    lcl_status=>set_draft( lt_doc_no ).
  ENDMETHOD.
ENDCLASS.

