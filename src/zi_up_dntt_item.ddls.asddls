@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Upload DNTT - Item'
define view entity ZI_UP_DNTT_ITEM
  as select from ztb_up_dntt_item
  association to parent ZI_UP_DNTT_HEAD as _Head on $projection.DocumentSequenceNo = _Head.DocumentSequenceNo
{
  key document_sequence_no as DocumentSequenceNo,
  key item                 as Item,
      trg_spec_gl_ind      as TrgSpecGlInd,
      assignment           as Assignment,
      item_text            as ItemText,
      amount               as Amount,
      reference_key_2      as ReferenceKey2,
      _Head
}
