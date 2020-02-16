unit mipas;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, db, FileUtil, SdpoSerial, Forms,
  Controls, Graphics, Dialogs, DBGrids, Grids, StdCtrls, ExtCtrls, IniFiles;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    lblcBps: TLabel;
    lblvRng1: TLabel;
    lblvCrNothing: TLabel;
    lblcCrNothing: TLabel;
    lblvRng0: TLabel;
    lblvBytesReceivedPerSecond: TLabel;
    lblcBytesReceivedPerSecond: TLabel;
    rs232ComPort: TSdpoSerial;
    sgSr: TStringGrid;
    sgCr: TStringGrid;
    tc500ms: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure rs232ComPortRxData(Sender: TObject);
    procedure tc500msTimer(Sender: TObject);
  private

  public
  end;

type
  TProc = procedure();
var
  frmMain: TfrmMain;

  ui8Error,
  ui8LastGoodByte,
  ui8Sockets: byte;

  ui32BytesReceived,
  ui32FreeSpaceP1,
  ui32SerRxHead,
  ui32SerRxTail: cardinal;

  ptrArCr: array[0..63] of Pointer;
  ptrArSr: array[0..63] of Pointer;
  ui8ArSerRxBff: array[0..65535] of byte;
  ui8ArSkIf: array[0..11] of byte;

implementation

{$R *.lfm}

//******************************************************************************
function NibToHex(bytNibble: byte):string;
begin
 CASE bytNibble of
  0: NibToHex := '0';
  1: NibToHex := '1';
  2: NibToHex := '2';
  3: NibToHex := '3';
  4: NibToHex := '4';
  5: NibToHex := '5';
  6: NibToHex := '6';
  7: NibToHex := '7';
  8: NibToHex := '8';
  9: NibToHex := '9';
  10: NibToHex := 'A';
  11: NibToHex := 'B';
  12: NibToHex := 'C';
  13: NibToHex := 'D';
  14: NibToHex := 'E';
  15: NibToHex := 'F';
  ELSE NibToHex := 'X';
 end;
end;

//******************************************************************************
function ByteToHex(bytByte: byte):string;
begin
 ByteToHex := NibToHex(bytByte shr 4) + NibToHex(bytByte and $F);
end;

procedure prCrGCGS;
begin
  frmMain.sgCr.Cells[0, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]);
  frmMain.sgCr.Cells[1, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]);

  ui32SerRxTail := (ui32SerRxTail + 5) and $FFFF;
  ui32FreeSpaceP1 := ui32FreeSpaceP1 + 5;
end;

procedure prCrHMA;
begin
  frmMain.sgCr.Cells[2, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF])
                            + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF]);
  ui32SerRxTail := (ui32SerRxTail + 7) and $FFFF;
  ui32FreeSpaceP1 := ui32FreeSpaceP1 + 7;
end;

procedure prCrHIPA_HSM_GIPA;
begin
  frmMain.sgCr.Cells[3, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]);
  frmMain.sgCr.Cells[4, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 8) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 7) and $FFFF]);
  frmMain.sgCr.Cells[5, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 10) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 9) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 12) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 11) and $FFFF]);
  ui32SerRxTail := (ui32SerRxTail + 13) and $FFFF;
  ui32FreeSpaceP1 := ui32FreeSpaceP1 + 13;
end;

procedure prCrIF;
var
  ui8FlagLen, ui8For: byte;
begin
 frmMain.sgCr.Cells[6, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) +  ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]);
 ui32SerRxTail := (ui32SerRxTail + 5) and $FFFF;
 ui32FreeSpaceP1 := ui32FreeSpaceP1 + 5;
end;

procedure prCrPHYCS;
begin
   frmMain.sgCr.Cells[7, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]);
   frmMain.sgCr.Cells[8, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]);
   ui32SerRxTail := (ui32SerRxTail + 5) and $FFFF;
   ui32FreeSpaceP1 := ui32FreeSpaceP1 + 5;
end;

procedure prCrPQIP;
begin
  frmMain.sgCr.Cells[9, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]);
  ui32SerRxTail := (ui32SerRxTail + 5) and $FFFF;
  ui32FreeSpaceP1 := ui32FreeSpaceP1 + 5;
end;

procedure prCrDHCS;
begin
   frmMain.sgCr.Cells[10, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]);
   ui32SerRxTail := (ui32SerRxTail + 3) and $FFFF;
   ui32FreeSpaceP1 := ui32FreeSpaceP1 + 3;
end;

procedure prCrDHSRV;
begin
  frmMain.sgCr.Cells[11, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]);
  frmMain.sgCr.Cells[12, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 8) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 7) and $FFFF]);
  frmMain.sgCr.Cells[13, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 10) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 9) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 12) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 11) and $FFFF]);
  ui32SerRxTail := (ui32SerRxTail + 13) and $FFFF;
  ui32FreeSpaceP1 := ui32FreeSpaceP1 + 13;
end;

procedure prCrDHRLT_DHLT;
begin
  frmMain.sgCr.Cells[14, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF] + ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF] shl 8 + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF] shl 16 + ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] shl 24);
  frmMain.sgCr.Cells[15, 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF] + ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF] shl 8 + ui8ArSerRxBff[(ui32SerRxTail + 7) and $FFFF] shl 16 + ui8ArSerRxBff[(ui32SerRxTail + 8) and $FFFF] shl 24);
  ui32SerRxTail := (ui32SerRxTail + 9) and $FFFF;
  ui32FreeSpaceP1 := ui32FreeSpaceP1 + 9;
end;

procedure prCrPORTB;
begin
   frmMain.sgCr.Cells[16, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF])
                        + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF])
                        + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]);
   ui32SerRxTail := (ui32SerRxTail + 7) and $FFFF;
   ui32FreeSpaceP1 := ui32FreeSpaceP1 + 7;
end;

procedure prCrPORTE;
begin
   frmMain.sgCr.Cells[17, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]);
   ui32SerRxTail := (ui32SerRxTail + 4) and $FFFF;
   ui32FreeSpaceP1 := ui32FreeSpaceP1 + 4;
end;

procedure prCrArpCtrl;
begin
   frmMain.sgCr.Cells[18, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]);
   frmMain.sgCr.Cells[19, 1] := IntToStr((ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] * 256 + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) shr 3);
   ui32SerRxTail := (ui32SerRxTail + 5) and $FFFF;
   ui32FreeSpaceP1 := ui32FreeSpaceP1 + 5;
end;

procedure prCrFWIDB;
begin
  frmMain.sgCr.Cells[20, 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF]);
  ui32SerRxTail := (ui32SerRxTail + 5) and $FFFF;
  ui32FreeSpaceP1 := ui32FreeSpaceP1 + 5;
end;

























procedure prSrArpFlagsTc;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[1, ui8SkNo + 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    frmMain.sgSr.Cells[2, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 7) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 8) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 8;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrArpMAC;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[3, ui8SkNo + 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 7) and $FFFF]) + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 8) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 8;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnCS;
var
  ui8B0, ui8B1, ui8Mode, ui8Ss, ui8SkNo: byte;
  strPdpif, strSs, strSen, strSv, strCfr, strToc, strMode, strWa: string;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    ui8B0 := ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF];
    ui8B1 := ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF];
//    if (ui8B1 and $80) > 0 then strPdpif := '1' else strPdpif := '0';
//    if (ui8B1 and $40) > 0 then strWa := '1' else strWa := '0';
    if (ui8B1 and $20) > 0 then strPdpif := '1' else strPdpif := '0';
    if (ui8B1 and $10) > 0 then strWa := '1' else strWa := '0';
    ui8Mode := ui8B0 and $F;
    ui8Ss := ui8B1 and $F;
    if ui8Ss = 15 then strSs := ' CFG_ERROR ';
    if (ui8Mode = 0) or (ui8Mode = 1) then begin // UDP
      if ui8Ss = 0 then strSs := '  CLOSED   '
      else if ui8Ss = 1 then strSs := '  RUNNING  '
      else if ui8Ss = 14 then strSs := 'ARP TIMEOUT';
    end
    else if (ui8Mode = 2) or (ui8Mode = 3) then begin // TCP
      if ui8Ss = 0 then strSs := '  CLOSED   '
      else if ui8Ss = 1 then strSs := ' LISTENING '
      else if ui8Ss = 2 then strSs := ' SEND_SYN  '
      else if ui8Ss = 3 then strSs := ' SYN_RCVD  '
      else if ui8Ss = 4 then strSs := 'ESTABLISHED'
      else if ui8Ss = 5 then strSs := 'FIN_WAIT_TX'
      else if ui8Ss = 6 then strSs := 'FIN_WAIT_1 '
      else if ui8Ss = 7 then strSs := 'FIN_WAIT_2 '
      else if ui8Ss = 8 then strSs := '  CLOSING  '
      else if ui8Ss = 9 then strSs := 'CLOSE_WAIT '
      else if ui8Ss = 10 then strSs := 'CLOSE_WAIT_'
      else if ui8Ss = 11 then strSs := ' LAST_ACK  '
      else if ui8Ss = 12 then strSs := ' TIME_WAIT '
      else if ui8Ss = 13 then strSs := 'RST_BY_PEER'
      else if ui8Ss = 14 then strSs := 'TCP_TIMEOUT'
    end;
    if (ui8B0 and $80) > 0 then strSen := '1' else strSen := '0';
    if (ui8B0 and $40) > 0 then strSv := '1' else strSv := '0';
    if (ui8B0 and $20) > 0 then strCfr := '1' else strCfr := '0';
    if (ui8B0 and $10) > 0 then strToc := '1' else strToc := '0';
    if (ui8B0 and $F) = 0 then strMode := 'UDPC'
    else if (ui8B0 and $F) = 1 then strMode := 'UDPS'
    else if (ui8B0 and $F) = 2 then strMode := 'TCPC'
    else if (ui8B0 and $F) = 3 then strMode := 'TCPS'
    else strMode := ' ----';

   // else frmMain.sgSr.Cells[0, ui8SkNo + 1] := 'Disabled';
    frmMain.sgSr.Cells[4, ui8SkNo + 1] := strPdpif + ' ' + strWa + ' ' + strSs + ' ' + strSen + ' ' + strSv + ' ' + strCfr + ' ' + strToc + ' ' + strMode;
    ui32SerRxTail := (ui32SerRxTail + 4) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 4;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnIPA;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[5, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnSM;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[6, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnPIPA;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[7, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + '.' + IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnP;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[8, ui8SkNo + 1] := IntToStr((ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + (ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF] shl 8));
    frmMain.sgSr.Cells[9, ui8SkNo + 1] := IntToStr((ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + (ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] shl 8));
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnBSPS;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[10, ui8SkNo + 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end;
end;

procedure prSrSnMTU_PMSS;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[11, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    frmMain.sgSr.Cells[12, ui8SkNo + 1] := IntToStr(((ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) shl 8) + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]);
    frmMain.sgSr.Cells[13, ui8SkNo + 1] := IntToStr(((ui8ArSerRxBff[(ui32SerRxTail + 6) and $FFFF]) shl 8) + ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 7) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 7;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnRTO_SRTT;
var
  ui8SkNo: byte;
  ui32Temp: cardinal;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    ui32Temp := ((ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) shl 8) + ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF];
    frmMain.sgSr.Cells[14, ui8SkNo + 1] := FloatToStrF(ui32Temp / 200, ffFixed, 2, 3);
    ui32Temp := ((ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) shl 8) + ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF];
    frmMain.sgSr.Cells[15, ui8SkNo + 1] := FloatToStrF(ui32Temp / 200, ffFixed, 2, 3);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnCW_SST;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
//    frmMain.sgSr.Cells[14, ui8SkNo + 1] := ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF]) + ' ' + ByteToHex(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    frmMain.sgSr.Cells[16, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF] + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF] * 256);
    frmMain.sgSr.Cells[17, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] + ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF] * 256);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnRHP;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[18, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF] shl 24 + ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] shl 16 + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF] shl 8 + ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnRTP;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[19, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF] shl 24 + ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] shl 16 + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF] shl 8 + ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnTHP;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[20, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF] shl 24 + ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] shl 16 + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF] shl 8 + ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnTHHP;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[21, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF] shl 24 + ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] shl 16 + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF] shl 8 + ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prSrSnTTP;
var
  ui8SkNo: byte;
begin
  ui8SkNo := ui8ArSerRxBff[(ui32SerRxTail + 1) and $FFFF];
  if (ui8SkNo + 1) < frmMain.sgSr.RowCount then begin
    frmMain.sgSr.Cells[22, ui8SkNo + 1] := IntToStr(ui8ArSerRxBff[(ui32SerRxTail + 5) and $FFFF] shl 24 + ui8ArSerRxBff[(ui32SerRxTail + 4) and $FFFF] shl 16 + ui8ArSerRxBff[(ui32SerRxTail + 3) and $FFFF] shl 8 + ui8ArSerRxBff[(ui32SerRxTail + 2) and $FFFF]);
    ui32SerRxTail := (ui32SerRxTail + 6) and $FFFF;
    ui32FreeSpaceP1 := ui32FreeSpaceP1 + 6;
  end
  else begin
    ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
    INC(ui32FreeSpaceP1);
  end;
end;

procedure prNothing;
begin
//  frmMain.lblvCrNothing.Caption := '1';
  ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
  INC(ui32FreeSpaceP1);
end;


procedure TfrmMain.FormCreate(Sender: TObject);
var
  clColumn: TGridColumn;
  intFor: integer;
  strTemp: string;
  iniFile: TIniFile;
begin
 ui8LastGoodByte:=0;
  ui8Sockets := 4;
  frmMain.sgCr.DoubleBuffered := true;
  with frmMain.sgCr do
  begin
    RowCount := 2;
    FixedRows := 1;

    clColumn := Columns.Add;
    clColumn.Width := 40;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'GC';

    clColumn := Columns.Add;
    clColumn.Width := 40;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'GS';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'HMA';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'HIPA';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'HSM';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'GIPA';

    clColumn := Columns.Add;
    clColumn.Width := 70;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'IF';

    clColumn := Columns.Add;
    clColumn.Width := 45;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'PHYCS';

    clColumn := Columns.Add;
    clColumn.Width := 45;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'ICMP';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'PQIP';

    clColumn := Columns.Add;
    clColumn.Width := 45;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'DHCS';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'DHSRV';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'DNS1';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'DNS2';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'DHRLT';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'DHLT';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'PORTB';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'PORTE';

    clColumn := Columns.Add;
    clColumn.Width := 40;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'ARPC';

    clColumn := Columns.Add;
    clColumn.Width := 40;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'ATTL';

    clColumn := Columns.Add;
    clColumn.Width := 80;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Courier';
    clColumn.Font.Size := 10;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'FWIDB';
  end;

  frmMain.sgSr.DoubleBuffered := true;
  with frmMain.sgSr do
  begin
    RowCount := 17;
    FixedRows := 1;

    clColumn := Columns.Add;
    clColumn.Width := 20;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'Sn';

    clColumn := Columns.Add;
    clColumn.Width := 50;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'Status';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'ARP IP';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'ARP MAC';

    clColumn := Columns.Add;
    clColumn.Width := 250;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Courier';
    clColumn.Font.Size := 10;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := '15  14           STATUS          7   6   5   4     MODE';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnIPA';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnSM';

    clColumn := Columns.Add;
    clColumn.Width := 100;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnPIPA';

    clColumn := Columns.Add;
    clColumn.Width := 50;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnP';

    clColumn := Columns.Add;
    clColumn.Width := 50;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnPP';

    clColumn := Columns.Add;
    clColumn.Width := 80;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnBSPS';

    clColumn := Columns.Add;
    clColumn.Width := 40;
    clColumn.Alignment := taCenter;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnTTL';

    clColumn := Columns.Add;
    clColumn.Width := 45;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnMTU';

    clColumn := Columns.Add;
    clColumn.Width := 40;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnPMSS';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnRTO';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnSRTT';

    clColumn := Columns.Add;
    clColumn.Width := 50;
    clColumn.Alignment := taRightJustify;;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnCW';

    clColumn := Columns.Add;
    clColumn.Width := 50;
    clColumn.Alignment := taRightJustify;;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnSST';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnRHP';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnRTP';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnTHP';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnTHHP';

    clColumn := Columns.Add;
    clColumn.Width := 55;
    clColumn.Alignment := taRightJustify;
    clColumn.Font.Name := 'Arial';
    clColumn.Font.Size := 9;
    clColumn.Title.Alignment := taCenter;
    clColumn.Title.Caption := 'SnTTP';

    Cells[0, 1] := '0';
    Cells[0, 2] := '1';
    Cells[0, 3] := '2';
    Cells[0, 4] := '3';
    Cells[0, 5] := '4';
    Cells[0, 6] := '5';
    Cells[0, 7] := '6';
    Cells[0, 8] := '7';
    Cells[0, 9] := '8';
    Cells[0, 10] := '9';
    Cells[0, 11] := '10';
    Cells[0, 12] := '11';
    Cells[0, 13] := '12';
    Cells[0, 14] := '13';
    Cells[0, 15] := '14';
    Cells[0, 16] := '15';
end;





  for intFor := 0 to 63 do begin
    ptrArCr[intFor] := @prNothing;
  end;

  ptrArCr[0] := @prCrGCGS; // 0
  ptrArCr[1] := @prCrHMA; // 2
  ptrArCr[2] := @prCrHIPA_HSM_GIPA; // 4
  ptrArCr[3] := @prCrIF; // 8
  ptrArCr[4] := @prCrPHYCS; // 10
  ptrArCr[5] := @prCrPQIP; // 12
  ptrArCr[6] := @prCrDHCS; // 14
  ptrArCr[7] := @prCrDHSRV; // 16
  ptrArCr[8] := @prCrDHRLT_DHLT; // 18
  ptrArCr[9] := @prCrPORTB; // 20
  ptrArCr[10] := @prCrPORTE; // 22
  ptrArCr[11] := @prCrArpCtrl; // 24
  ptrArCr[13] := @prCrFWIDB; // 28


  for intFor := 0 to 63 do begin
    ptrArSr[intFor] := @prNothing;
  end;

  ptrArSr[0] := @prSrArpFlagsTc;
  ptrArSr[1] := @prSrArpMac;
  ptrArSr[2] := @prSrSnCS;
  ptrArSr[3] := @prSrSnIPA;
  ptrArSr[4] := @prSrSnSM;
  ptrArSr[5] := @prSrSnPIPA;
  ptrArSr[6] := @prSrSnP;
  ptrArSr[7] := @prSrSnBSPS;
  ptrArSr[8] := @prSrSnMTU_PMSS;
  ptrArSr[9] := @prSrSnRTO_SRTT;
  ptrArSr[10] := @prSrSnCW_SST;
  ptrArSr[11] := @prSrSnRHP;
  ptrArSr[12] := @prSrSnRTP;
  ptrArSr[13] := @prSrSnTHP;
  ptrArSr[14] := @prSrSnTHHP;
  ptrArSr[15] := @prSrSnTTP;

  iniFile := TIniFile.Create( ChangeFileExt( Application.ExeName, '.INI' ) );
  strTemp := iniFile.ReadString('Settings', 'ComPort', 'COM1');
  iniFile.Free;
  frmMain.rs232ComPort.Device := strTemp;
//  frmMain.rs232ComPort.BaudRate := br115200;
  frmMain.rs232ComPort.AltBaudRate := 115200;
  frmMain.rs232ComPort.Open;




end;

procedure TfrmMain.rs232ComPortRxData(Sender: TObject);
var
  ui32LenStrSerRx,
  ui32SerRxBffFreeTop: cardinal;

  strSerRx: string;
begin
  // read rs232ComPort Rx buffer
  strSerRx := frmMain.rs232ComPort.ReadData();
  ui32LenStrSerRx := LENGTH(strSerRx);
  ui32BytesReceived := ui32BytesReceived + ui32LenStrSerRx;
//  frmMain.lblvRng1.Caption := IntToStr(ui32LenStrSerRx);

  // find out free space + 1 in the Rx buffer
  ui32FreeSpaceP1 := ui32SerRxTail - ui32SerRxHead; // for now
  if ui32SerRxHead >= ui32SerRxTail then ui32FreeSpaceP1 := ui32FreeSpaceP1 + 65536;

  // check if data received fits in the buffer; ui32FreeSpaceP1 has the free space plus 1
  if ui32LenStrSerRx < ui32FreeSpaceP1 THEN begin // if there is enough free space

    // find out free space top (above head)
    ui32SerRxBffFreeTop := 65536 - ui32SerRxHead;
    if ui32LenStrSerRx <= ui32SerRxBffFreeTop then begin
      Move(strSerRx[1], ui8ArSerRxBff[ui32SerRxHead], ui32LenStrSerRx);
    end
    else begin
      Move(strSerRx[1], ui8ArSerRxBff[ui32SerRxHead], ui32SerRxBffFreeTop);
      Move(strSerRx[1 + ui32SerRxBffFreeTop], ui8ArSerRxBff[0], ui32LenStrSerRx - ui32SerRxBffFreeTop);
    end;
    ui32SerRxHead := (ui32SerRxHead + ui32LenStrSerRx) and $FFFF; // update header, rollover 65536
  end;

  // read buffer
  while ui32FreeSpaceP1 < 65436 do begin // while there are at least 100 bytes in the buffer
//    ui8LastGoodByte := ui8ArSerRxBff[ui32SerRxTail];
    if (ui8ArSerRxBff[ui32SerRxTail] < 64) and ((ui8ArSerRxBff[ui32SerRxTail] and 1) = 0) then begin // common registers
ui8LastGoodByte := ui8ArSerRxBff[ui32SerRxTail];
      TProc(ptrArCr[ui8ArSerRxBff[ui32SerRxTail] shr 1]);
    end
    else if (ui8ArSerRxBff[ui32SerRxTail] < 64) and (((ui8ArSerRxBff[ui32SerRxTail] and 1) = 1)) and (ui8ArSerRxBff[ui32SerRxTail + 1] < 16) then begin // socket registers. ONly up to 24 sockets for now
ui8LastGoodByte := ui8ArSerRxBff[ui32SerRxTail];
      TProc(ptrArSr[(ui8ArSerRxBff[ui32SerRxTail]) shr 1]);
    end
    else begin // error
      INC(ui8Error);
      frmMain.lblcCrNothing.Caption := IntToStr(ui8LastGoodByte);
      frmMain.lblvCrNothing.Caption := IntToStr(ui8Error);
      ui32SerRxTail := (ui32SerRxTail + 1) and $FFFF;
      INC(ui32FreeSpaceP1);
    end;
//    TProc(ptrArCr[1]);
//    frmMain.lblvCrNothing.Caption := IntToStr(ui32FreeSpaceP1);
  end;
end;

procedure TfrmMain.tc500msTimer(Sender: TObject);
begin
  frmmain.lblvBytesReceivedPerSecond.Caption := IntToStr(8 * ui32BytesReceived);
  ui32BytesReceived := 0;
  frmMain.lblvRng0.Caption := IntToStr(ui32SerRxTail);
  frmMain.lblvRng1.Caption := IntToStr(ui32SerRxHead);
end;


end.

