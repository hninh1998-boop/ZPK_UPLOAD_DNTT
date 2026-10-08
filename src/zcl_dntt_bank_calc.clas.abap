"! Thông tin Supplier hiển thị trên Upload DNTT (màn hình chi tiết ZC_UP_DNTT_HEAD - virtual element,
"! và màn hình danh sách ZCE_UP_DNTT):
"! - BankAccount / Bank / AccountHolder: ngân hàng của Supplier theo Partner Bank Type (BP bank details),
"!   cùng logic với "Số tài khoản" / "Ngân hàng - Chi nhánh" / "Chủ tài khoản" của ZI_BP_BANK_ACCOUNT
"! - SupplierName: tên BP của Supplier, cùng logic với field "Tên NCC" của ZI_BP_BANK_ACCOUNT
CLASS zcl_dntt_bank_calc DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

    TYPES:
      BEGIN OF ty_data,
        supplier        TYPE c LENGTH 10,
        partnerbanktype TYPE c LENGTH 4,
        bankaccount     TYPE c LENGTH 40,
        bank            TYPE c LENGTH 110,
        accountholder   TYPE c LENGTH 110,
        suppliername    TYPE c LENGTH 130,
      END OF ty_data,
      tt_data TYPE STANDARD TABLE OF ty_data WITH EMPTY KEY.

    "! Điền bankaccount / bank / accountholder / suppliername theo supplier + partnerbanktype của từng dòng
    CLASS-METHODS fill
      CHANGING ct_data TYPE tt_data.
ENDCLASS.



CLASS zcl_dntt_bank_calc IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    LOOP AT it_requested_calc_elements INTO DATA(lv_element).
      CASE lv_element.
        WHEN 'BANKACCOUNT' OR 'BANK' OR 'ACCOUNTHOLDER'.
          INSERT `SUPPLIER`        INTO TABLE et_requested_orig_elements.
          INSERT `PARTNERBANKTYPE` INTO TABLE et_requested_orig_elements.
        WHEN 'SUPPLIERNAME'.
          INSERT `SUPPLIER`        INTO TABLE et_requested_orig_elements.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_data TYPE tt_data.

    lt_data = CORRESPONDING #( it_original_data ).
    fill( CHANGING ct_data = lt_data ).
    ct_calculated_data = CORRESPONDING #( lt_data ).
  ENDMETHOD.


  METHOD fill.
    DATA lr_supplier TYPE RANGE OF ty_data-supplier.

    lr_supplier = VALUE #( FOR ls_d IN ct_data WHERE ( supplier IS NOT INITIAL )
                           ( sign = 'I' option = 'EQ' low = ls_d-supplier ) ).
    SORT lr_supplier BY low.
    DELETE ADJACENT DUPLICATES FROM lr_supplier COMPARING low.

    IF lr_supplier IS NOT INITIAL.
      SELECT FROM I_BusinessPartnerSupplier AS supplier
             INNER JOIN I_BusinessPartnerBank AS bank
               ON bank~BusinessPartner = supplier~BusinessPartner
             LEFT OUTER JOIN I_BankVH AS branch
               ON  branch~BankCountry    = bank~BankCountryKey
               AND branch~BankInternalID = bank~BankNumber
        FIELDS supplier~Supplier,
               bank~BankIdentification,
               bank~BankAccount,
               bank~BusinessPartnerExternalBankID,
               bank~BankName,
               branch~LongBankBranch,
               bank~BankAccountHolderName,
               bank~BankAccountName
        WHERE supplier~Supplier IN @lr_supplier
        INTO TABLE @DATA(lt_bank).

      SELECT FROM I_BusinessPartnerSupplier AS supplier
             INNER JOIN I_BusinessPartner AS bp
               ON bp~BusinessPartner = supplier~BusinessPartner
        FIELDS supplier~Supplier,
               bp~OrganizationBPName1,
               bp~OrganizationBPName2,
               bp~OrganizationBPName3,
               bp~OrganizationBPName4,
               bp~LastName
        WHERE supplier~Supplier IN @lr_supplier
        INTO TABLE @DATA(lt_name).
    ENDIF.

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      CLEAR: <ls_data>-bankaccount, <ls_data>-bank, <ls_data>-accountholder, <ls_data>-suppliername.

      READ TABLE lt_bank INTO DATA(ls_bank)
           WITH KEY Supplier           = <ls_data>-supplier
                    BankIdentification = <ls_data>-partnerbanktype.
      IF sy-subrc = 0.
        " Số tài khoản = BankAccount + BusinessPartnerExternalBankID (viết liền)
        <ls_data>-bankaccount   = |{ ls_bank-BankAccount }{ ls_bank-BusinessPartnerExternalBankID }|.
        " Ngân hàng - Chi nhánh = BankName, có chi nhánh thì thêm " - LongBankBranch"
        <ls_data>-bank          = COND #( WHEN ls_bank-LongBankBranch IS INITIAL
                                          THEN ls_bank-BankName
                                          ELSE |{ ls_bank-BankName } - { ls_bank-LongBankBranch }| ).
        " Chủ tài khoản = BankAccountHolderName + dấu cách + BankAccountName
        <ls_data>-accountholder = COND #( WHEN ls_bank-BankAccountName IS INITIAL
                                          THEN ls_bank-BankAccountHolderName
                                          WHEN ls_bank-BankAccountHolderName IS INITIAL
                                          THEN ls_bank-BankAccountName
                                          ELSE |{ ls_bank-BankAccountHolderName } { ls_bank-BankAccountName }| ).
      ENDIF.

      " Giống "Tên NCC" của ZI_BP_BANK_ACCOUNT: có Name 2/3/4 -> ghép Name 2 3 4,
      " không thì Last name, không nữa thì Name 1
      READ TABLE lt_name INTO DATA(ls_name) WITH KEY Supplier = <ls_data>-supplier.
      IF sy-subrc = 0.
        <ls_data>-suppliername =
          COND #( WHEN ls_name-OrganizationBPName2 IS NOT INITIAL
                    OR ls_name-OrganizationBPName3 IS NOT INITIAL
                    OR ls_name-OrganizationBPName4 IS NOT INITIAL
                  THEN condense( |{ ls_name-OrganizationBPName2 } { ls_name-OrganizationBPName3 } | &&
                                 |{ ls_name-OrganizationBPName4 }| )
                  WHEN ls_name-LastName IS NOT INITIAL
                  THEN ls_name-LastName
                  ELSE ls_name-OrganizationBPName1 ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

