"! Gọi API Journal Entry - Post (Synchronous) - SOAP JournalEntryCreateRequestConfirmation_In
"! (SAP_COM_0002) để Check (TestDataIndicator = true) / Post (false) các đề nghị thanh toán.
"! Mỗi chứng từ = 1 JournalEntryCreateRequest, mỗi item = 1 CreditorItem (Special G/L F).
CLASS zcl_dntt_je_api DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      tt_doc_no TYPE STANDARD TABLE OF ztb_up_dntt_head-document_sequence_no WITH EMPTY KEY,

      BEGIN OF ty_result,
        document_sequence_no TYPE ztb_up_dntt_head-document_sequence_no,
        success              TYPE abap_bool,
        technical_error      TYPE abap_bool,  " Lỗi kết nối / hệ thống -> không đổi status
        accounting_document  TYPE ztb_up_dntt_head-document_number,
        message              TYPE string,
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CONSTANTS:
      " User / password / host gọi API lấy từ ZTB_API_AUTH (mỗi môi trường 1 dòng riêng)
      c_system_id     TYPE ztb_api_auth-systemid VALUE 'CASLA',
      c_uri_path      TYPE string VALUE `/sap/bc/srt/scs_ext/sap/journalentrycreaterequestconfi`,
      c_soap_action   TYPE string
        VALUE `http://sap.com/xi/SAPSCORE/SFIN/JournalEntryCreateRequestConfirmation_In/JournalEntryCreateRequestConfirmation_InRequest`,
      c_max_per_call  TYPE i VALUE 10.      " API: 1-10 chứng từ / lần

    "! iv_test_run = abap_true -> TestDataIndicator = true (Check, không tạo chứng từ)
    METHODS execute
      IMPORTING it_doc_no        TYPE tt_doc_no
                iv_test_run      TYPE abap_bool
      RETURNING VALUE(rt_result) TYPE tt_result.

  PRIVATE SECTION.
    TYPES:
      tt_head TYPE STANDARD TABLE OF ztb_up_dntt_head WITH EMPTY KEY,
      tt_item TYPE STANDARD TABLE OF ztb_up_dntt_item WITH EMPTY KEY.

    CONSTANTS:
      c_ns_sfin          TYPE string VALUE `http://sap.com/xi/SAPSCORE/SFIN`,
      " Giá trị mặc định theo sheet Mapping API
      c_orig_ref_doc_typ TYPE string VALUE `BKPFF`,
      c_business_trans   TYPE string VALUE `RFST`,
      c_debit_credit     TYPE string VALUE `H`,
      c_special_gl       TYPE string VALUE `F`,
      c_net_payment_days TYPE string VALUE `0`,
      c_severity_error   TYPE i VALUE 3.

    METHODS get_url
      IMPORTING iv_host       TYPE csequence
      RETURNING VALUE(rv_url) TYPE string.

    METHODS call_api
      IMPORTING it_head          TYPE tt_head
                it_item          TYPE tt_item
                iv_test_run      TYPE abap_bool
      RETURNING VALUE(rt_result) TYPE tt_result.

    METHODS build_request
      IMPORTING it_head       TYPE tt_head
                it_item       TYPE tt_item
                iv_test_run   TYPE abap_bool
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS build_entry
      IMPORTING is_head       TYPE ztb_up_dntt_head
                it_item       TYPE tt_item
                iv_test_run   TYPE abap_bool
                iv_now        TYPE string
                iv_user       TYPE string
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS parse_response
      IMPORTING iv_response      TYPE string
                it_head          TYPE tt_head
      RETURNING VALUE(rt_result) TYPE tt_result.

    METHODS tag
      IMPORTING iv_name       TYPE string
                iv_value      TYPE string
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS to_iso_date
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_date) TYPE string.

    METHODS format_amount
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    METHODS error_for_all
      IMPORTING it_head          TYPE tt_head
                iv_message       TYPE string
                iv_technical     TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rt_result) TYPE tt_result.
ENDCLASS.



CLASS zcl_dntt_je_api IMPLEMENTATION.

  METHOD execute.
    DATA lr_doc TYPE RANGE OF ztb_up_dntt_head-document_sequence_no.

    lr_doc = VALUE #( FOR lv_doc IN it_doc_no ( sign = 'I' option = 'EQ' low = lv_doc ) ).
    IF lr_doc IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM ztb_up_dntt_head
      WHERE document_sequence_no IN @lr_doc
      ORDER BY document_sequence_no
      INTO TABLE @DATA(lt_head).

    SELECT * FROM ztb_up_dntt_item
      WHERE document_sequence_no IN @lr_doc
      ORDER BY document_sequence_no, item
      INTO TABLE @DATA(lt_item).

    " Chia lô tối đa 10 chứng từ / lần gọi API
    DATA lt_chunk TYPE tt_head.
    LOOP AT lt_head INTO DATA(ls_head).
      APPEND ls_head TO lt_chunk.
      IF lines( lt_chunk ) = c_max_per_call.
        APPEND LINES OF call_api( it_head = lt_chunk it_item = lt_item iv_test_run = iv_test_run ) TO rt_result.
        CLEAR lt_chunk.
      ENDIF.
    ENDLOOP.
    IF lt_chunk IS NOT INITIAL.
      APPEND LINES OF call_api( it_head = lt_chunk it_item = lt_item iv_test_run = iv_test_run ) TO rt_result.
    ENDIF.
  ENDMETHOD.


  METHOD call_api.
    SELECT SINGLE api_user, api_password, api_url
      FROM ztb_api_auth
      WHERE systemid = @c_system_id
      INTO @DATA(ls_auth).
    IF sy-subrc <> 0 OR ls_auth-api_url IS INITIAL OR ls_auth-api_user IS INITIAL.
      rt_result = error_for_all( it_head    = it_head
                                 iv_message = |Chưa khai báo user API trong ZTB_API_AUTH (SYSTEMID = { c_system_id })| ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_url( i_url = get_url( ls_auth-api_url ) ).
        DATA(lo_client)  = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_authorization_basic( i_username = CONV #( ls_auth-api_user )
                                             i_password = CONV #( ls_auth-api_password ) ).
        lo_request->set_header_field( i_name = `Content-Type` i_value = `text/xml; charset=utf-8` ).
        lo_request->set_header_field( i_name = `SOAPAction`   i_value = |"{ c_soap_action }"| ).
        lo_request->set_text( build_request( it_head = it_head it_item = it_item iv_test_run = iv_test_run ) ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
        DATA(lv_status)   = lo_response->get_status( ).
        DATA(lv_body)     = lo_response->get_text( ).
        lo_client->close( ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_http).
        rt_result = error_for_all( it_head = it_head iv_message = |Lỗi kết nối API: { lx_http->get_text( ) }| ).
        RETURN.
    ENDTRY.

    " SOAP fault (HTTP 500) cũng có body XML -> parse được thì lấy lỗi từ body
    rt_result = parse_response( iv_response = lv_body it_head = it_head ).
    IF rt_result IS INITIAL.
      rt_result = error_for_all( it_head    = it_head
                                 iv_message = |API lỗi HTTP { lv_status-code } { lv_status-reason }| ).
    ENDIF.
  ENDMETHOD.


  METHOD get_url.
    " API_URL lưu host (vd. my426501-api.s4hana.cloud.sap) hoặc URL đầy đủ có https://
    rv_url = condense( val = CONV string( iv_host ) ).
    IF NOT matches( val = rv_url regex = `^https?://.*` case = abap_false ).
      rv_url = |https://{ rv_url }|.
    ENDIF.
    WHILE rv_url CP '*/'.
      rv_url = substring( val = rv_url len = strlen( rv_url ) - 1 ).
    ENDWHILE.
    IF NOT rv_url CS c_uri_path.
      rv_url &&= c_uri_path.
    ENDIF.
  ENDMETHOD.


  METHOD build_request.
    DATA lv_ts TYPE timestamp.
    GET TIME STAMP FIELD lv_ts.
    DATA(lv_now) = |{ lv_ts TIMESTAMP = ISO }Z|.

    DATA(lv_user) = ``.
    TRY.
        lv_user = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR lv_user.
    ENDTRY.

    DATA(lv_test) = COND string( WHEN iv_test_run = abap_true THEN `true` ELSE `false` ).
    DATA(lv_message_id) = ``.
    TRY.
        lv_message_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        lv_message_id = |DNTT{ lv_ts }|.
    ENDTRY.

    rv_xml = `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"`
          && | xmlns:sfin="{ c_ns_sfin }">|
          && `<soapenv:Header/><soapenv:Body>`
          && `<sfin:JournalEntryBulkCreateRequest>`
          && `<MessageHeader>`
          && tag( iv_name = `ID`                iv_value = lv_message_id )
          && tag( iv_name = `CreationDateTime`  iv_value = lv_now )
          && tag( iv_name = `TestDataIndicator` iv_value = lv_test )
          && `</MessageHeader>`.

    LOOP AT it_head INTO DATA(ls_head).
      rv_xml &&= build_entry( is_head     = ls_head
                              it_item     = VALUE #( FOR ls_i IN it_item
                                                     WHERE ( document_sequence_no = ls_head-document_sequence_no )
                                                     ( ls_i ) )
                              iv_test_run = iv_test_run
                              iv_now      = lv_now
                              iv_user     = lv_user ).
    ENDLOOP.

    rv_xml &&= `</sfin:JournalEntryBulkCreateRequest></soapenv:Body></soapenv:Envelope>`.
  ENDMETHOD.


  METHOD build_entry.
    DATA(lv_test)     = COND string( WHEN iv_test_run = abap_true THEN `true` ELSE `false` ).
    DATA(lv_posting)  = to_iso_date( is_head-posting_date_conv ).
    DATA(lv_due_on)   = to_iso_date( zcl_dntt_excel_upload=>to_date( CONV #( is_head-due_on ) ) ).
    DATA(lv_currency) = escape( val = CONV string( is_head-currency ) format = cl_abap_format=>e_xml_attr ).

    " ID của từng chứng từ = Document SequenceNo -> map lại kết quả qua MessageHeader/ReferenceID
    rv_xml = `<JournalEntryCreateRequest>`
          && `<MessageHeader>`
          && tag( iv_name = `ID`                iv_value = CONV #( is_head-document_sequence_no ) )
          && tag( iv_name = `CreationDateTime`  iv_value = iv_now )
          && tag( iv_name = `TestDataIndicator` iv_value = lv_test )
          && `</MessageHeader>`
          && `<JournalEntry>`
          && tag( iv_name = `OriginalReferenceDocumentType` iv_value = c_orig_ref_doc_typ )
          && tag( iv_name = `BusinessTransactionType`       iv_value = c_business_trans )
          && tag( iv_name = `AccountingDocumentType`        iv_value = CONV #( is_head-je_type ) )
          && tag( iv_name = `DocumentHeaderText`            iv_value = CONV #( is_head-header_text ) )
          && tag( iv_name = `CreatedByUser`                 iv_value = iv_user )
          && tag( iv_name = `CompanyCode`                   iv_value = CONV #( is_head-company_code ) )
          && tag( iv_name = `DocumentDate`                  iv_value = lv_posting )
          && tag( iv_name = `PostingDate`                   iv_value = lv_posting )
          && tag( iv_name = `ExchangeRateDate`              iv_value = lv_posting ).

    LOOP AT it_item INTO DATA(ls_item).
      rv_xml &&= `<CreditorItem>`
              && tag( iv_name = `ReferenceDocumentItem` iv_value = |{ CONV i( ls_item-item ) }| )
              && tag( iv_name = `Creditor`              iv_value = CONV #( is_head-supplier ) )
              && |<AmountInTransactionCurrency currencyCode="{ lv_currency }">|
              && format_amount( CONV #( ls_item-amount ) )
              && `</AmountInTransactionCurrency>`
              && tag( iv_name = `DebitCreditCode`               iv_value = c_debit_credit )
              && tag( iv_name = `DocumentItemText`              iv_value = CONV #( ls_item-item_text ) )
              && tag( iv_name = `AssignmentReference`           iv_value = CONV #( ls_item-assignment ) )
              && tag( iv_name = `Reference2IDByBusinessPartner` iv_value = CONV #( ls_item-reference_key_2 ) )
              && `<CashDiscountTerms>`
              && tag( iv_name = `DueCalculationBaseDate` iv_value = lv_due_on )
              && tag( iv_name = `NetPaymentDays`         iv_value = c_net_payment_days )
              && `</CashDiscountTerms>`
              && `<PaymentDetails>`
              && tag( iv_name = `PaymentMethod`           iv_value = CONV #( is_head-payment_method ) )
              && tag( iv_name = `BPBankAccountInternalID` iv_value = CONV #( is_head-partner_bank_type ) )
              && `</PaymentDetails>`
              " ProfitCenter nằm trong DownPaymentTerms (đặt ở CreditorItem sẽ bị SAP bỏ qua)
              && `<DownPaymentTerms>`
              && tag( iv_name = `SpecialGLCode`       iv_value = c_special_gl )
              && tag( iv_name = `TargetSpecialGLCode` iv_value = CONV #( ls_item-trg_spec_gl_ind ) )
              && tag( iv_name = `ProfitCenter`        iv_value = CONV #( is_head-profit_center ) )
              && `</DownPaymentTerms>`
              && `</CreditorItem>`.
    ENDLOOP.

    rv_xml &&= `</JournalEntry></JournalEntryCreateRequest>`.
  ENDMETHOD.


  METHOD parse_response.
    " Cấu trúc response:
    "  JournalEntryBulkCreateConfirmation
    "    MessageHeader
    "    JournalEntryCreateConfirmation            (1 / chứng từ)
    "      MessageHeader/ReferenceID               = ID request = Document SequenceNo
    "      JournalEntryCreateConfirmation/AccountingDocument
    "      Log/Item (SeverityCode, Note)
    "    Log/Item                                   (lỗi chung)
    "  hoặc soap:Fault/faultstring
    TYPES: BEGIN OF ty_entry,
             reference_id TYPE string,
             acc_doc      TYPE string,
             errors       TYPE STANDARD TABLE OF string WITH EMPTY KEY,
           END OF ty_entry.

    DATA: lt_path       TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lt_entries    TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY,
          ls_entry      TYPE ty_entry,
          lv_in_entry   TYPE abap_bool,
          lt_bulk_error TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lv_severity   TYPE i,
          lv_note       TYPE string.

    IF iv_response IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_reader) = cl_sxml_string_reader=>create( cl_abap_conv_codepage=>create_out( )->convert( iv_response ) ).

        DO.
          DATA(lo_node) = lo_reader->read_next_node( ).
          IF lo_node IS INITIAL.
            EXIT.
          ENDIF.

          CASE lo_node->type.
            WHEN if_sxml_node=>co_nt_element_open.
              DATA(lv_name)   = CAST if_sxml_open_element( lo_node )->qname-name.
              DATA(lv_parent) = VALUE string( lt_path[ lines( lt_path ) ] OPTIONAL ).
              APPEND lv_name TO lt_path.

              IF lv_name = `JournalEntryCreateConfirmation` AND lv_parent = `JournalEntryBulkCreateConfirmation`.
                CLEAR ls_entry.
                lv_in_entry = abap_true.
              ELSEIF lv_name = `Item` AND lv_parent = `Log`.
                CLEAR: lv_severity, lv_note.
              ENDIF.

            WHEN if_sxml_node=>co_nt_value.
              DATA(lv_value)   = CAST if_sxml_value_node( lo_node )->get_value( ).
              DATA(lv_current) = VALUE string( lt_path[ lines( lt_path ) ] OPTIONAL ).
              DATA(lv_owner)   = VALUE string( lt_path[ lines( lt_path ) - 1 ] OPTIONAL ).

              CASE lv_current.
                WHEN `ReferenceID`.
                  IF lv_in_entry = abap_true AND lv_owner = `MessageHeader`.
                    ls_entry-reference_id = lv_value.
                  ENDIF.
                WHEN `AccountingDocument`.
                  IF lv_in_entry = abap_true.
                    ls_entry-acc_doc = lv_value.
                  ENDIF.
                WHEN `SeverityCode`.
                  lv_severity = lv_value.
                WHEN `Note`.
                  lv_note = lv_value.
                WHEN `faultstring`.
                  APPEND lv_value TO lt_bulk_error.
              ENDCASE.

            WHEN if_sxml_node=>co_nt_element_close.
              DATA(lv_closed) = VALUE string( lt_path[ lines( lt_path ) ] OPTIONAL ).
              DELETE lt_path INDEX lines( lt_path ).
              DATA(lv_closed_parent) = VALUE string( lt_path[ lines( lt_path ) ] OPTIONAL ).

              IF lv_closed = `Item` AND lv_closed_parent = `Log` AND lv_severity >= c_severity_error.
                IF lv_in_entry = abap_true.
                  APPEND lv_note TO ls_entry-errors.
                ELSE.
                  APPEND lv_note TO lt_bulk_error.
                ENDIF.
              ELSEIF lv_closed = `JournalEntryCreateConfirmation` AND lv_closed_parent = `JournalEntryBulkCreateConfirmation`.
                APPEND ls_entry TO lt_entries.
                lv_in_entry = abap_false.
              ENDIF.
          ENDCASE.
        ENDDO.

      CATCH cx_root.
        " Response không phải XML -> để call_api báo lỗi HTTP
        CLEAR rt_result.
        RETURN.
    ENDTRY.

    IF lt_entries IS INITIAL AND lt_bulk_error IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_bulk_text) = concat_lines_of( table = lt_bulk_error sep = `; ` ).

    LOOP AT it_head INTO DATA(ls_head).
      DATA(ls_result) = VALUE ty_result( document_sequence_no = ls_head-document_sequence_no ).
      READ TABLE lt_entries INTO DATA(ls_found) WITH KEY reference_id = CONV string( ls_head-document_sequence_no ).

      IF sy-subrc = 0 AND ls_found-errors IS INITIAL AND lt_bulk_error IS INITIAL.
        ls_result-success = abap_true.
        ls_result-accounting_document = COND #( WHEN ls_found-acc_doc CO `0` THEN `` ELSE ls_found-acc_doc ).
      ELSE.
        ls_result-message = COND #( WHEN sy-subrc = 0 AND ls_found-errors IS NOT INITIAL
                                    THEN concat_lines_of( table = ls_found-errors sep = `; ` )
                                    WHEN lv_bulk_text IS NOT INITIAL
                                    THEN lv_bulk_text
                                    ELSE `API không trả kết quả cho chứng từ` ).
      ENDIF.

      APPEND ls_result TO rt_result.
    ENDLOOP.
  ENDMETHOD.


  METHOD tag.
    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.
    rv_xml = |<{ iv_name }>{ escape( val = iv_value format = cl_abap_format=>e_xml_text ) }</{ iv_name }>|.
  ENDMETHOD.


  METHOD to_iso_date.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_date = |{ iv_date(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }|.
  ENDMETHOD.


  METHOD format_amount.
    " Số tiền upload: 1234 / 1234,56 -> API: -1234.56 (dòng Có - H là số âm)
    DATA(lv_amount) = zcl_dntt_excel_upload=>to_amount( iv_value ).
    lv_amount = - abs( lv_amount ).
    rv_text = |{ lv_amount STYLE = SIMPLE }|.
  ENDMETHOD.


  METHOD error_for_all.
    rt_result = VALUE #( FOR ls_head IN it_head
                         ( document_sequence_no = ls_head-document_sequence_no
                           technical_error      = iv_technical
                           message              = iv_message ) ).
  ENDMETHOD.

ENDCLASS.

