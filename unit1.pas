unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, StdCtrls, FileUtil;

type
    Line = record
      len      : integer;
      addr     : integer;
      data     : array of byte;
      checksum : byte;
      next     : ^Line;
    end;
    wsk        = ^Line;
  { TForm1 }

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure MenuItem4Click(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure ClearLines;
    procedure AddLines(l: wsk);
    function GetLine:wsk;
    procedure ResetLines;
    procedure SaveFile(filename: string);
  private

    var
    edit : Boolean;
    hexfile: TextFile;
    dane : wsk;
    active_line : wsk;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }
procedure TForm1.SaveFile(filename: string);
var
  l: wsk;
  chk_sum: byte;
  i:integer;
begin

  //if not FileExists(filename) then
  //begin
    //FileCreate(filename);
  //end;
  AssignFile(hexfile, filename);
  {$I-} // without this, if rewrite fails then a runtime error will be generated
  Rewrite(hexfile);
  {$I+}
  try
    ResetLines;
    while active_line<>nil do
    begin
      Write(hexfile, ':' + active_line^.len.ToHexString(2) );
      Write(hexfile,  (active_line^.addr div 2).ToHexString(4) );
      Write(hexfile,  '00' );
      chk_sum:=byte(active_line^.len);
      chk_sum:=chk_sum+Hi(Word(active_line^.addr div 2));
      chk_sum:=chk_sum+Lo(Word(active_line^.addr div 2));
      for i:=0 to active_line^.len -1 do
      begin
        Write(hexfile, active_line^.data[i].ToHexString(2) );
        chk_sum:=chk_sum+active_line^.data[i];
      end;
      chk_sum:=0-chk_sum;
      WriteLn(hexfile,chk_sum.ToHexString(2));
      GetLine;
    end;
    WriteLn(hexfile,':00000001FF');
  finally
    CloseFile(hexfile);
  end;

end;

procedure TForm1.ClearLines;
var
  tmp_wsk: wsk;
  tmp_wsk_prev: wsk;
begin
  tmp_wsk:= dane;
  tmp_wsk_prev:=nil;
  if tmp_wsk<> nil then begin
    while (tmp_wsk^.next<>nil) do
    begin
      tmp_wsk_prev :=tmp_wsk;
      tmp_wsk      :=tmp_wsk^.next;
      FreeMemAndNil(tmp_wsk_prev);
    end;
    FreeMemAndNil(tmp_wsk);
    dane:=nil;
  end;
end;

procedure TForm1.AddLines(l: wsk);
var
  tmp_wsk: wsk;
  tmp_wsk_prev: wsk;
begin
  tmp_wsk:= dane;
  tmp_wsk_prev:=nil;
  if tmp_wsk<> nil then begin
      while (tmp_wsk^.next<>nil) do
      begin
        tmp_wsk_prev :=tmp_wsk;
        tmp_wsk      :=tmp_wsk^.next;
      end;
      tmp_wsk^.next:=l;
    end else begin
      dane:=l;
    end;
end;

function TForm1.GetLine:wsk;
var
  TmpLine: wsk;
begin
  TmpLine:=active_line;
  if TmpLine <> nil then active_line:=active_line^.next;
  GetLine:=TmpLine;
end;

procedure TForm1.ResetLines;
begin
  active_line := dane;
end;

procedure TForm1.MenuItem3Click(Sender: TObject);
var
  s,t: String;
  w: Word;
  i,j: Integer;
  pos1  : Integer;
  l: wsk;
  tmp_len :integer;
  tmp_type : integer;
  tmp_addr : integer;
  error: boolean;
  chk_sum: byte;
  count: integer;
begin
  error:=False;
  count:=0;
  OpenDialog1.Filter:='Intel HEX|*.hex;*.HEX|Motorola S68|*.S68;*.s68';
  if OpenDialog1.Execute then begin
    AssignFile(hexfile, OpenDialog1.FileName);
    ClearLines;
    Memo1.Clear;
    try
      Reset(hexfile);

      while not Eof(hexfile) do
      begin
        count:=count+1;
        ReadLn(hexfile, s);
        if (length(s) < 11) then begin  error:=True; Break; end;
        pos1 := Pos(':', s);
        if pos1=1 then begin
           chk_sum:=0;
           t:=Copy(s,2,2);
           Insert('$',t,1);
           Val(t,w,i);
           tmp_len:=w;
           chk_sum:=chk_sum+w;
           if Length(s) <> (tmp_len*2 + 11) then
           begin
             error:=True;
             Break;
           end;
           t:=Copy(s,4,4);
           Insert('$',t,1);
           Val(t,tmp_addr,i);
           chk_sum:=chk_sum+Hi(Word(tmp_addr));
           chk_sum:=chk_sum+Lo(Word(tmp_addr));
           t:=Copy(s,8,2);
           Insert('$',t,1);
           Val(t,tmp_type,i);
           chk_sum:=chk_sum+Lo(tmp_type);
           if tmp_type = 1 then break;
           if tmp_type <> 0 then
           begin
             error:=True;
             Break;
           end;
           l := new(wsk);
           l^.len:=tmp_len;
           l^.addr:=tmp_addr;
           if l^.len > 0 then begin
             SetLength(l^.data,tmp_len);
             l^.next:=nil;
             for j:=0 to tmp_len-1 do begin
               t:=Copy(s,10+j*2,2);
               Insert('$',t,1);
               Val(t,l^.data[j],i);
               chk_sum:=chk_sum+l^.data[j];
             end;
             t:=Copy(s,10+tmp_len*2,2);
             Insert('$',t,1);
             Val(t,l^.checksum,i);
             chk_sum:=0-chk_sum;
             if l^.checksum <> chk_sum then
             begin
               memo1.lines.add(chk_sum.ToHexString(2));
               memo1.lines.add(l^.checksum.ToHexString(2));
               memo1.lines.add(count.ToHexString(2));
               error:=True;
               Break;
             end;
             AddLines(l);
           end;
        end else begin
           error:=True;
           Break;
        end;
        //Memo1.Lines.Add(s);
      end;
      if error then ClearLines;
      //Val('$4f',w,i);
      //memo1.lines.add(w.ToString);
    finally
    CloseFile(hexfile);
    end;
    if error then
    begin
      ClearLines;
      Memo1.Lines.Add('Error');
    end else
    begin
      ResetLines;
      l:=GetLine;
      while l<>nil do
      begin
        s:=l^.addr.ToHexString(4) + ':';
        for j:=0 to l^.len-1 do begin
          s:=s + ' ' + l^.data[j].ToHexString(2) ;
        end;
        memo1.lines.add(s);
        l:=GetLine;
      end;
    end;
    //filename := OpenDialog1.FileName;
  end;
end;

procedure TForm1.MenuItem4Click(Sender: TObject);
var a: byte;
  i:integer;
begin
  //if not edit then form1.Close;
  //a:=0;
  //a:=a-$91;
  //memo1.lines.add(a.ToHexString(2));
  i:=$0100;
  //memo1.lines.add(lo(Word(i)).ToHexString(2));
  //memo1.lines.add(hi(Word(i)).ToHexString(2));
end;

procedure TForm1.MenuItem2Click(Sender: TObject); //Save
var
  s,ext:string;

begin
  //OpenDialog1.Filter:='Intel HEX16|*.I16';
  //if OpenDialog1.FileName = '' then
  //if OpenDialog1.Execute then
  //begin

  //end;
  //ext:=ExtractFileExt(OpenDialog1.FileName);
  //StringReplace(OpenDialog1.FileName, ext, '',  );
  s:=ExtractFileNameWithoutExt(OpenDialog1.FileName);
  s:=s + '.I16.Hex';
  OpenDialog1.FileName:=s;
  if not FileExists(OpenDialog1.FileName) or (MessageDlg('File exists: overwrite?',mtConfirmation,[mbYes,mbNo],0) = mrYes) then
    SaveFile(OpenDialog1.FileName);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Memo1.Clear;
  edit := False;
  ResetLines;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  Memo1.Left:=0;
  Memo1.Top:=0;
  Memo1.Width:=Form1.Width;
  Memo1.Height:=Form1.Height;
end;

procedure TForm1.MenuItem5Click(Sender: TObject);
begin
  OpenDialog1.Filter:='Intel HEX16|*.I16';
  if OpenDialog1.Execute then begin
    SaveFile(OpenDialog1.FileName);
  end;
end;

end.

