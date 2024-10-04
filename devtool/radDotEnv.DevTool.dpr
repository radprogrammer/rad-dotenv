program radDotEnv.DevTool;

uses
  Vcl.Forms,
  radDotEnv.DevTool.MainForm in 'radDotEnv.DevTool.MainForm.pas' {frmMain},
  radDotEnv in '..\source\radDotEnv.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
