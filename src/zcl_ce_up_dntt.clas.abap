CLASS zcl_ce_up_dntt DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ce_up_dntt IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    zcl_ce_up_dntt_f01=>requested(
      EXPORTING
        io_request = io_request
      IMPORTING
        et_filters = DATA(lt_filters)
    ).

    zcl_ce_up_dntt_f01=>main(
      EXPORTING
        it_filters = lt_filters
      IMPORTING
        et_result  = DATA(lt_result)
    ).

    zcl_ce_up_dntt_f01=>response(
      EXPORTING
        io_request  = io_request
        io_response = io_response
      CHANGING
        ct_result   = lt_result
    ).
  ENDMETHOD.
ENDCLASS.
