CLASS zcl_ce_up_dntt_f01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      ty_result TYPE zce_up_dntt,
      tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY,
      ry_string TYPE RANGE OF string,
      ry_date   TYPE RANGE OF d.

    CLASS-METHODS requested
      IMPORTING
        io_request TYPE REF TO if_rap_query_request
      EXPORTING
        et_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    CLASS-METHODS main
      IMPORTING
        it_filters TYPE if_rap_query_filter=>tt_name_range_pairs
      EXPORTING
        et_result  TYPE tt_result.

    CLASS-METHODS response
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_result   TYPE tt_result.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS convert_date
      IMPORTING
        iv_text        TYPE clike
      RETURNING
        VALUE(rv_date) TYPE d.

    CLASS-METHODS to_number
      IMPORTING
        iv_text         TYPE clike
      RETURNING
        VALUE(rv_value) TYPE decfloat34.
ENDCLASS.



CLASS zcl_ce_up_dntt_f01 IMPLEMENTATION.


  METHOD requested.
    TRY.
        et_filters = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR et_filters.
    ENDTRY.
  ENDMETHOD.


  METHOD main.
    TYPES:
      BEGIN OF lty_sum,
        document_sequence_no TYPE ztb_up_dntt_head-document_sequence_no,
        trg_spec_gl_ind      TYPE string,
        total_amount         TYPE decfloat34,
        total_tax            TYPE decfloat34,
        match_trg            TYPE abap_bool,  " Có item thỏa filter Trg. Spec. G/L Ind
      END OF lty_sum.

    DATA:
      lt_sum  TYPE SORTED TABLE OF lty_sum WITH UNIQUE KEY document_sequence_no,
      lt_spgl TYPE SORTED TABLE OF ztb_up_dntt_item-trg_spec_gl_ind WITH UNIQUE KEY table_line,
      ls_sum  TYPE lty_sum.

    LOOP AT it_filters INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'DOCUMENTSEQUENCENO'.
          DATA(lr_documentsequenceno) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'COMPANYCODE'.
          DATA(lr_companycode) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'JETYPE'.
          DATA(lr_jetype) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'TRGSPECGLIND'.
          DATA(lr_trgspecglind) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'SUPPLIER'.
          DATA(lr_supplier) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'DOCUMENTNUMBER'.
          DATA(lr_documentnumber) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'STATUS'.
          DATA(lr_status) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'CREATEDBY'.
          DATA(lr_createdby) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'POSTINGDATE'.
          DATA(lr_postingdate) = CORRESPONDING ry_date( ls_filter-range ).
        WHEN 'CREATEDON'.
          DATA(lr_createdon) = CORRESPONDING ry_date( ls_filter-range ).
      ENDCASE.
    ENDLOOP.

    " Đọc qua CDS ZI_UP_DNTT_HEAD (không đọc thẳng bảng) -> áp dụng DCL:
    " chỉ thấy chứng từ thuộc Company code (F_BKPF_BUK) / JE Type (F_BKPF_BLA) được phân quyền
    SELECT FROM zi_up_dntt_head
    FIELDS
        DocumentSequenceNo AS document_sequence_no,
        CompanyCode        AS company_code,
        JeType             AS je_type,
        PostingDate        AS posting_date,
        Currency           AS currency,
        HeaderText         AS header_text,
        Supplier           AS supplier,
        PaymentMethod      AS payment_method,
        PartnerBankType    AS partner_bank_type,
        ProfitCenter       AS profit_center,
        DueOn              AS due_on,
        Status             AS status,
        DocumentNumber     AS document_number,
        Message            AS message,
        CreatedBy          AS created_by,
        CreatedAt          AS created_at,
        LastChangedBy      AS last_changed_by,
        LastChangedAt      AS last_changed_at
    WHERE
        DocumentSequenceNo IN @lr_documentsequenceno
        AND CompanyCode    IN @lr_companycode
        AND JeType         IN @lr_jetype
        AND Supplier       IN @lr_supplier
        AND DocumentNumber IN @lr_documentnumber
        AND Status         IN @lr_status
        AND CreatedBy      IN @lr_createdby
    INTO TABLE @DATA(lt_head).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT FROM ztb_up_dntt_item
    FIELDS
        document_sequence_no,
        item,
        trg_spec_gl_ind,
        amount,
        reference_key_2
    FOR ALL ENTRIES IN @lt_head
    WHERE
        document_sequence_no = @lt_head-document_sequence_no
    INTO TABLE @DATA(lt_item).

    SORT lt_item BY document_sequence_no item.

    LOOP AT lt_item INTO DATA(ls_item) GROUP BY ls_item-document_sequence_no INTO DATA(lg_doc).
      CLEAR: ls_sum, lt_spgl.
      ls_sum-document_sequence_no = lg_doc.

      LOOP AT GROUP lg_doc INTO DATA(ls_member).
        ls_sum-total_amount += to_number( ls_member-amount ).
        ls_sum-total_tax    += to_number( ls_member-reference_key_2 ).
        IF ls_member-trg_spec_gl_ind IS NOT INITIAL.
          " Distinct: B, M, B -> BM
          INSERT ls_member-trg_spec_gl_ind INTO TABLE lt_spgl.
        ENDIF.
        IF ls_member-trg_spec_gl_ind IN lr_trgspecglind.
          ls_sum-match_trg = abap_true.
        ENDIF.
      ENDLOOP.

      ls_sum-trg_spec_gl_ind = concat_lines_of( table = lt_spgl ).
      INSERT ls_sum INTO TABLE lt_sum.
    ENDLOOP.

    TRY.
        DATA(lv_timezone) = cl_abap_context_info=>get_user_time_zone( ).
      CATCH cx_abap_context_info_error.
        lv_timezone = 'UTC'.
    ENDTRY.

    " Supplier Name / Bank Acc / Bank / Acc.Holder: dùng chung logic với màn hình chi tiết
    DATA(lt_supplier) = VALUE zcl_dntt_bank_calc=>tt_data( FOR ls_h IN lt_head
                                                           ( supplier        = ls_h-supplier
                                                             partnerbanktype = ls_h-partner_bank_type ) ).
    SORT lt_supplier BY supplier partnerbanktype.
    DELETE ADJACENT DUPLICATES FROM lt_supplier COMPARING supplier partnerbanktype.
    zcl_dntt_bank_calc=>fill( CHANGING ct_data = lt_supplier ).

    LOOP AT lt_head INTO DATA(ls_head).
      READ TABLE lt_sum INTO ls_sum WITH TABLE KEY document_sequence_no = ls_head-document_sequence_no.
      IF sy-subrc <> 0.
        CLEAR ls_sum.
      ENDIF.

      " Filter Trg. Spec. G/L Ind theo item (header hiển thị dạng gộp, vd. BM)
      IF lr_trgspecglind IS NOT INITIAL AND ls_sum-match_trg = abap_false.
        CONTINUE.
      ENDIF.

      DATA(ls_base) = VALUE ty_result(
          DocumentSequenceNo = ls_head-document_sequence_no
          TrgSpecGlInd       = ls_sum-trg_spec_gl_ind
          Status             = ls_head-status
          " Status lưu dạng Draft/Checked/Error/Posted -> so sánh không phân biệt hoa thường
          StatusCriticality  = SWITCH #( to_upper( ls_head-status )
                                         WHEN 'POSTED'  THEN 3
                                         WHEN 'CHECKED' THEN 5
                                         WHEN 'ERROR'   THEN 1
                                         ELSE 0 )
          DocumentNumber     = ls_head-document_number
          CompanyCode        = ls_head-company_code
          JeType             = ls_head-je_type
          PostingDate        = convert_date( ls_head-posting_date )
          Currency           = ls_head-currency
          HeaderText         = ls_head-header_text
          Supplier           = ls_head-supplier
          PaymentMethod      = ls_head-payment_method
          PartnerBankType    = ls_head-partner_bank_type
          ProfitCenter       = ls_head-profit_center
          DueOn              = convert_date( ls_head-due_on )
          TotalAmount        = ls_sum-total_amount
          TotalTax           = ls_sum-total_tax
          Message            = ls_head-message
          CreatedBy          = ls_head-created_by
          ChangedBy          = ls_head-last_changed_by ).

      READ TABLE lt_supplier INTO DATA(ls_supplier)
           WITH KEY supplier        = ls_head-supplier
                    partnerbanktype = ls_head-partner_bank_type
           BINARY SEARCH.
      IF sy-subrc = 0.
        ls_base-SupplierName  = ls_supplier-suppliername.
        ls_base-BankAccount   = ls_supplier-bankaccount.
        ls_base-Bank          = ls_supplier-bank.
        ls_base-AccountHolder = ls_supplier-accountholder.
      ENDIF.

      IF ls_head-created_at IS NOT INITIAL.
        CONVERT TIME STAMP ls_head-created_at TIME ZONE lv_timezone INTO DATE ls_base-CreatedOn.
      ENDIF.
      IF ls_head-last_changed_at IS NOT INITIAL.
        CONVERT TIME STAMP ls_head-last_changed_at TIME ZONE lv_timezone INTO DATE ls_base-ChangedOn.
      ENDIF.

      " 1 dòng / chứng từ
      APPEND ls_base TO et_result.
    ENDLOOP.

    DELETE et_result WHERE NOT ( PostingDate IN lr_postingdate )
                        OR NOT ( CreatedOn   IN lr_createdon ).
  ENDMETHOD.


  METHOD response.
    DATA(lv_total) = lines( ct_result ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( CONV int8( lv_total ) ).
    ENDIF.

    DATA(lt_sort) = io_request->get_sort_elements( ).
    IF lt_sort IS NOT INITIAL.
      DATA lt_sort_order TYPE abap_sortorder_tab.
      LOOP AT lt_sort INTO DATA(ls_sort).
        APPEND VALUE #(
            name       = ls_sort-element_name
            descending = ls_sort-descending
        ) TO lt_sort_order.
      ENDLOOP.
      SORT ct_result BY (lt_sort_order).
    ELSE.
      " Mặc định: Document SequenceNo giảm dần -> chứng từ mới lên trên
      SORT ct_result BY DocumentSequenceNo DESCENDING.
    ENDIF.

    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).

    IF lv_top = if_rap_query_paging=>page_size_unlimited.
      lv_top = lv_total.
    ENDIF.

    IF lv_skip > 0.
      DELETE ct_result TO lv_skip.
    ENDIF.

    IF lv_top < lines( ct_result ).
      DELETE ct_result FROM lv_top + 1.
    ENDIF.

    IF io_request->is_data_requested( ).
      io_response->set_data( ct_result ).
    ENDIF.
  ENDMETHOD.


  METHOD convert_date.
    DATA lv_date TYPE d.

    DATA(lv_text) = condense( val = CONV string( iv_text ) ).
    SPLIT lv_text AT '/' INTO DATA(lv_dd) DATA(lv_mm) DATA(lv_yyyy).

    IF strlen( lv_dd ) <> 2 OR strlen( lv_mm ) <> 2 OR strlen( lv_yyyy ) <> 4
       OR lv_dd CN '0123456789' OR lv_mm CN '0123456789' OR lv_yyyy CN '0123456789'.
      RETURN.
    ENDIF.

    lv_date = |{ lv_yyyy }{ lv_mm }{ lv_dd }|.
    IF CONV i( lv_date ) = 0.
      RETURN.
    ENDIF.

    rv_date = lv_date.
  ENDMETHOD.


  METHOD to_number.
    " Số tiền upload dùng dấu , cho phần thập phân (vd. 10,11)
    DATA(lv_text) = condense( val = CONV string( iv_text ) ).
    IF lv_text IS INITIAL.
      RETURN.
    ENDIF.

    rv_value = zcl_dntt_excel_upload=>to_amount( lv_text ).
  ENDMETHOD.
ENDCLASS.

