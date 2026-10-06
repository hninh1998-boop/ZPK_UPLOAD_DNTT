"! Virtual element cho ZC_UP_DNTT_HEAD: BankAccount / Bank / AccountHolder
"! lấy từ ngân hàng của Supplier theo Partner Bank Type (BP bank details)
CLASS zcl_dntt_bank_calc DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_data,
        supplier        TYPE c LENGTH 10,
        partnerbanktype TYPE c LENGTH 4,
        bankaccount     TYPE c LENGTH 18,
        bank            TYPE c LENGTH 60,
        accountholder   TYPE c LENGTH 60,
      END OF ty_data,
      tt_data TYPE STANDARD TABLE OF ty_data WITH EMPTY KEY.
ENDCLASS.



CLASS zcl_dntt_bank_calc IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    LOOP AT it_requested_calc_elements INTO DATA(lv_element).
      CASE lv_element.
        WHEN 'BANKACCOUNT' OR 'BANK' OR 'ACCOUNTHOLDER'.
          INSERT `SUPPLIER`        INTO TABLE et_requested_orig_elements.
          INSERT `PARTNERBANKTYPE` INTO TABLE et_requested_orig_elements.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_data TYPE tt_data.
    DATA lr_supplier TYPE RANGE OF ty_data-supplier.

    lt_data = CORRESPONDING #( it_original_data ).

    lr_supplier = VALUE #( FOR ls_d IN lt_data WHERE ( supplier IS NOT INITIAL )
                           ( sign = 'I' option = 'EQ' low = ls_d-supplier ) ).
    SORT lr_supplier BY low.
    DELETE ADJACENT DUPLICATES FROM lr_supplier COMPARING low.

    IF lr_supplier IS NOT INITIAL.
      SELECT FROM I_BusinessPartnerSupplier AS supplier
             INNER JOIN I_BusinessPartnerBank AS bank
               ON bank~BusinessPartner = supplier~BusinessPartner
        FIELDS supplier~Supplier,
               bank~BankIdentification,
               bank~BankAccount,
               bank~BankName,
               bank~BankAccountHolderName
        WHERE supplier~Supplier IN @lr_supplier
        INTO TABLE @DATA(lt_bank).
    ENDIF.

    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      READ TABLE lt_bank INTO DATA(ls_bank)
           WITH KEY Supplier           = <ls_data>-supplier
                    BankIdentification = <ls_data>-partnerbanktype.
      IF sy-subrc = 0.
        <ls_data>-bankaccount   = ls_bank-BankAccount.
        <ls_data>-bank          = ls_bank-BankName.
        <ls_data>-accountholder = ls_bank-BankAccountHolderName.
      ENDIF.
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_data ).
  ENDMETHOD.

ENDCLASS.

