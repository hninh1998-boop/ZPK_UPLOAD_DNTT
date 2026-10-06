@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Upload DNTT - Header'
@Metadata.allowExtensions: true
define root view entity ZC_UP_DNTT_HEAD
  provider contract transactional_query
  as projection on ZI_UP_DNTT_HEAD
{
  key     DocumentSequenceNo,
          CompanyCode,
          JeType,
          PostingDate,
          PostingDateConv,
          Currency,
          HeaderText,
          Supplier,
          PaymentMethod,
          PartnerBankType,
          ProfitCenter,
          DueOn,
          TrgSpecGlInd,
          TotalAmount,
          TotalTax,
          Status,
          StatusCriticality,
          DocumentNumber,
          Message,
          CreatedOn,
          CreatedBy,
          CreatedAt,
          LastChangedBy,
          LastChangedAt,
          LocalLastChangedAt,
          _Item : redirected to composition child ZC_UP_DNTT_ITEM,

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DNTT_BANK_CALC'
  virtual BankAccount   : abap.char(18),
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DNTT_BANK_CALC'
  virtual Bank          : abap.char(60),
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DNTT_BANK_CALC'
  virtual AccountHolder : abap.char(60)
}
