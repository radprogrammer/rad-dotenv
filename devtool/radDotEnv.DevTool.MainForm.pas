unit radDotEnv.DevTool.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Grids, Vcl.ExtCtrls,
  radDotEnv;


type
  TfrmMain = class(TForm)
    gridDotEnvParsed: TStringGrid;
    memLog: TMemo;
    panContents: TPanel;
    panParsed: TPanel;
    labContentsHeader: TLabel;
    labParsedHeader: TLabel;
    panSys: TPanel;
    labSysHeader: TLabel;
    gridSys: TStringGrid;
    memDotEnvContents: TMemo;
    panContentsActions: TPanel;
    butSaveContents: TButton;
    panGrids: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure butSaveContentsClick(Sender: TObject);
  private
    fDotEnv:iDotEnv;
    procedure LogIt(const Text:String);
    procedure PopulateSystemVariables;
    procedure PopulateParsedDotEnvGrid;
    procedure LoadGrids;
  end;

var
  frmMain: TfrmMain;

const
  COL_KEY = 0;
  COL_VALUE = 1;

implementation
uses
  System.Generics.Collections,
  System.Generics.Defaults;

{$R *.dfm}



procedure TfrmMain.FormCreate(Sender: TObject);
    procedure SetupGrid(const grid:TStringGrid);
    begin
      grid.FixedRows := 1;
      grid.FixedCols := 0;
      grid.Options := grid.Options + [goRowSelect] - [goRangeSelect];
      grid.ColCount := 2;
      grid.RowCount := 2;
      grid.ColWidths[COL_KEY] := 200;
      grid.ColWidths[COL_VALUE] := 4000;
      grid.Cells[COL_KEY, 0] := 'Key';
      grid.Cells[COL_VALUE, 0] := 'Value';
    end;
begin
  ReportMemoryLeaksOnShutdown := True;

  panGrids.Width := (Screen.Width * 2 ) div 3;
  panParsed.Width := panGrids.Width div 2;

  SetupGrid(gridDotEnvParsed);
  SetupGrid(gridSys);

  memDotEnvContents.Lines.LoadFromFile('.env');

  LoadGrids;
end;

procedure TfrmMain.LoadGrids;
begin
  memLog.Clear;
  LogIt('Loading .env file');
  fDotEnv := NewDotEnv
             .UseSetOption(TSetOption.AlwaysSet)
             .UseLogProc(LogIt)
             .Load;

  PopulateSystemVariables;
  PopulateParsedDotEnvGrid;
end;

procedure TfrmMain.butSaveContentsClick(Sender: TObject);
begin
  memDotEnvContents.Lines.SaveToFile('.env');
  LoadGrids;
end;



procedure TfrmMain.LogIt(const Text:String);
begin
  memLog.Lines.Add(Text);
end;


procedure TfrmMain.PopulateParsedDotEnvGrid;
var
  DotEnvKeyPairs:TArray<TStringKeyValue>;
  i:Integer;
  Len:Integer;
begin
  DotEnvKeyPairs := fDotEnv.ToArray;  //ToArray is a useful debugging method, but otherwise not typically used

  TArray.Sort<TPair<string, string>>(DotEnvKeyPairs, TComparer<TPair<string, string>>.Construct(
    function(const Left, Right: TPair<string, string>): Integer
    begin
      Result := CompareText(Left.Key, Right.Key);
    end
   ));

  Len := Length(DotEnvKeyPairs);

  gridDotEnvParsed.RowCount := Len + 1;

  for i := 0 to Len - 1 do
  begin
    gridDotEnvParsed.Cells[COL_KEY, i+1] := DotEnvKeyPairs[i].Key;
    gridDotEnvParsed.Cells[COL_VALUE, i+1] := StringReplace(StringReplace(DotEnvKeyPairs[i].Value, #10, '/n', [rfReplaceAll]), #13, '/r', [rfReplaceAll]);
  end;
end;

procedure GetSystemEnvironmentVariables(const Destination:TStrings);
var
  EnvVars:PChar;
  Current:PChar;
  KeyValue:string;
begin
  EnvVars := GetEnvironmentStrings;
  try
    Current := EnvVars;
    while Current^ <> #0 do
    begin
      if Current^ <> '=' then   //skip special blank key with value of "::=::" used by CMD
      begin
        KeyValue := Current;
        Destination.Add(KeyValue);
      end;
      Inc(Current, StrLen(Current) + 1);
    end;
  finally
    FreeEnvironmentStrings(EnvVars);
  end;
end;

procedure TfrmMain.PopulateSystemVariables;
var
  SystemEnvironment:TStringList;
  i:integer;
begin

  SystemEnvironment := TStringList.Create;
  try

    GetSystemEnvironmentVariables(SystemEnvironment);
    gridSys.RowCount := SystemEnvironment.Count + 1;

    for i := 0 to SystemEnvironment.Count - 1 do
    begin
      gridSys.Cells[COL_KEY, i+1] := SystemEnvironment.Names[i];
      gridSys.Cells[COL_VALUE, i+1] := SystemEnvironment.ValueFromIndex[i];
    end;

  finally
    SystemEnvironment.Free;
  end;
end;

end.
