program radDotEnv.TestFileGenerator;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  radDotEnv.Tests in '..\radDotEnv.Tests.pas',
  radDotEnv in '..\..\source\radDotEnv.pas',
  radDotEnv.TestFileGenerator.CreateLargeFile in 'radDotEnv.TestFileGenerator.CreateLargeFile.pas';

begin
  try
    CreateLargeEnvFile(radDotEnv.Tests.LargeGeneratedTestFileName, radDotEnv.Tests.LargeVariableCount);
  except
    on E: Exception do
      Writeln('Error: ', E.Message);
  end;
end.
