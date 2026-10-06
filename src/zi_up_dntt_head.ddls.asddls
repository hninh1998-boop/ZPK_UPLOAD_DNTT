@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Upload DNTT - Header'
define root view entity ZI_UP_DNTT_HEAD
  as select from ztb_up_dntt_head
  composition [0..*] of ZI_UP_DNTT_ITEM as _Item
{
  key document_sequence_no  as DocumentSequenceNo,
      company_code          as CompanyCode,
      je_type               as JeType,
      posting_date          as PostingDate,
      posting_date_conv     as PostingDateConv,
      currency              as Currency,
      header_text           as HeaderText,
      supplier              as Supplier,
      payment_method        as PaymentMethod,
      partner_bank_type     as PartnerBankType,
      profit_center         as ProfitCenter,
      due_on                as DueOn,
      trg_spec_gl_ind       as TrgSpecGlInd,
      total_amount          as TotalAmount,
      total_tax             as TotalTax,
      status                as Status,
      // Status lưu dạng Draft / Checked / Error / Posted -> so sánh chữ hoa
      case upper( status )
        when 'POSTED'  then 3
        when 'CHECKED' then 5
        when 'ERROR'   then 1
        else 0
      end                   as StatusCriticality,
      document_number       as DocumentNumber,
      message               as Message,
      created_on            as CreatedOn,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Item
}
