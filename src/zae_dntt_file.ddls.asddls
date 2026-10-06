@EndUserText.label: 'Upload DNTT - File'
define abstract entity ZAE_DNTT_FILE
{
  FileName    : abap.char(128);
  MimeType    : abap.char(128);
  FileContent : abap.string(0); // base64
}
