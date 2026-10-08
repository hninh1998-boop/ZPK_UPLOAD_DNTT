CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-DATA mt_head TYPE zcl_dntt_excel_upload=>tt_head.
    CLASS-DATA mt_item TYPE zcl_dntt_excel_upload=>tt_item.
    CLASS-DATA mt_delete TYPE STANDARD TABLE OF ztb_up_dntt_head-document_sequence_no WITH EMPTY KEY.

    TYPES: BEGIN OF ty_status_update,
             document_sequence_no TYPE ztb_up_dntt_head-document_sequence_no,
             status               TYPE ztb_up_dntt_head-status,
             document_number      TYPE ztb_up_dntt_head-document_number,
             message              TYPE ztb_up_dntt_head-message,
           END OF ty_status_update.
    CLASS-DATA mt_status TYPE STANDARD TABLE OF ty_status_update WITH EMPTY KEY.
ENDCLASS.

CLASS lhc_dnttlist DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DnttList RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ DnttList RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK DnttList.

    METHODS downloadTemplate FOR MODIFY
      IMPORTING keys FOR ACTION DnttList~downloadTemplate RESULT result.

    METHODS uploadFile FOR MODIFY
      IMPORTING keys FOR ACTION DnttList~uploadFile RESULT result.

    METHODS deleteDocument FOR MODIFY
      IMPORTING keys FOR ACTION DnttList~deleteDocument.

    METHODS checkDocuments FOR MODIFY
      IMPORTING keys FOR ACTION DnttList~checkDocuments RESULT result.

    METHODS postDocuments FOR MODIFY
      IMPORTING keys FOR ACTION DnttList~postDocuments RESULT result.

    TYPES:
      BEGIN OF ty_summary,
        success_count TYPE i,
        error_count   TYPE i,
        details       TYPE string,
      END OF ty_summary.

    "! Check (test run) / Post qua API Journal Entry cho danh sách chứng từ "A1,A2,..."
    "! - Chỉ xử lý chứng từ có status = iv_required_status (hoặc iv_alt_status nếu có), không đang Edit (draft)
    "! - Thành công -> iv_success_status (+ số chứng từ khi Post), lỗi API -> Error + message
    "! - Lỗi kết nối -> giữ nguyên status
    METHODS process_documents
      IMPORTING iv_document_list   TYPE string
                iv_test_run        TYPE abap_bool
                iv_required_status TYPE ztb_up_dntt_head-status
                iv_alt_status      TYPE ztb_up_dntt_head-status OPTIONAL
                iv_success_status  TYPE ztb_up_dntt_head-status
                iv_action_text     TYPE string
                iv_actvt           TYPE csequence
      RETURNING VALUE(rs_summary)  TYPE ty_summary.
ENDCLASS.

CLASS lhc_dnttlist IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-downloadTemplate = if_abap_behv=>mk-on.
      result-%action-downloadTemplate = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-uploadFile = if_abap_behv=>mk-on.
      result-%action-uploadFile = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-deleteDocument = if_abap_behv=>mk-on.
      result-%action-deleteDocument = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-checkDocuments = if_abap_behv=>mk-on.
      result-%action-checkDocuments = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-postDocuments = if_abap_behv=>mk-on.
      result-%action-postDocuments = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD read.
    " Custom entity - dữ liệu đọc qua query ZCL_CE_UP_DNTT
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD downloadTemplate.
    TRY.
        DATA(lv_xlsx)   = NEW zcl_dntt_excel_template( )->build( ).
        DATA(lv_base64) = cl_web_http_utility=>encode_x_base64( lv_xlsx ).
      CATCH cx_root INTO DATA(lx_error).
        LOOP AT keys INTO DATA(ls_key).
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-dnttlist.
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = lx_error->get_text( ) ) )
                 TO reported-dnttlist.
        ENDLOOP.
        RETURN.
    ENDTRY.

    result = VALUE #( FOR ls_k IN keys
                      ( %cid   = ls_k-%cid
                        %param = VALUE #( filename    = zcl_dntt_excel_template=>c_file_name
                                          mimetype    = zcl_dntt_excel_template=>c_mime_type
                                          filecontent = lv_base64 ) ) ).
  ENDMETHOD.

  METHOD uploadFile.
    DATA: lt_messages TYPE zcl_dntt_excel_upload=>tt_message,
          lt_warnings TYPE zcl_dntt_excel_upload=>tt_message.

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_messages, lt_warnings.

      IF ls_key-%param-filecontent IS INITIAL.
        APPEND `Chưa chọn file upload` TO lt_messages.
      ELSE.
        TRY.
            DATA(lv_file) = cl_web_http_utility=>decode_x_base64( ls_key-%param-filecontent ).
          CATCH cx_root.
            APPEND `File upload không hợp lệ` TO lt_messages.
        ENDTRY.
      ENDIF.

      IF lt_messages IS INITIAL.
        NEW zcl_dntt_excel_upload( )->parse( EXPORTING iv_file     = lv_file
                                             IMPORTING et_head     = DATA(lt_head)
                                                       et_item     = DATA(lt_item)
                                                       et_messages = lt_messages
                                                       et_warnings = lt_warnings ).
      ENDIF.

      " Lỗi chặn cả file: không lưu gì, trả danh sách lỗi đầy đủ trong result
      " (không dùng failed / reported vì text message RAP bị cắt ở 50 ký tự)
      IF lt_messages IS NOT INITIAL.
        APPEND VALUE #( %cid   = ls_key-%cid
                        %param = VALUE #( errors = concat_lines_of( table = lt_messages
                                                                    sep   = cl_abap_char_utilities=>newline ) ) )
               TO result.
        CONTINUE.
      ENDIF.

      " Cùng chứng từ upload nhiều lần trong 1 request -> lấy lần sau cùng
      LOOP AT lt_head INTO DATA(ls_head).
        DELETE lcl_buffer=>mt_head WHERE document_sequence_no = ls_head-document_sequence_no.
        DELETE lcl_buffer=>mt_item WHERE document_sequence_no = ls_head-document_sequence_no.
      ENDLOOP.
      APPEND LINES OF lt_head TO lcl_buffer=>mt_head.
      APPEND LINES OF lt_item TO lcl_buffer=>mt_item.

      APPEND VALUE #( %cid   = ls_key-%cid
                      %param = VALUE #( documentcount = lines( lt_head )
                                        itemcount     = lines( lt_item )
                                        errorcount    = REDUCE #( INIT n = 0
                                                                  FOR ls_h IN lt_head
                                                                  WHERE ( status = zcl_dntt_excel_upload=>c_status-error )
                                                                  NEXT n = n + 1 )
                                        warnings      = concat_lines_of( table = lt_warnings
                                                                         sep   = cl_abap_char_utilities=>newline ) ) )
             TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD deleteDocument.
    DATA lr_doc TYPE RANGE OF ztb_up_dntt_head-document_sequence_no.

    lr_doc = VALUE #( FOR ls_k IN keys ( sign = 'I' option = 'EQ' low = ls_k-DocumentSequenceNo ) ).
    IF lr_doc IS INITIAL.
      RETURN.
    ENDIF.

    SELECT document_sequence_no, status, company_code, je_type
      FROM ztb_up_dntt_head
      WHERE document_sequence_no IN @lr_doc
      INTO TABLE @DATA(lt_head).

    " Chứng từ đang được Edit ở màn hình chi tiết (có bản draft của BO DnttHead)
    READ ENTITIES OF zi_up_dntt_head
      ENTITY Head
        FIELDS ( DocumentSequenceNo )
        WITH VALUE #( FOR ls_k IN keys ( %is_draft          = if_abap_behv=>mk-on
                                         DocumentSequenceNo = ls_k-DocumentSequenceNo ) )
      RESULT DATA(lt_draft).

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_error) = ``.

      READ TABLE lt_head INTO DATA(ls_head) WITH KEY document_sequence_no = ls_key-DocumentSequenceNo.
      IF sy-subrc <> 0.
        lv_error = |Chứng từ { ls_key-DocumentSequenceNo } không tồn tại|.
      ELSEIF to_upper( ls_head-status ) = to_upper( zcl_dntt_excel_upload=>c_status-posted ).
        lv_error = |Chứng từ { ls_key-DocumentSequenceNo } đã Posted, không được xóa|.
      " Xóa không cần quyền riêng (06): user thấy được chứng từ trên danh sách thì xóa được, giống màn hình
      " chi tiết. Vẫn check quyền hiển thị (03, cùng điều kiện với DCL ZI_UP_DNTT_HEAD) vì ở đây đọc
      " thẳng bảng -> chặn gọi action trực tiếp với chứng từ không được xem
      ELSEIF zcl_dntt_auth=>is_authorized( iv_company_code = ls_head-company_code
                                           iv_je_type      = ls_head-je_type
                                           iv_actvt        = zcl_dntt_auth=>c_actvt-display ) = abap_false.
        " Message RAP bị cắt ở 50 ký tự -> câu ngắn
        lv_error = |{ ls_key-DocumentSequenceNo }: không có quyền xóa ({ ls_head-company_code }/{ ls_head-je_type })|.
      ELSEIF line_exists( lt_draft[ DocumentSequenceNo = ls_key-DocumentSequenceNo ] ).
        lv_error = |{ ls_key-DocumentSequenceNo } đang được chỉnh sửa, không xóa được|.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-dnttlist.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_error ) ) TO reported-dnttlist.
        CONTINUE.
      ENDIF.

      APPEND ls_key-DocumentSequenceNo TO lcl_buffer=>mt_delete.
    ENDLOOP.
  ENDMETHOD.

  METHOD checkDocuments.
    " Check = test run (TestDataIndicator = true): Draft / Error -> Checked / Error
    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_summary) = process_documents( iv_document_list   = ls_key-%param-DocumentList
                                            iv_test_run        = abap_true
                                            iv_required_status = zcl_dntt_excel_upload=>c_status-draft
                                            " Error -> cho check lại
                                            iv_alt_status      = zcl_dntt_excel_upload=>c_status-error
                                            iv_success_status  = zcl_dntt_excel_upload=>c_status-checked
                                            iv_action_text     = `check`
                                            " Check = mô phỏng hạch toán -> cần quyền hiển thị
                                            iv_actvt           = zcl_dntt_auth=>c_actvt-display ).
      APPEND VALUE #( %cid   = ls_key-%cid
                      %param = VALUE #( successcount = ls_summary-success_count
                                        errorcount   = ls_summary-error_count
                                        details      = ls_summary-details ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD postDocuments.
    " Post thật (TestDataIndicator = false): Checked -> Posted (+ Document number) / Error
    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_summary) = process_documents( iv_document_list   = ls_key-%param-DocumentList
                                            iv_test_run        = abap_false
                                            iv_required_status = zcl_dntt_excel_upload=>c_status-checked
                                            iv_success_status  = zcl_dntt_excel_upload=>c_status-posted
                                            iv_action_text     = `post`
                                            " Post = tạo chứng từ kế toán (API chạy bằng user kỹ thuật -> phải check ở đây)
                                            iv_actvt           = zcl_dntt_auth=>c_actvt-create ).
      APPEND VALUE #( %cid   = ls_key-%cid
                      %param = VALUE #( successcount = ls_summary-success_count
                                        errorcount   = ls_summary-error_count
                                        details      = ls_summary-details ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD process_documents.
    DATA: lr_doc     TYPE RANGE OF ztb_up_dntt_head-document_sequence_no,
          lt_doc     TYPE zcl_dntt_je_api=>tt_doc_no,
          lt_doc_no  TYPE zcl_dntt_je_api=>tt_doc_no,
          lt_details TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    " Danh sách Document SequenceNo: "A1,A2,A3"
    SPLIT iv_document_list AT `,` INTO TABLE DATA(lt_raw).
    LOOP AT lt_raw INTO DATA(lv_raw).
      DATA(lv_doc) = CONV ztb_up_dntt_head-document_sequence_no( condense( lv_raw ) ).
      IF lv_doc IS NOT INITIAL AND NOT line_exists( lt_doc[ table_line = lv_doc ] ).
        APPEND lv_doc TO lt_doc.
      ENDIF.
    ENDLOOP.

    lr_doc = VALUE #( FOR lv_d IN lt_doc ( sign = 'I' option = 'EQ' low = lv_d ) ).
    IF lr_doc IS INITIAL.
      RETURN.
    ENDIF.

    SELECT document_sequence_no, status, company_code, je_type
      FROM ztb_up_dntt_head
      WHERE document_sequence_no IN @lr_doc
      INTO TABLE @DATA(lt_head).

    " Chứng từ đang được Edit ở màn hình chi tiết -> kết quả sẽ bị bản draft ghi đè
    READ ENTITIES OF zi_up_dntt_head
      ENTITY Head
        FIELDS ( DocumentSequenceNo )
        WITH VALUE #( FOR lv_d IN lt_doc ( %is_draft          = if_abap_behv=>mk-on
                                           DocumentSequenceNo = lv_d ) )
      RESULT DATA(lt_draft).

    " 1. Kiểm tra status
    LOOP AT lt_doc INTO lv_doc.
      READ TABLE lt_head INTO DATA(ls_head) WITH KEY document_sequence_no = lv_doc.
      IF sy-subrc <> 0.
        APPEND |{ lv_doc }: không tồn tại| TO lt_details.
      ELSEIF to_upper( ls_head-status ) <> to_upper( iv_required_status )
         AND ( iv_alt_status IS INITIAL OR to_upper( ls_head-status ) <> to_upper( iv_alt_status ) ).
        DATA(lv_allowed) = COND string( WHEN iv_alt_status IS INITIAL THEN iv_required_status
                                        ELSE |{ iv_required_status } / { iv_alt_status }| ).
        APPEND |{ lv_doc }: đang ở trạng thái { ls_head-status }, chỉ { iv_action_text } được chứng từ { lv_allowed }|
               TO lt_details.
      ELSEIF line_exists( lt_draft[ DocumentSequenceNo = lv_doc ] ).
        APPEND |{ lv_doc }: đang được chỉnh sửa (draft), không { iv_action_text } được| TO lt_details.
      ELSEIF zcl_dntt_auth=>is_authorized( iv_company_code = ls_head-company_code
                                           iv_je_type      = ls_head-je_type
                                           iv_actvt        = iv_actvt ) = abap_false.
        DATA(lv_auth_text) = zcl_dntt_auth=>get_message( iv_company_code = ls_head-company_code
                                                         iv_je_type      = ls_head-je_type
                                                         iv_action       = iv_action_text ).
        APPEND |{ lv_doc }: { lv_auth_text }| TO lt_details.
      ELSE.
        APPEND lv_doc TO lt_doc_no.
        CONTINUE.
      ENDIF.
      rs_summary-error_count += 1.
    ENDLOOP.

    " 2. Gọi API - 1 request SOAP / 10 chứng từ
    IF lt_doc_no IS NOT INITIAL.
      DATA(lt_api_result) = NEW zcl_dntt_je_api( )->execute( it_doc_no = lt_doc_no iv_test_run = iv_test_run ).

      LOOP AT lt_api_result INTO DATA(ls_api).
        " Lỗi kết nối -> giữ nguyên status
        IF ls_api-technical_error = abap_true.
          APPEND |{ ls_api-document_sequence_no }: { ls_api-message }| TO lt_details.
          rs_summary-error_count += 1.
          CONTINUE.
        ENDIF.

        " Post thành công nhưng không có số chứng từ -> coi là lỗi
        IF ls_api-success = abap_true AND iv_test_run = abap_false AND ls_api-accounting_document IS INITIAL.
          ls_api-success = abap_false.
          ls_api-message = `API không trả về số chứng từ kế toán`.
        ENDIF.

        " 3. Thành công -> iv_success_status, lỗi -> Error + message
        DATA(ls_update) = VALUE lcl_buffer=>ty_status_update(
                            document_sequence_no = ls_api-document_sequence_no
                            status               = COND #( WHEN ls_api-success = abap_true
                                                           THEN iv_success_status
                                                           ELSE zcl_dntt_excel_upload=>c_status-error )
                            document_number      = ls_api-accounting_document
                            message              = ls_api-message ).
        DELETE lcl_buffer=>mt_status WHERE document_sequence_no = ls_update-document_sequence_no.
        APPEND ls_update TO lcl_buffer=>mt_status.

        IF ls_api-success = abap_true.
          rs_summary-success_count += 1.
          IF ls_api-accounting_document IS NOT INITIAL.
            APPEND |{ ls_api-document_sequence_no }: { iv_success_status } - { ls_api-accounting_document }| TO lt_details.
          ENDIF.
        ELSE.
          rs_summary-error_count += 1.
          APPEND |{ ls_api-document_sequence_no }: Error - { ls_api-message }| TO lt_details.
        ENDIF.
      ENDLOOP.
    ENDIF.

    rs_summary-details = concat_lines_of( table = lt_details sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zce_up_dntt DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.
ENDCLASS.

CLASS lsc_zce_up_dntt IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    DATA lr_doc TYPE RANGE OF ztb_up_dntt_head-document_sequence_no.

    IF lcl_buffer=>mt_head IS NOT INITIAL.
      " Upload: cấp Document SequenceNo thật thay cho số tạm ($1, $2...).
      " Number range chỉ được gọi ở save phase (gọi trong action -> BEHAVIOR_ILLEGAL_STATEMENT)
      LOOP AT lcl_buffer=>mt_head ASSIGNING FIELD-SYMBOL(<ls_new_head>).
        DATA(lv_temp_no) = <ls_new_head>-document_sequence_no.
        TRY.
            <ls_new_head>-document_sequence_no = zcl_dntt_excel_upload=>next_document_number( ).
          CATCH cx_number_ranges INTO DATA(lx_number_range).
            " Không báo lỗi được ở save phase -> number range ZNR_DNTT / 01 phải được tạo trước
            RAISE SHORTDUMP lx_number_range.
        ENDTRY.

        LOOP AT lcl_buffer=>mt_item ASSIGNING FIELD-SYMBOL(<ls_new_item>)
             WHERE document_sequence_no = lv_temp_no.
          <ls_new_item>-document_sequence_no = <ls_new_head>-document_sequence_no.
        ENDLOOP.
      ENDLOOP.

      INSERT ztb_up_dntt_head FROM TABLE @lcl_buffer=>mt_head.
    ENDIF.
    IF lcl_buffer=>mt_item IS NOT INITIAL.
      INSERT ztb_up_dntt_item FROM TABLE @lcl_buffer=>mt_item.
    ENDIF.

    " Cập nhật status sau Check / Post
    IF lcl_buffer=>mt_status IS NOT INITIAL.
      DATA lv_timestamp TYPE timestampl.
      GET TIME STAMP FIELD lv_timestamp.
      DATA(lv_user) = ``.
      TRY.
          lv_user = cl_abap_context_info=>get_user_technical_name( ).
        CATCH cx_abap_context_info_error.
          CLEAR lv_user.
      ENDTRY.

      LOOP AT lcl_buffer=>mt_status INTO DATA(ls_status).
        UPDATE ztb_up_dntt_head
          SET status                = @ls_status-status,
              message               = @ls_status-message,
              document_number       = @ls_status-document_number,
              last_changed_by       = @lv_user,
              last_changed_at       = @lv_timestamp,
              local_last_changed_at = @lv_timestamp
          WHERE document_sequence_no = @ls_status-document_sequence_no.
      ENDLOOP.
    ENDIF.

    " Xóa chứng từ (button Delete)
    IF lcl_buffer=>mt_delete IS NOT INITIAL.
      lr_doc = VALUE #( FOR lv_doc IN lcl_buffer=>mt_delete ( sign = 'I' option = 'EQ' low = lv_doc ) ).
      DELETE FROM ztb_up_dntt_item WHERE document_sequence_no IN @lr_doc.
      DELETE FROM ztb_up_dntt_head WHERE document_sequence_no IN @lr_doc.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup.
    CLEAR: lcl_buffer=>mt_head, lcl_buffer=>mt_item, lcl_buffer=>mt_delete, lcl_buffer=>mt_status.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR: lcl_buffer=>mt_head, lcl_buffer=>mt_item, lcl_buffer=>mt_delete, lcl_buffer=>mt_status.
  ENDMETHOD.

ENDCLASS.

