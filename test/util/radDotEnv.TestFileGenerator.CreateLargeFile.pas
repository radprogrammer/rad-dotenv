unit radDotEnv.TestFileGenerator.CreateLargeFile;

interface

procedure CreateLargeEnvFile(const FileName:string; const VariableCount:Integer);

implementation
uses
  System.SysUtils,
  System.Classes;

procedure CreateLargeEnvFile(const FileName:string; const VariableCount:Integer);
var
  EnvFile: TStringList;
  I: Integer;
begin
  EnvFile := TStringList.Create;
  try

    EnvFile.Add('');
    for I := 1 to VariableCount do
    begin
      EnvFile.Add(Format('VAR_%d=Value_%d', [I, I]));
    end;
    EnvFile.Add('');


    EnvFile.SaveToFile(FileName);
    Writeln(Format('Successfully generated the .env file with %d variables at "%s".', [VariableCount, FileName]));
  finally
    EnvFile.Free;
  end;
end;

end.
