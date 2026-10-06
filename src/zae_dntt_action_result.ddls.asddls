@EndUserText.label: 'Upload DNTT - Action result'
define abstract entity ZAE_DNTT_ACTION_RESULT
{
  SuccessCount : abap.int4;
  ErrorCount   : abap.int4;
  Details      : abap.string(0); // Mỗi dòng: <Document SequenceNo>: <kết quả>
}
