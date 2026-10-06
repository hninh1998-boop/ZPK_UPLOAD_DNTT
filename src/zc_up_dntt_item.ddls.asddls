@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Upload DNTT - Item'
@Metadata.allowExtensions: true
define view entity ZC_UP_DNTT_ITEM
  as projection on ZI_UP_DNTT_ITEM
{
  key DocumentSequenceNo,
  key Item,
      TrgSpecGlInd,
      Assignment,
      ItemText,
      Amount,
      ReferenceKey2,
      _Head : redirected to parent ZC_UP_DNTT_HEAD
}
