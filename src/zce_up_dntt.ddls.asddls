@EndUserText.label: 'Upload DNTT - List'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_UP_DNTT'
@Metadata.allowExtensions: true
define root custom entity ZCE_UP_DNTT
{
  key DocumentSequenceNo : abap.char(10);
      TrgSpecGlInd       : abap.char(30);
      Status             : abap.char(10);
      StatusCriticality  : abap.int1;
      DocumentNumber     : abap.char(20);
      CompanyCode        : abap.char(4);
      JeType             : abap.char(2);
      PostingDate        : abap.dats;
      Currency           : abap.char(3);
      HeaderText         : abap.char(25);
      Supplier           : abap.char(10);
      PaymentMethod      : abap.char(1);
      PartnerBankType    : abap.char(4);
      BankAccount        : abap.char(18);
      Bank               : abap.char(60);
      AccountHolder      : abap.char(60);
      ProfitCenter       : abap.char(6);
      DueOn              : abap.dats;
      TotalAmount        : abap.decfloat34;
      TotalTax           : abap.decfloat34;
      Message            : abap.char(255);
      CreatedBy          : abap.char(12);
      CreatedOn          : abap.dats;
      // Tham số in (chỉ là filter, không lọc dữ liệu) -> truyền sang báo cáo ZDENGHITT khi bấm Print
      NguoiDeNghi        : abap.char(80);
      PhongBan           : abap.char(80);
      NguoiLap           : abap.char(80);
      GiamDoc            : abap.char(80);
      KeToan             : abap.char(80);
}
