program radDotEnv.DemoConsoleApp;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  radDotEnv.DemoConsoleApp.MainU in 'radDotEnv.DemoConsoleApp.MainU.pas',
  radDotEnv in '..\source\radDotEnv.pas';

begin
  try
    MainDemo;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
