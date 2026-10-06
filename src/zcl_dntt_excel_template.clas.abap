CLASS zcl_dntt_excel_template DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_column,
        col       TYPE string,    " Cột Excel
        field     TYPE string,    " Tên kỹ thuật (row 1 - ẩn)
        label     TYPE string,
        sub_label TYPE string,    " Dòng thứ 2 của header
        mandatory TYPE abap_bool,
        hint      TYPE string,
        length    TYPE i,         " Độ dài tối đa (0 = không kiểm tra, vd. cột ngày)
        is_detail TYPE abap_bool,
        width     TYPE string,
      END OF ty_column,
      tt_column TYPE STANDARD TABLE OF ty_column WITH EMPTY KEY,
      BEGIN OF ty_ref,
        code      TYPE string,
        text      TYPE string,
        em_before TYPE string,    " Rich text: phần in nghiêng trước từ nhấn mạnh
        emphasis  TYPE string,    " Rich text: từ in đỏ đậm
        em_after  TYPE string,    " Rich text: phần in nghiêng sau từ nhấn mạnh
        note      TYPE string,
      END OF ty_ref,
      tt_ref TYPE STANDARD TABLE OF ty_ref WITH EMPTY KEY.

    CONSTANTS:
      c_file_name      TYPE string VALUE `Template_Upload_DNTT.xlsx`,
      c_mime_type      TYPE string VALUE `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`,
      c_sheet_data     TYPE string VALUE `Data`,
      c_sheet_ref      TYPE string VALUE `Reference`,
      c_first_data_row TYPE i VALUE 5,
      c_last_check_row TYPE i VALUE 1000.

    CLASS-METHODS get_columns
      RETURNING VALUE(rt_columns) TYPE tt_column.

    CLASS-METHODS get_je_types        RETURNING VALUE(rt_ref) TYPE tt_ref.
    CLASS-METHODS get_currencies      RETURNING VALUE(rt_ref) TYPE tt_ref.
    CLASS-METHODS get_payment_methods RETURNING VALUE(rt_ref) TYPE tt_ref.
    CLASS-METHODS get_trg_spec_gl     RETURNING VALUE(rt_ref) TYPE tt_ref.

    METHODS build
      RETURNING VALUE(rv_xlsx) TYPE xstring.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_style,
        normal       TYPE i VALUE 0,
        group_header TYPE i VALUE 1,
        group_detail TYPE i VALUE 2,
        col_header   TYPE i VALUE 3,
        col_detail   TYPE i VALUE 4,
        hint_header  TYPE i VALUE 5,
        hint_detail  TYPE i VALUE 6,
        text         TYPE i VALUE 7,
        ref_title    TYPE i VALUE 8,
        ref_code     TYPE i VALUE 9,
        ref_text     TYPE i VALUE 10,
      END OF c_style,
      c_xml_decl  TYPE string VALUE `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`,
      c_ns_main   TYPE string VALUE `http://schemas.openxmlformats.org/spreadsheetml/2006/main`,
      c_ns_rel    TYPE string VALUE `http://schemas.openxmlformats.org/officeDocument/2006/relationships`,
      c_ref_rows  TYPE i VALUE 9,  " Các bảng nhỏ ở sheet Reference kẻ ô tới row 9
      c_font_head TYPE string VALUE `Times New Roman`,
      c_font_ref  TYPE string VALUE `Courier New`,
      c_font_em   TYPE string VALUE `Calibri`,
      c_red       TYPE string VALUE `FFFF0000`.

    METHODS content_types  RETURNING VALUE(rv_xml) TYPE string.
    METHODS root_rels      RETURNING VALUE(rv_xml) TYPE string.
    METHODS workbook       RETURNING VALUE(rv_xml) TYPE string.
    METHODS workbook_rels  RETURNING VALUE(rv_xml) TYPE string.
    METHODS styles         RETURNING VALUE(rv_xml) TYPE string.
    METHODS sheet_data     RETURNING VALUE(rv_xml) TYPE string.
    METHODS sheet_reference RETURNING VALUE(rv_xml) TYPE string.

    METHODS cell_text
      IMPORTING iv_ref        TYPE string
                iv_style      TYPE i
                iv_text       TYPE string OPTIONAL
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS cell_rich
      IMPORTING iv_ref        TYPE string
                iv_style      TYPE i
                iv_runs       TYPE string
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS run
      IMPORTING iv_text       TYPE string
                iv_font       TYPE string
                iv_size       TYPE i
                iv_bold       TYPE abap_bool DEFAULT abap_false
                iv_italic     TYPE abap_bool DEFAULT abap_false
                iv_color      TYPE string DEFAULT `FF000000`
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS list_validation
      IMPORTING iv_col        TYPE string
                iv_ref_col    TYPE string
                iv_count      TYPE i
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS to_xstring
      IMPORTING iv_xml          TYPE string
      RETURNING VALUE(rv_xstring) TYPE xstring.
ENDCLASS.



CLASS zcl_dntt_excel_template IMPLEMENTATION.

  METHOD get_columns.
    rt_columns = VALUE #(
      ( col = `A` field = `DocumentSequenceNo` label = `Document SequenceNo` mandatory = abap_true
        hint = |Mã nhóm (vd. A, B)\nHệ thống tự cấp số| length = 10 width = `14.7` )
      ( col = `B` field = `CompanyCode` label = `Company code` mandatory = abap_true
        hint = `4 ký tự` length = 4 width = `15.7` )
      ( col = `C` field = `JeType` label = `Journal Entry Type` mandatory = abap_true
        hint = `2 ký tự` length = 2 width = `13` )
      ( col = `D` field = `PostingDate` label = `Posting date` mandatory = abap_true
        hint = `dd/mm/yyyy` width = `14.7` )
      ( col = `E` field = `Currency` label = `Currency` mandatory = abap_true
        hint = `3 ký tự` length = 3 width = `13.7` )
      ( col = `F` field = `HeaderText` label = `Header Text`
        hint = `25 ký tự` length = 25 width = `13.7` )
      ( col = `G` field = `Supplier` label = `Supplier` mandatory = abap_true
        hint = `10 ký tự` length = 10 width = `17` )
      ( col = `H` field = `PaymentMethod` label = `Payment Method` mandatory = abap_true
        hint = `1 ký tự` length = 1 width = `10.7` )
      ( col = `I` field = `PartnerBankType` label = `Partner Bank Type`
        hint = `4 ký tự` length = 4 width = `14.4` )
      ( col = `J` field = `ProfitCenter` label = `Profit Center` mandatory = abap_true
        hint = `6 ký tự` length = 6 width = `16.7` )
      ( col = `K` field = `DueOn` label = `Due On` mandatory = abap_true
        hint = `dd/mm/yyyy` width = `17.9` )
      ( col = `L` field = `TrgSpecGlInd` label = `Trg. Spec. G/L Ind` mandatory = abap_true
        hint = `1 ký tự` length = 1 is_detail = abap_true width = `15.3` )
      ( col = `M` field = `Assignment` label = `Assignment` sub_label = `(Bill/Hóa đơn/Hợp đồng/…)`
        hint = `18 ký tự` length = 18 is_detail = abap_true width = `26.4` )
      ( col = `N` field = `ItemText` label = `Item Text` sub_label = `(Diễn giải)`
        hint = `50 ký tự` length = 50 is_detail = abap_true width = `29.6` )
      ( col = `O` field = `Amount` label = `Amount` sub_label = `(Tiền thanh toán)` mandatory = abap_true
        hint = `14 ký tự` length = 14 is_detail = abap_true width = `20.9` )
      ( col = `P` field = `ReferenceKey2` label = `Reference Key 2` sub_label = `(Tiền thuế)`
        hint = |12 ký tự\nChỉ nhập số và dấu ,| length = 12 is_detail = abap_true width = `22.9` ) ).
  ENDMETHOD.


  METHOD get_je_types.
    rt_ref = VALUE #(
      ( code = `A1` text = `KHGC` )
      ( code = `A2` text = `HCNS VPHN` )
      ( code = `A3` text = `HCNS nhà máy` )
      ( code = `A4` text = `KHSX,R&D,QAQC,PC-DA` )
      ( code = `A5` text = `Kinh doanh` )
      ( code = `A6` text = `Mua hàng` )
      ( code = `A7` text = `Kế toán` )
      ( code = `A8` text = `Kiểm soát nội bộ` ) ).
  ENDMETHOD.


  METHOD get_currencies.
    rt_ref = VALUE #(
      ( code = `VND` )
      ( code = `USD` )
      ( code = `GBP` )
      ( code = `EUR` ) ).
  ENDMETHOD.


  METHOD get_payment_methods.
    rt_ref = VALUE #(
      ( code = `1` text = `Tiền mặt` )
      ( code = `2` text = `Chuyển khoản` )
      ( code = `3` text = `Bù trừ công nợ` ) ).
  ENDMETHOD.


  METHOD get_trg_spec_gl.
    rt_ref = VALUE #(
      ( code = `A` text = `Đề nghị đặt cọc/trả trước NCC chưa có hóa đơn (3312)` )
      ( code = `A` text = `Đề nghị thanh toán các khoản thuế (thuế nhập khẩu; thuế môn bài, thuế đất, thuế GTGT…) (3388)` )
      ( code = `A` text = `Đề nghị thanh toán lương (334)` )
      ( code = `A` text = `Đề nghị thanh toán kinh phí công đoàn (3382)` )
      ( code = `B` text = `Đề nghị thanh toán các khoản chi đã có hóa đơn (3311)` )
      ( code = `M` text = `Đề nghị tạm ứng cho nhân viên (141)` )
      ( code = `I` text = `Đề nghị thanh toán Bảo hiểm xã hội` )
      ( code = `J` text = `Đề nghị thanh toán Bảo hiểm y tế` )
      ( code = `K` text = `Đề nghị thanh toán bảo hiểm thất nghiệp` )
      ( code = `L` text = `Đề nghị  thanh toán các loại phí theo mẫu ` em_before = `(TH ` emphasis = `chưa`
        em_after = ` có hóa đơn): Tên công ty_MST_ Nội dung TT [Số bill]` note = `Áp dụng phòng mua` )
      ( code = `O` text = `Đề nghị  thanh toán các loại phí theo mẫu ` em_before = `(TH ` emphasis = `Đã`
        em_after = ` có hóa đơn): Tên công ty_MST_ Nội dung TT [Số bill]` note = `Áp dụng phòng mua` ) ).
  ENDMETHOD.


  METHOD build.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = `[Content_Types].xml`        content = to_xstring( content_types( ) ) ).
    lo_zip->add( name = `_rels/.rels`                content = to_xstring( root_rels( ) ) ).
    lo_zip->add( name = `xl/workbook.xml`            content = to_xstring( workbook( ) ) ).
    lo_zip->add( name = `xl/_rels/workbook.xml.rels` content = to_xstring( workbook_rels( ) ) ).
    lo_zip->add( name = `xl/styles.xml`              content = to_xstring( styles( ) ) ).
    lo_zip->add( name = `xl/worksheets/sheet1.xml`   content = to_xstring( sheet_data( ) ) ).
    lo_zip->add( name = `xl/worksheets/sheet2.xml`   content = to_xstring( sheet_reference( ) ) ).
    rv_xlsx = lo_zip->save( ).
  ENDMETHOD.


  METHOD content_types.
    DATA(lv_ct) = `application/vnd.openxmlformats-officedocument.spreadsheetml`.
    rv_xml = c_xml_decl
      && `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">`
      && `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>`
      && `<Default Extension="xml" ContentType="application/xml"/>`
      && |<Override PartName="/xl/workbook.xml" ContentType="{ lv_ct }.sheet.main+xml"/>|
      && |<Override PartName="/xl/worksheets/sheet1.xml" ContentType="{ lv_ct }.worksheet+xml"/>|
      && |<Override PartName="/xl/worksheets/sheet2.xml" ContentType="{ lv_ct }.worksheet+xml"/>|
      && |<Override PartName="/xl/styles.xml" ContentType="{ lv_ct }.styles+xml"/>|
      && `</Types>`.
  ENDMETHOD.


  METHOD root_rels.
    rv_xml = c_xml_decl
      && `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`
      && |<Relationship Id="rId1" Type="{ c_ns_rel }/officeDocument" Target="xl/workbook.xml"/>|
      && `</Relationships>`.
  ENDMETHOD.


  METHOD workbook.
    rv_xml = c_xml_decl
      && |<workbook xmlns="{ c_ns_main }" xmlns:r="{ c_ns_rel }">|
      && `<bookViews><workbookView activeTab="0"/></bookViews>`
      && `<sheets>`
      && |<sheet name="{ c_sheet_data }" sheetId="1" r:id="rId1"/>|
      && |<sheet name="{ c_sheet_ref }" sheetId="2" r:id="rId2"/>|
      && `</sheets>`
      && `</workbook>`.
  ENDMETHOD.


  METHOD workbook_rels.
    rv_xml = c_xml_decl
      && `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`
      && |<Relationship Id="rId1" Type="{ c_ns_rel }/worksheet" Target="worksheets/sheet1.xml"/>|
      && |<Relationship Id="rId2" Type="{ c_ns_rel }/worksheet" Target="worksheets/sheet2.xml"/>|
      && |<Relationship Id="rId3" Type="{ c_ns_rel }/styles" Target="styles.xml"/>|
      && `</Relationships>`.
  ENDMETHOD.


  METHOD styles.
    DATA(lv_center)    = `<alignment horizontal="center" vertical="center"/>`.
    DATA(lv_center_wr) = `<alignment horizontal="center" vertical="center" wrapText="1"/>`.
    DATA(lv_left)      = `<alignment horizontal="left" vertical="center"/>`.
    DATA(lv_apply)     = `applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"`.

    rv_xml = c_xml_decl
      && |<styleSheet xmlns="{ c_ns_main }">|
      " Fonts: 0 Calibri | 1 Header (TNR bold) | 2 Hint (TNR italic) | 3 Reference | 4 Reference bold
      && `<fonts count="5">`
      && `<font><sz val="11"/><color rgb="FF000000"/><name val="Calibri"/><family val="2"/></font>`
      && |<font><b/><sz val="11"/><color rgb="FF000000"/><name val="{ c_font_head }"/><family val="1"/></font>|
      && |<font><i/><sz val="10"/><color rgb="FF000000"/><name val="{ c_font_head }"/><family val="1"/></font>|
      && |<font><sz val="9"/><color rgb="FF000000"/><name val="{ c_font_ref }"/><family val="3"/></font>|
      && |<font><b/><sz val="9"/><color rgb="FF000000"/><name val="{ c_font_ref }"/><family val="3"/></font>|
      && `</fonts>`
      " Fills: 2 vàng (Header) | 3 hồng (Detail / mã) | 4 xám (tiêu đề Reference)
      && `<fills count="5">`
      && `<fill><patternFill patternType="none"/></fill>`
      && `<fill><patternFill patternType="gray125"/></fill>`
      && `<fill><patternFill patternType="solid"><fgColor rgb="FFFFF2CC"/><bgColor indexed="64"/></patternFill></fill>`
      && `<fill><patternFill patternType="solid"><fgColor rgb="FFFCE4D6"/><bgColor indexed="64"/></patternFill></fill>`
      && `<fill><patternFill patternType="solid"><fgColor rgb="FFD9D9D9"/><bgColor indexed="64"/></patternFill></fill>`
      && `</fills>`
      && `<borders count="2">`
      && `<border><left/><right/><top/><bottom/><diagonal/></border>`
      && `<border><left style="thin"><color auto="1"/></left><right style="thin"><color auto="1"/></right>`
      && `<top style="thin"><color auto="1"/></top><bottom style="thin"><color auto="1"/></bottom><diagonal/></border>`
      && `</borders>`
      && `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>`
      && `<cellXfs count="11">`
      && `<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>`
      && |<xf numFmtId="0" fontId="3" fillId="2" borderId="1" xfId="0" { lv_apply }>{ lv_center }</xf>|
      && |<xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" { lv_apply }>{ lv_center }</xf>|
      && |<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" { lv_apply }>{ lv_center_wr }</xf>|
      && |<xf numFmtId="0" fontId="1" fillId="3" borderId="1" xfId="0" { lv_apply }>{ lv_center_wr }</xf>|
      && |<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" { lv_apply }>{ lv_center_wr }</xf>|
      && |<xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" { lv_apply }>{ lv_center_wr }</xf>|
      " 7: định dạng Text (@) cho vùng nhập liệu -> giữ số 0 đầu, ngày dạng chuỗi dd/mm/yyyy
      && `<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>`
      && |<xf numFmtId="0" fontId="4" fillId="4" borderId="1" xfId="0" { lv_apply }>{ lv_left }</xf>|
      && |<xf numFmtId="49" fontId="3" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" { lv_apply }>{ lv_center }</xf>|
      && |<xf numFmtId="49" fontId="3" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" { lv_apply }>{ lv_left }</xf>|
      && `</cellXfs>`
      && `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>`
      && `</styleSheet>`.
  ENDMETHOD.


  METHOD sheet_data.
    DATA: lv_cols         TYPE string,
          lv_row1         TYPE string,
          lv_row2         TYPE string,
          lv_row3         TYPE string,
          lv_row4         TYPE string,
          lv_last_head    TYPE string,
          lv_first_detail TYPE string.

    DATA(lt_columns) = get_columns( ).
    DATA(lv_last_col) = lt_columns[ lines( lt_columns ) ]-col.

    LOOP AT lt_columns INTO DATA(ls_col).
      DATA(lv_idx) = sy-tabix.

      IF ls_col-is_detail = abap_false.
        lv_last_head = ls_col-col.
      ELSEIF lv_first_detail IS INITIAL.
        lv_first_detail = ls_col-col.
      ENDIF.

      lv_cols &&= |<col min="{ lv_idx }" max="{ lv_idx }" width="{ ls_col-width }" style="{ c_style-text }" customWidth="1"/>|.

      " Row 1 (ẩn): tên kỹ thuật - dùng để map cột khi upload
      lv_row1 &&= cell_text( iv_ref = |{ ls_col-col }1| iv_style = c_style-text iv_text = ls_col-field ).

      " Row 2: nhóm Header / Detail
      lv_row2 &&= cell_text(
        iv_ref   = |{ ls_col-col }2|
        iv_style = COND #( WHEN ls_col-is_detail = abap_true THEN c_style-group_detail ELSE c_style-group_header )
        iv_text  = COND #( WHEN lv_idx = 1 THEN `Header`
                           WHEN ls_col-col = lv_first_detail THEN `Detail` ) ).

      " Row 3: tên cột (+ * đỏ cho trường bắt buộc)
      DATA(lv_runs) = run( iv_text = ls_col-label iv_font = c_font_head iv_size = 11 iv_bold = abap_true ).
      IF ls_col-mandatory = abap_true.
        lv_runs &&= run( iv_text = `*` iv_font = c_font_head iv_size = 11 iv_color = c_red ).
      ENDIF.
      IF ls_col-sub_label IS NOT INITIAL.
        lv_runs &&= run( iv_text = |\n{ ls_col-sub_label }| iv_font = c_font_head iv_size = 11 iv_bold = abap_true ).
      ENDIF.
      lv_row3 &&= cell_rich(
        iv_ref   = |{ ls_col-col }3|
        iv_style = COND #( WHEN ls_col-is_detail = abap_true THEN c_style-col_detail ELSE c_style-col_header )
        iv_runs  = lv_runs ).

      " Row 4: gợi ý độ dài / định dạng
      lv_row4 &&= cell_text(
        iv_ref   = |{ ls_col-col }4|
        iv_style = COND #( WHEN ls_col-is_detail = abap_true THEN c_style-hint_detail ELSE c_style-hint_header )
        iv_text  = ls_col-hint ).
    ENDLOOP.

    rv_xml = c_xml_decl
      && |<worksheet xmlns="{ c_ns_main }" xmlns:r="{ c_ns_rel }">|
      && `<sheetViews><sheetView tabSelected="1" workbookViewId="0">`
      && `<pane xSplit="1" ySplit="4" topLeftCell="B5" activePane="bottomRight" state="frozen"/>`
      && `<selection pane="topRight"/><selection pane="bottomLeft"/>`
      && `<selection pane="bottomRight" activeCell="B5" sqref="B5"/>`
      && `</sheetView></sheetViews>`
      && `<sheetFormatPr defaultRowHeight="15"/>`
      && |<cols>{ lv_cols }</cols>|
      && `<sheetData>`
      && |<row r="1" hidden="1">{ lv_row1 }</row>|
      && |<row r="2" ht="15" customHeight="1">{ lv_row2 }</row>|
      && |<row r="3" ht="33" customHeight="1">{ lv_row3 }</row>|
      && |<row r="4" ht="27" customHeight="1">{ lv_row4 }</row>|
      && `</sheetData>`
      && `<mergeCells count="2">`
      && |<mergeCell ref="A2:{ lv_last_head }2"/>|
      && |<mergeCell ref="{ lv_first_detail }2:{ lv_last_col }2"/>|
      && `</mergeCells>`
      " Dropdown lấy từ sheet Reference
      && `<dataValidations count="4">`
      && list_validation( iv_col     = lt_columns[ field = `JeType` ]-col
                          iv_ref_col = `A`
                          iv_count   = lines( get_je_types( ) ) )
      && list_validation( iv_col     = lt_columns[ field = `Currency` ]-col
                          iv_ref_col = `D`
                          iv_count   = lines( get_currencies( ) ) )
      && list_validation( iv_col     = lt_columns[ field = `PaymentMethod` ]-col
                          iv_ref_col = `F`
                          iv_count   = lines( get_payment_methods( ) ) )
      && list_validation( iv_col     = lt_columns[ field = `TrgSpecGlInd` ]-col
                          iv_ref_col = `I`
                          iv_count   = lines( get_trg_spec_gl( ) ) )
      && `</dataValidations>`
      && `<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>`
      && `</worksheet>`.
  ENDMETHOD.


  METHOD sheet_reference.
    DATA lv_rows TYPE string.

    DATA(lt_je)  = get_je_types( ).
    DATA(lt_cur) = get_currencies( ).
    DATA(lt_pay) = get_payment_methods( ).
    DATA(lt_trg) = get_trg_spec_gl( ).

    " JE Type / Currency / Payment Method: kẻ ô sẵn tới row c_ref_rows (hoặc hơn nếu nhiều dữ liệu)
    DATA(lv_small_last) = nmax( val1 = c_ref_rows
                                val2 = 1 + lines( lt_je )
                                val3 = 1 + lines( lt_cur )
                                val4 = 1 + lines( lt_pay ) ).
    DATA(lv_trg_last)  = 1 + lines( lt_trg ).
    DATA(lv_last_row)  = nmax( val1 = lv_small_last val2 = lv_trg_last ).

    DO lv_last_row TIMES.
      DATA(lv_r) = sy-index.
      DATA(lv_cells) = ``.

      IF lv_r = 1.
        lv_cells = cell_text( iv_ref = `A1` iv_style = c_style-ref_title iv_text = `JE Type` )
                && cell_text( iv_ref = `B1` iv_style = c_style-ref_title )
                && cell_text( iv_ref = `D1` iv_style = c_style-ref_title iv_text = `Currency` )
                && cell_text( iv_ref = `F1` iv_style = c_style-ref_title iv_text = `Payment Method` )
                && cell_text( iv_ref = `G1` iv_style = c_style-ref_title )
                && cell_text( iv_ref = `I1` iv_style = c_style-ref_title iv_text = `Trg. Spec. G/L Ind` )
                && cell_text( iv_ref = `J1` iv_style = c_style-ref_title )
                && cell_text( iv_ref = `K1` iv_style = c_style-ref_title ).
      ELSE.
        DATA(lv_i) = lv_r - 1.

        IF lv_r <= lv_small_last.
          DATA(ls_je)  = VALUE ty_ref( lt_je[ lv_i ] OPTIONAL ).
          DATA(ls_cur) = VALUE ty_ref( lt_cur[ lv_i ] OPTIONAL ).
          DATA(ls_pay) = VALUE ty_ref( lt_pay[ lv_i ] OPTIONAL ).
          lv_cells = cell_text( iv_ref = |A{ lv_r }| iv_style = c_style-ref_code iv_text = ls_je-code )
                  && cell_text( iv_ref = |B{ lv_r }| iv_style = c_style-ref_text iv_text = ls_je-text )
                  && cell_text( iv_ref = |D{ lv_r }| iv_style = c_style-ref_code iv_text = ls_cur-code )
                  && cell_text( iv_ref = |F{ lv_r }| iv_style = c_style-ref_code iv_text = ls_pay-code )
                  && cell_text( iv_ref = |G{ lv_r }| iv_style = c_style-ref_text iv_text = ls_pay-text ).
        ENDIF.

        IF lv_r <= lv_trg_last.
          DATA(ls_trg) = lt_trg[ lv_i ].
          lv_cells &&= cell_text( iv_ref = |I{ lv_r }| iv_style = c_style-ref_code iv_text = ls_trg-code ).

          IF ls_trg-emphasis IS INITIAL.
            lv_cells &&= cell_text( iv_ref = |J{ lv_r }| iv_style = c_style-ref_text iv_text = ls_trg-text ).
          ELSE.
            lv_cells &&= cell_rich(
              iv_ref   = |J{ lv_r }|
              iv_style = c_style-ref_text
              iv_runs  = run( iv_text = ls_trg-text iv_font = c_font_ref iv_size = 9 )
                      && run( iv_text = ls_trg-em_before iv_font = c_font_em iv_size = 10 iv_italic = abap_true )
                      && run( iv_text = ls_trg-emphasis iv_font = c_font_em iv_size = 10
                              iv_bold = abap_true iv_italic = abap_true iv_color = c_red )
                      && run( iv_text = ls_trg-em_after iv_font = c_font_em iv_size = 10 iv_italic = abap_true ) ).
          ENDIF.

          lv_cells &&= cell_text( iv_ref = |K{ lv_r }| iv_style = c_style-ref_text iv_text = ls_trg-note ).
        ENDIF.
      ENDIF.

      lv_rows &&= |<row r="{ lv_r }">{ lv_cells }</row>|.
    ENDDO.

    rv_xml = c_xml_decl
      && |<worksheet xmlns="{ c_ns_main }" xmlns:r="{ c_ns_rel }">|
      && `<sheetViews><sheetView workbookViewId="0"/></sheetViews>`
      && `<sheetFormatPr defaultRowHeight="15"/>`
      && `<cols>`
      && `<col min="1" max="1" width="8.7" customWidth="1"/>`
      && `<col min="2" max="2" width="31.7" customWidth="1"/>`
      && `<col min="4" max="4" width="11" customWidth="1"/>`
      && `<col min="6" max="6" width="8.7" customWidth="1"/>`
      && `<col min="7" max="7" width="31.7" customWidth="1"/>`
      && `<col min="9" max="9" width="8.7" customWidth="1"/>`
      && `<col min="10" max="10" width="103" customWidth="1"/>`
      && `<col min="11" max="11" width="19.7" customWidth="1"/>`
      && `</cols>`
      && |<sheetData>{ lv_rows }</sheetData>|
      && `<mergeCells count="3">`
      && `<mergeCell ref="A1:B1"/><mergeCell ref="F1:G1"/><mergeCell ref="I1:K1"/>`
      && `</mergeCells>`
      && `<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>`
      && `</worksheet>`.
  ENDMETHOD.


  METHOD cell_text.
    IF iv_text IS INITIAL.
      rv_xml = |<c r="{ iv_ref }" s="{ iv_style }"/>|.
    ELSE.
      rv_xml = |<c r="{ iv_ref }" s="{ iv_style }" t="inlineStr"><is><t xml:space="preserve">|
            && escape( val = iv_text format = cl_abap_format=>e_xml_text )
            && `</t></is></c>`.
    ENDIF.
  ENDMETHOD.


  METHOD cell_rich.
    rv_xml = |<c r="{ iv_ref }" s="{ iv_style }" t="inlineStr"><is>{ iv_runs }</is></c>|.
  ENDMETHOD.


  METHOD run.
    rv_xml = `<r><rPr>`
          && COND #( WHEN iv_bold = abap_true THEN `<b/>` ELSE `` )
          && COND #( WHEN iv_italic = abap_true THEN `<i/>` ELSE `` )
          && |<sz val="{ iv_size }"/><color rgb="{ iv_color }"/><rFont val="{ iv_font }"/></rPr>|
          && `<t xml:space="preserve">`
          && escape( val = iv_text format = cl_abap_format=>e_xml_text )
          && `</t></r>`.
  ENDMETHOD.


  METHOD list_validation.
    rv_xml = |<dataValidation type="list" allowBlank="1" showErrorMessage="1" |
          && |sqref="{ iv_col }{ c_first_data_row }:{ iv_col }{ c_last_check_row }">|
          && |<formula1>{ c_sheet_ref }!${ iv_ref_col }$2:${ iv_ref_col }${ 1 + iv_count }</formula1>|
          && `</dataValidation>`.
  ENDMETHOD.


  METHOD to_xstring.
    rv_xstring = cl_abap_conv_codepage=>create_out( )->convert( iv_xml ).
  ENDMETHOD.

ENDCLASS.

