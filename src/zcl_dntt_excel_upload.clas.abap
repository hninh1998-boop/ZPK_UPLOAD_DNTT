CLASS zcl_dntt_excel_upload DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      tt_head    TYPE STANDARD TABLE OF ztb_up_dntt_head WITH EMPTY KEY,
      tt_item    TYPE STANDARD TABLE OF ztb_up_dntt_item WITH EMPTY KEY,
      tt_message TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF c_status,
        draft   TYPE ztb_up_dntt_head-status VALUE 'Draft',
        checked TYPE ztb_up_dntt_head-status VALUE 'Checked',
        error   TYPE ztb_up_dntt_head-status VALUE 'Error',
        posted  TYPE ztb_up_dntt_head-status VALUE 'Posted',
      END OF c_status.

    "! Đọc file Excel theo template ZCL_DNTT_EXCEL_TEMPLATE và kiểm tra dữ liệu.
    "! - Lỗi dữ liệu của chứng từ -> vẫn lưu, status = Error, lỗi ghi vào message của header
    "! - Document SequenceNo đã có -> cập nhật header, thay toàn bộ item
    "! - Lỗi không lưu được (sai file/template, thiếu Document SequenceNo, chứng từ đã Posted)
    "!   -> et_messages, et_head / et_item rỗng
    "! Cột A (Document SequenceNo) trong file chỉ là MÃ NHÓM để gom các dòng của 1 chứng từ.
    "! et_head / et_item mang số TẠM ($1, $2...) - số thật cấp từ number range ZNR_DNTT
    "! lúc lưu (saver của ZBP_CE_UP_DNTT gọi next_document_number) -> luôn tạo mới.
    "! et_warnings: cảnh báo (hiện không dùng, giữ cho tương thích)
    METHODS parse
      IMPORTING iv_file     TYPE xstring
      EXPORTING et_head     TYPE tt_head
                et_item     TYPE tt_item
                et_messages TYPE tt_message
                et_warnings TYPE tt_message.

    "! Document SequenceNo tiếp theo từ number range ZNR_DNTT / 01.
    "! Chỉ gọi ở save phase (RAP cấm ghi DB - kể cả lấy số - ở interaction phase)
    CLASS-METHODS next_document_number
      RETURNING VALUE(rv_doc_no) TYPE ztb_up_dntt_head-document_sequence_no
      RAISING   cx_number_ranges.

    "! Ngày dạng dd/mm/yyyy -> d. Sai định dạng hoặc ngày không tồn tại -> initial
    CLASS-METHODS to_date
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_date) TYPE d.

    "! abap_true nếu là số hợp lệ theo format của Amount (chỉ chữ số, thập phân dùng dấu ,)
    CLASS-METHODS is_valid_amount
      IMPORTING iv_value        TYPE csequence
      RETURNING VALUE(rv_valid) TYPE abap_bool.

    "! Số tiền dạng 1234 hoặc 1234,56 -> decfloat34. Không hợp lệ -> 0
    CLASS-METHODS to_amount
      IMPORTING iv_value         TYPE string
      RETURNING VALUE(rv_amount) TYPE decfloat34.

  PRIVATE SECTION.
    " Thứ tự field phải giống thứ tự cột A..P trong ZCL_DNTT_EXCEL_TEMPLATE=>GET_COLUMNS
    TYPES:
      BEGIN OF ty_row,
        document_sequence_no TYPE string,
        company_code         TYPE string,
        je_type              TYPE string,
        posting_date         TYPE string,
        currency             TYPE string,
        header_text          TYPE string,
        supplier             TYPE string,
        payment_method       TYPE string,
        partner_bank_type    TYPE string,
        profit_center        TYPE string,
        due_on               TYPE string,
        trg_spec_gl_ind      TYPE string,
        assignment           TYPE string,
        item_text            TYPE string,
        amount               TYPE string,
        reference_key_2      TYPE string,
      END OF ty_row,
      tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY,

      " Phần header của 1 dòng - dùng so sánh các dòng cùng Document SequenceNo
      BEGIN OF ty_head_key,
        document_sequence_no TYPE string,
        company_code         TYPE string,
        je_type              TYPE string,
        posting_date         TYPE string,
        currency             TYPE string,
        header_text          TYPE string,
        supplier             TYPE string,
        payment_method       TYPE string,
        partner_bank_type    TYPE string,
        profit_center        TYPE string,
        due_on               TYPE string,
      END OF ty_head_key,

      BEGIN OF ty_doc,
        document_sequence_no TYPE ztb_up_dntt_head-document_sequence_no,
        first_row            TYPE i,
        header               TYPE ty_head_key,
        item_count           TYPE i,
        messages             TYPE tt_message,
      END OF ty_doc,
      tt_doc TYPE SORTED TABLE OF ty_doc WITH UNIQUE KEY document_sequence_no,

      tt_value_set TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line,

      " Chứng từ đã có trong bảng -> upload lại = cập nhật (giữ thông tin tạo + số chứng từ)
      BEGIN OF ty_existing,
        document_sequence_no TYPE ztb_up_dntt_head-document_sequence_no,
        status               TYPE ztb_up_dntt_head-status,
        document_number      TYPE ztb_up_dntt_head-document_number,
        created_on           TYPE ztb_up_dntt_head-created_on,
        created_by           TYPE ztb_up_dntt_head-created_by,
        created_at           TYPE ztb_up_dntt_head-created_at,
      END OF ty_existing,
      tt_existing TYPE HASHED TABLE OF ty_existing WITH UNIQUE KEY document_sequence_no,
      ty_char10    TYPE c LENGTH 10.

    CONSTANTS:
      c_max_messages TYPE i VALUE 100,
      c_message_len  TYPE i VALUE 255,
      c_regex_date   TYPE string VALUE `^\d{2}/\d{2}/\d{4}$`,
      c_regex_serial TYPE string VALUE `^\d{1,7}(\.\d+)?$`,
      c_serial_max   TYPE i VALUE 2958465,  " 31/12/9999
      " Ô kiểu Number: XCO trả về dấu . (vd. 150.23, 1.5, 150.22999999999999).
      " Chỉ nhận 1-2 số lẻ hoặc phần lẻ dài (sai số số thực); 150.000 / 1.000.000 vẫn báo lỗi
      c_regex_number TYPE string VALUE `^\d+\.(\d{1,2}|\d{10,})$`,
      c_amount_dec   TYPE i VALUE 2,
      " Number range cấp Document SequenceNo (tạo bằng ADT + ZCL_DNTT_NR_SETUP)
      c_nr_object    TYPE c LENGTH 10 VALUE 'ZNR_DNTT',
      c_nr_interval  TYPE c LENGTH 2 VALUE '01',
      c_regex_amount TYPE string VALUE `^\d+(,\d+)?$`,
      c_regex_ref2   TYPE string VALUE `^[0-9,]+$`.

    DATA mt_messages     TYPE tt_message.

    " Chứng từ đã Posted có trong file -> bỏ qua, gom số dòng để cảnh báo
    TYPES: BEGIN OF ty_skipped,
             document_sequence_no TYPE string,
             rows                 TYPE string,
           END OF ty_skipped.
    DATA mt_skipped TYPE STANDARD TABLE OF ty_skipped WITH EMPTY KEY.
    DATA mt_company_code TYPE tt_value_set.
    DATA mt_supplier     TYPE tt_value_set.
    DATA mt_currency     TYPE tt_value_set.
    DATA mt_existing_doc TYPE tt_existing.

    METHODS read_rows
      IMPORTING io_sheet       TYPE REF TO if_xco_xlsx_ra_worksheet
                iv_from_row    TYPE i
                iv_to_row      TYPE i OPTIONAL
      RETURNING VALUE(rt_rows) TYPE tt_row.

    METHODS is_valid_template
      IMPORTING io_sheet        TYPE REF TO if_xco_xlsx_ra_worksheet
      RETURNING VALUE(rv_valid) TYPE abap_bool.

    METHODS trim_row
      CHANGING cs_row TYPE ty_row.

    METHODS prefetch_master_data
      IMPORTING it_rows TYPE tt_row.

    METHODS compare_header
      IMPORTING is_first       TYPE ty_head_key
                is_current     TYPE ty_head_key
      RETURNING VALUE(rt_diff) TYPE tt_message.

    METHODS check_key
      IMPORTING is_row          TYPE ty_row
                iv_row          TYPE i
      RETURNING VALUE(rv_valid) TYPE abap_bool.

    "! Thiếu field bắt buộc -> add_error (chặn cả file). Lỗi khác -> rt_errors (ghi vào Message chứng từ)
    METHODS validate_row
      IMPORTING is_row           TYPE ty_row
                iv_row           TYPE i
      RETURNING VALUE(rt_errors) TYPE tt_message.

    METHODS check_in_list
      IMPORTING iv_value        TYPE string
                it_list         TYPE zcl_dntt_excel_template=>tt_ref
                iv_label        TYPE string
      CHANGING  ct_errors       TYPE tt_message.

    METHODS check_date
      IMPORTING iv_value  TYPE string
                iv_label  TYPE string
      CHANGING  ct_errors TYPE tt_message.

    METHODS check_amount
      IMPORTING iv_value  TYPE string
                iv_label  TYPE string
      CHANGING  ct_errors TYPE tt_message.

    METHODS build_message
      IMPORTING it_messages     TYPE tt_message
      RETURNING VALUE(rv_text) TYPE string.

    METHODS normalize_values
      CHANGING cs_row TYPE ty_row.

    METHODS number_to_text
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    METHODS serial_to_text
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    METHODS alpha_in
      IMPORTING iv_value        TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    METHODS add_error
      IMPORTING iv_row  TYPE i DEFAULT 0
                iv_text TYPE string.
ENDCLASS.



CLASS zcl_dntt_excel_upload IMPLEMENTATION.

  METHOD parse.
    TYPES: BEGIN OF ty_numbered,
             row  TYPE i,
             data TYPE ty_row,
           END OF ty_numbered.
    DATA: lt_docs     TYPE tt_doc,
          lt_rows     TYPE tt_row,
          lt_numbered TYPE STANDARD TABLE OF ty_numbered WITH EMPTY KEY.

    CLEAR: et_head, et_item, et_messages, et_warnings, mt_messages, mt_skipped.

    " 1. Đọc file
    TRY.
        DATA(lo_sheet) = xco_cp_xlsx=>document->for_file_content( iv_file
                           )->read_access( )->get_workbook(
                           )->worksheet->for_name( zcl_dntt_excel_template=>c_sheet_data ).

        IF lo_sheet->exists( ) = abap_false.
          add_error( |Không tìm thấy sheet "{ zcl_dntt_excel_template=>c_sheet_data }" trong file| ).
        ELSEIF is_valid_template( lo_sheet ) = abap_false.
          add_error( `File không đúng template. Vui lòng tải lại template mới nhất` ).
        ELSE.
          lt_rows = read_rows( io_sheet    = lo_sheet
                               iv_from_row = zcl_dntt_excel_template=>c_first_data_row ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_error).
        add_error( |Không đọc được file Excel: { lx_error->get_text( ) }| ).
    ENDTRY.

    IF mt_messages IS NOT INITIAL.
      et_messages = mt_messages.
      RETURN.
    ENDIF.

    " 2. Bỏ khoảng trắng, đánh số dòng Excel, bỏ dòng trống
    LOOP AT lt_rows INTO DATA(ls_raw).
      DATA(lv_excel_row) = zcl_dntt_excel_template=>c_first_data_row + sy-tabix - 1.
      trim_row( CHANGING cs_row = ls_raw ).
      normalize_values( CHANGING cs_row = ls_raw ).
      IF ls_raw IS NOT INITIAL.
        APPEND VALUE #( row = lv_excel_row data = ls_raw ) TO lt_numbered.
      ENDIF.
    ENDLOOP.

    IF lt_numbered IS INITIAL.
      add_error( `File không có dữ liệu` ).
      et_messages = mt_messages.
      RETURN.
    ENDIF.

    prefetch_master_data( VALUE #( FOR ls_n IN lt_numbered ( ls_n-data ) ) ).

    " 3. Kiểm tra từng dòng, gom theo Document SequenceNo
    LOOP AT lt_numbered INTO DATA(ls_line).
      DATA(ls_row) = ls_line-data.

      " Key sai -> không lưu được -> chặn cả file
      IF check_key( is_row = ls_row iv_row = ls_line-row ) = abap_false.
        CONTINUE.
      ENDIF.

      " Phân quyền Company code / JE Type: upload luôn tạo mới (01) -> không có quyền thì chặn cả file
      IF ls_row-company_code IS NOT INITIAL AND ls_row-je_type IS NOT INITIAL
         AND zcl_dntt_auth=>is_authorized( iv_company_code = ls_row-company_code
                                           iv_je_type      = ls_row-je_type
                                           iv_actvt        = zcl_dntt_auth=>c_actvt-create ) = abap_false.
        add_error( iv_row  = ls_line-row
                   iv_text = zcl_dntt_auth=>get_message( iv_company_code = ls_row-company_code
                                                         iv_je_type      = ls_row-je_type
                                                         iv_action       = `upload` ) ).
        CONTINUE.
      ENDIF.

      DATA(ls_head_key) = CORRESPONDING ty_head_key( ls_row ).
      DATA(lv_doc_no)   = CONV ztb_up_dntt_head-document_sequence_no( ls_row-document_sequence_no ).

      READ TABLE lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>) WITH TABLE KEY document_sequence_no = lv_doc_no.
      IF sy-subrc <> 0.
        INSERT VALUE #( document_sequence_no = lv_doc_no
                        first_row            = ls_line-row
                        header               = ls_head_key ) INTO TABLE lt_docs ASSIGNING <ls_doc>.
      ELSEIF <ls_doc>-header <> ls_head_key.
        " Cột B..K phải giống dòng đầu tiên của chứng từ -> sai header thì chặn cả file (không upload)
        LOOP AT compare_header( is_first = <ls_doc>-header is_current = ls_head_key ) INTO DATA(lv_diff).
          add_error( |Document SequenceNo { ls_row-document_sequence_no } trong file có lỗi header: | &&
                     |Dòng { ls_line-row }: { lv_diff } khác dòng { <ls_doc>-first_row }| ).
        ENDLOOP.
      ENDIF.

      LOOP AT validate_row( is_row = ls_row iv_row = ls_line-row ) INTO DATA(lv_error).
        APPEND |Dòng { ls_line-row }: { lv_error }| TO <ls_doc>-messages.
      ENDLOOP.

      <ls_doc>-item_count += 1.
      APPEND VALUE #( document_sequence_no = lv_doc_no
                      item                 = <ls_doc>-item_count
                      trg_spec_gl_ind      = ls_row-trg_spec_gl_ind
                      assignment           = ls_row-assignment
                      item_text            = ls_row-item_text
                      amount               = ls_row-amount
                      reference_key_2      = ls_row-reference_key_2 ) TO et_item.
    ENDLOOP.

    et_warnings = VALUE #( FOR ls_s IN mt_skipped
                           ( |Document SequenceNo { ls_s-document_sequence_no } đã Posted - bỏ qua, | &&
                             |không cập nhật (dòng { ls_s-rows })| ) ).

    IF mt_messages IS NOT INITIAL.
      CLEAR et_item.
      DATA(lv_total) = lines( mt_messages ).
      IF lv_total > c_max_messages.
        DATA(lv_cut_from) = c_max_messages + 1.
        DELETE mt_messages FROM lv_cut_from.
        APPEND |... và { lv_total - c_max_messages } lỗi khác| TO mt_messages.
      ENDIF.
      et_messages = mt_messages.
      RETURN.
    ENDIF.

    " 4. Số tạm cho từng nhóm ($1, $2...) - không trùng với mã nhóm user nhập / số thật.
    "    Số thật cấp từ number range khi lưu (saver)
    TYPES: BEGIN OF ty_map,
             group_key TYPE ztb_up_dntt_head-document_sequence_no,
             doc_no    TYPE ztb_up_dntt_head-document_sequence_no,
           END OF ty_map.
    DATA lt_map TYPE HASHED TABLE OF ty_map WITH UNIQUE KEY group_key.

    LOOP AT lt_docs INTO DATA(ls_group).
      INSERT VALUE #( group_key = ls_group-document_sequence_no doc_no = |${ sy-tabix }| ) INTO TABLE lt_map.
    ENDLOOP.

    LOOP AT et_item ASSIGNING FIELD-SYMBOL(<ls_new_item>).
      <ls_new_item>-document_sequence_no = lt_map[ group_key = <ls_new_item>-document_sequence_no ]-doc_no.
    ENDLOOP.

    " 5. Tạo dữ liệu header
    DATA lv_timestamp TYPE timestampl.
    DATA(lv_user) = ``.
    TRY.
        lv_user = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR lv_user.
    ENDTRY.
    GET TIME STAMP FIELD lv_timestamp.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_docs INTO DATA(ls_doc).
      DATA(lv_doc_new) = lt_map[ group_key = ls_doc-document_sequence_no ]-doc_no.
      DATA(lv_total_amount) = CONV decfloat34( 0 ).
      DATA(lv_total_tax)    = CONV decfloat34( 0 ).
      DATA lt_trg TYPE STANDARD TABLE OF string WITH EMPTY KEY.
      CLEAR lt_trg.

      DATA(ls_existing) = VALUE ty_existing( ).  " Luôn tạo mới

      LOOP AT et_item INTO DATA(ls_item) WHERE document_sequence_no = lv_doc_new.
        lv_total_amount += to_amount( CONV #( ls_item-amount ) ).
        lv_total_tax    += to_amount( CONV #( ls_item-reference_key_2 ) ).
        IF ls_item-trg_spec_gl_ind IS NOT INITIAL
           AND NOT line_exists( lt_trg[ table_line = CONV string( ls_item-trg_spec_gl_ind ) ] ).
          APPEND CONV string( ls_item-trg_spec_gl_ind ) TO lt_trg.
        ENDIF.
      ENDLOOP.
      SORT lt_trg.  " Giống custom entity: B, M, B -> BM

      APPEND VALUE #( document_sequence_no  = lv_doc_new
                      company_code          = ls_doc-header-company_code
                      je_type               = ls_doc-header-je_type
                      posting_date          = ls_doc-header-posting_date
                      posting_date_conv     = to_date( ls_doc-header-posting_date )
                      currency              = ls_doc-header-currency
                      header_text           = ls_doc-header-header_text
                      supplier              = alpha_in( ls_doc-header-supplier )
                      payment_method        = ls_doc-header-payment_method
                      partner_bank_type     = ls_doc-header-partner_bank_type
                      profit_center         = ls_doc-header-profit_center
                      due_on                = ls_doc-header-due_on
                      trg_spec_gl_ind       = concat_lines_of( table = lt_trg )
                      total_amount          = lv_total_amount
                      total_tax             = lv_total_tax
                      status                = COND #( WHEN ls_doc-messages IS INITIAL THEN c_status-draft
                                                      ELSE c_status-error )
                      message               = build_message( ls_doc-messages )
                      document_number       = ls_existing-document_number
                      created_on            = COND #( WHEN ls_existing IS INITIAL THEN lv_today
                                                      ELSE ls_existing-created_on )
                      created_by            = COND #( WHEN ls_existing IS INITIAL THEN lv_user
                                                      ELSE ls_existing-created_by )
                      created_at            = COND #( WHEN ls_existing IS INITIAL THEN lv_timestamp
                                                      ELSE ls_existing-created_at )
                      last_changed_by       = lv_user
                      last_changed_at       = lv_timestamp
                      local_last_changed_at = lv_timestamp ) TO et_head.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_rows.
    DATA(lo_builder) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( `A` )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( `P` )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( iv_from_row ) ).

    IF iv_to_row IS NOT INITIAL.
      lo_builder = lo_builder->to_row( xco_cp_xlsx=>coordinate->for_numeric_value( iv_to_row ) ).
    ENDIF.

    io_sheet->select( lo_builder->get_pattern( )
      )->row_stream(
      )->operation->write_to( REF #( rt_rows )
      )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
      )->if_xco_xlsx_ra_operation~execute( ).
  ENDMETHOD.


  METHOD is_valid_template.
    " Row 1 (ẩn) chứa tên kỹ thuật các cột
    DATA(lt_header) = read_rows( io_sheet = io_sheet iv_from_row = 1 iv_to_row = 1 ).
    IF lt_header IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_header) = lt_header[ 1 ].
    trim_row( CHANGING cs_row = ls_header ).

    LOOP AT zcl_dntt_excel_template=>get_columns( ) INTO DATA(ls_col).
      ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_header TO FIELD-SYMBOL(<lv_name>).
      IF sy-subrc <> 0 OR <lv_name> <> ls_col-field.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_valid = abap_true.
  ENDMETHOD.


  METHOD trim_row.
    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_value>).
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      <lv_value> = shift_right( val = shift_left( val = <lv_value> sub = ` ` ) sub = ` ` ).
    ENDDO.
  ENDMETHOD.


  METHOD prefetch_master_data.
    DATA: lr_company TYPE RANGE OF ztb_up_dntt_head-company_code,
          lr_curr    TYPE RANGE OF ztb_up_dntt_head-currency,
          lr_supp    TYPE RANGE OF ztb_up_dntt_head-supplier.

    LOOP AT it_rows INTO DATA(ls_row).
      IF ls_row-company_code IS NOT INITIAL AND strlen( ls_row-company_code ) <= 4.
        INSERT VALUE #( sign = 'I' option = 'EQ' low = ls_row-company_code ) INTO TABLE lr_company.
      ENDIF.
      IF ls_row-currency IS NOT INITIAL AND strlen( ls_row-currency ) <= 3.
        INSERT VALUE #( sign = 'I' option = 'EQ' low = ls_row-currency ) INTO TABLE lr_curr.
      ENDIF.
      IF ls_row-supplier IS NOT INITIAL AND strlen( ls_row-supplier ) <= 10.
        INSERT VALUE #( sign = 'I' option = 'EQ' low = alpha_in( ls_row-supplier ) ) INTO TABLE lr_supp.
      ENDIF.
    ENDLOOP.

    SORT lr_company BY low. DELETE ADJACENT DUPLICATES FROM lr_company COMPARING low.
    SORT lr_curr    BY low. DELETE ADJACENT DUPLICATES FROM lr_curr    COMPARING low.
    SORT lr_supp    BY low. DELETE ADJACENT DUPLICATES FROM lr_supp    COMPARING low.

    " Range rỗng = lấy tất cả -> phải chặn
    IF lr_company IS NOT INITIAL.
      SELECT CompanyCode FROM I_CompanyCode
        WHERE CompanyCode IN @lr_company
        INTO TABLE @DATA(lt_company).
      mt_company_code = VALUE #( FOR ls_c IN lt_company ( CONV #( ls_c-CompanyCode ) ) ).
    ENDIF.

    IF lr_curr IS NOT INITIAL.
      SELECT Currency FROM I_Currency
        WHERE Currency IN @lr_curr
        INTO TABLE @DATA(lt_curr).
      mt_currency = VALUE #( FOR ls_cu IN lt_curr ( CONV #( ls_cu-Currency ) ) ).
    ENDIF.

    IF lr_supp IS NOT INITIAL.
      " Chỉ kiểm tra tồn tại -> không phụ thuộc quyền xem supplier của user upload
      " (supplier nhân viên - account group EMPL - bị DCL của I_Supplier ẩn với user thường)
      SELECT Supplier FROM I_Supplier WITH PRIVILEGED ACCESS
        WHERE Supplier IN @lr_supp
        INTO TABLE @DATA(lt_supp).
      mt_supplier = VALUE #( FOR ls_s IN lt_supp ( CONV #( ls_s-Supplier ) ) ).
    ENDIF.

  ENDMETHOD.


  METHOD compare_header.
    " ty_head_key = cột A..K theo đúng thứ tự trong template
    DATA(lt_columns) = zcl_dntt_excel_template=>get_columns( ).

    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE is_first   TO FIELD-SYMBOL(<lv_first>).
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      ASSIGN COMPONENT sy-index OF STRUCTURE is_current TO FIELD-SYMBOL(<lv_current>).

      IF <lv_current> <> <lv_first>.
        APPEND |{ lt_columns[ sy-index ]-label } "{ <lv_current> }" (dòng đầu: "{ <lv_first> }")| TO rt_diff.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD check_key.
    " Cột A = mã nhóm dòng trong file (Document SequenceNo thật do hệ thống cấp)
    IF is_row-document_sequence_no IS INITIAL.
      add_error( iv_row = iv_row iv_text = `Document SequenceNo (mã nhóm) không được để trống` ).
    ELSEIF strlen( is_row-document_sequence_no ) > 10.
      add_error( iv_row = iv_row iv_text = |Document SequenceNo (mã nhóm) "{ is_row-document_sequence_no }" vượt quá 10 ký tự| ).
    ELSE.
      rv_valid = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD next_document_number.
    cl_numberrange_runtime=>number_get( EXPORTING nr_range_nr = c_nr_interval
                                                  object      = c_nr_object
                                        IMPORTING number      = DATA(lv_number) ).
    " NUMC 20 -> bỏ số 0 đầu (interval 10 chữ số)
    rv_doc_no = shift_left( val = CONV string( lv_number ) sub = `0` ).
  ENDMETHOD.


  METHOD validate_row.
    " Bắt buộc + độ dài: theo định nghĩa cột của template (Document SequenceNo đã check ở check_key)
    LOOP AT zcl_dntt_excel_template=>get_columns( ) INTO DATA(ls_col) FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_value>).
      IF ls_col-mandatory = abap_true AND <lv_value> IS INITIAL.
        " Field bắt buộc (*) để trống -> chặn cả file, báo lỗi ở popup
        add_error( |Document SequenceNo { is_row-document_sequence_no } trong file thiếu dữ liệu bắt buộc: | &&
                   |Dòng { iv_row }: { ls_col-label } không được để trống| ).
      ELSEIF ls_col-length > 0 AND strlen( <lv_value> ) > ls_col-length.
        APPEND |{ ls_col-label } vượt quá { ls_col-length } ký tự| TO rt_errors.
      ENDIF.
    ENDLOOP.

    " Kiểu dữ liệu
    check_date( EXPORTING iv_value = is_row-posting_date iv_label = `Posting date`
                CHANGING  ct_errors = rt_errors ).
    check_date( EXPORTING iv_value = is_row-due_on iv_label = `Due On`
                CHANGING  ct_errors = rt_errors ).
    check_amount( EXPORTING iv_value = is_row-amount iv_label = `Amount`
                  CHANGING  ct_errors = rt_errors ).
    IF is_row-reference_key_2 IS NOT INITIAL AND NOT matches( val = is_row-reference_key_2 regex = c_regex_ref2 ).
      APPEND |Reference Key 2 "{ is_row-reference_key_2 }" chỉ được nhập số và dấu ,| TO rt_errors.
    ENDIF.

    " Giá trị theo sheet Reference
    check_in_list( EXPORTING iv_value = is_row-je_type it_list = zcl_dntt_excel_template=>get_je_types( )
                             iv_label = `Journal Entry Type`
                   CHANGING  ct_errors = rt_errors ).
    check_in_list( EXPORTING iv_value = is_row-payment_method it_list = zcl_dntt_excel_template=>get_payment_methods( )
                             iv_label = `Payment Method`
                   CHANGING  ct_errors = rt_errors ).
    check_in_list( EXPORTING iv_value = is_row-trg_spec_gl_ind it_list = zcl_dntt_excel_template=>get_trg_spec_gl( )
                             iv_label = `Trg. Spec. G/L Ind`
                   CHANGING  ct_errors = rt_errors ).

    " Master data
    IF is_row-company_code IS NOT INITIAL AND NOT line_exists( mt_company_code[ table_line = is_row-company_code ] ).
      APPEND |Company code { is_row-company_code } không tồn tại| TO rt_errors.
    ENDIF.
    IF is_row-currency IS NOT INITIAL AND NOT line_exists( mt_currency[ table_line = is_row-currency ] ).
      APPEND |Currency { is_row-currency } không tồn tại| TO rt_errors.
    ENDIF.
    IF is_row-supplier IS NOT INITIAL AND NOT line_exists( mt_supplier[ table_line = alpha_in( is_row-supplier ) ] ).
      APPEND |Supplier { is_row-supplier } không tồn tại| TO rt_errors.
    ENDIF.
  ENDMETHOD.


  METHOD check_in_list.
    IF iv_value IS NOT INITIAL AND NOT line_exists( it_list[ code = iv_value ] ).
      APPEND |{ iv_label } "{ iv_value }" không có trong sheet Reference| TO ct_errors.
    ENDIF.
  ENDMETHOD.


  METHOD check_date.
    IF iv_value IS INITIAL.
      RETURN.
    ELSEIF NOT matches( val = iv_value regex = c_regex_date ).
      APPEND |{ iv_label } "{ iv_value }" sai định dạng dd/mm/yyyy| TO ct_errors.
    ELSEIF to_date( iv_value ) IS INITIAL.
      APPEND |{ iv_label } "{ iv_value }" không tồn tại| TO ct_errors.
    ENDIF.
  ENDMETHOD.


  METHOD check_amount.
    IF iv_value IS NOT INITIAL AND NOT matches( val = iv_value regex = c_regex_amount ).
      APPEND |{ iv_label } "{ iv_value }" không hợp lệ (chỉ nhập số, thập phân dùng dấu ,)| TO ct_errors.
    ENDIF.
  ENDMETHOD.


  METHOD to_date.
    DATA lv_back TYPE d.

    IF NOT matches( val = iv_value regex = c_regex_date ).
      RETURN.
    ENDIF.

    rv_date = substring( val = iv_value off = 6 len = 4 )
           && substring( val = iv_value off = 3 len = 2 )
           && substring( val = iv_value off = 0 len = 2 ).

    " Ngày không tồn tại (vd. 31/02/2026): đổi sang số ngày rồi đổi ngược lại sẽ không khớp
    DATA(lv_days) = CONV i( rv_date ).
    lv_back = lv_days.
    IF lv_days = 0 OR lv_back <> rv_date.
      CLEAR rv_date.
    ENDIF.
  ENDMETHOD.


  METHOD is_valid_amount.
    rv_valid = xsdbool( matches( val = iv_value regex = c_regex_amount ) ).
  ENDMETHOD.


  METHOD to_amount.
    IF iv_value IS INITIAL OR NOT matches( val = iv_value regex = c_regex_amount ).
      RETURN.
    ENDIF.
    rv_amount = replace( val = iv_value sub = `,` with = `.` ).
  ENDMETHOD.


  METHOD build_message.
    rv_text = concat_lines_of( table = it_messages sep = `; ` ).
    IF strlen( rv_text ) > c_message_len.
      rv_text = substring( val = rv_text len = c_message_len - 3 ) && `...`.
    ENDIF.
  ENDMETHOD.


  METHOD normalize_values.
    " Ô bị Excel lưu kiểu Date / Number (vd. copy/paste từ file khác) -> XCO đọc ra giá trị gốc.
    " Đổi về dạng như ô Text (dd/mm/yyyy, số lẻ dùng dấu ,) để kiểm tra / lưu.
    cs_row-posting_date    = serial_to_text( cs_row-posting_date ).
    cs_row-due_on          = serial_to_text( cs_row-due_on ).
    cs_row-amount          = number_to_text( cs_row-amount ).
    cs_row-reference_key_2 = number_to_text( cs_row-reference_key_2 ).
  ENDMETHOD.


  METHOD number_to_text.
    rv_text = iv_value.
    IF NOT matches( val = iv_value regex = c_regex_number ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_number) = round( val = CONV decfloat34( iv_value ) dec = c_amount_dec ).
      CATCH cx_sy_conversion_error.
        RETURN.
    ENDTRY.

    " 150.22999999999999 -> 150,23 ; 1.5 -> 1,5
    rv_text = replace( val = |{ lv_number STYLE = SIMPLE }| sub = `.` with = `,` ).
  ENDMETHOD.


  METHOD serial_to_text.
    rv_text = iv_value.
    IF NOT matches( val = iv_value regex = c_regex_serial ).
      RETURN.
    ENDIF.

    DATA(lv_serial) = CONV i( segment( val = iv_value index = 1 sep = `.` ) ).
    IF lv_serial < 1 OR lv_serial > c_serial_max.
      RETURN.
    ENDIF.

    " Serial Excel tính từ 30/12/1899
    DATA(lv_date) = CONV d( CONV d( '18991230' ) + lv_serial ).
    rv_text = |{ lv_date+6(2) }/{ lv_date+4(2) }/{ lv_date(4) }|.
  ENDMETHOD.


  METHOD alpha_in.
    IF strlen( iv_value ) > 10.
      rv_value = iv_value.
      RETURN.
    ENDIF.
    " ALPHA = IN giữ nguyên độ dài 10 của field: mã có chữ (vd. NS0088) bị đệm khoảng trắng
    " phía sau -> phải cắt, nếu không so sánh string với mt_supplier sẽ không khớp
    rv_value = condense( |{ CONV ty_char10( iv_value ) ALPHA = IN }| ).
  ENDMETHOD.


  METHOD add_error.
    APPEND COND #( WHEN iv_row > 0 THEN |Dòng { iv_row }: { iv_text }| ELSE iv_text ) TO mt_messages.
  ENDMETHOD.

ENDCLASS.

