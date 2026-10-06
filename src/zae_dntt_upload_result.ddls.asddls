@EndUserText.label: 'Upload DNTT - Upload result'
define abstract entity ZAE_DNTT_UPLOAD_RESULT
{
  DocumentCount : abap.int4;
  ItemCount     : abap.int4;
  ErrorCount    : abap.int4;
  Warnings      : abap.string(0); // Cảnh báo (vd. chứng từ đã Posted bị bỏ qua), mỗi dòng 1 cảnh báo
  // Lỗi chặn cả file (không lưu gì), mỗi dòng 1 lỗi. Trả qua result vì message RAP bị cắt ở 50 ký tự
  Errors        : abap.string(0);
}
