// DotEnv file (.env) support for Delphi
// More info: https://github.com/radprogrammer/rad-dotenv
unit radDotEnv.DemoConsoleApp.MainU;

interface

procedure MainDemo;

implementation
uses
  radDotEnv;

procedure MainDemo;
var
  env:iDotEnv;
begin
  //alternatively, define a new define radDotEnv_SINGLETON and use the global DotEnv
  env := NewDotEnv.UseRetrieveOption(TRetrieveOption.PreferDotEnv)
                  .UseSetOption(TSetOption.AlwaysSet)
                  .UseEscapeSequenceInterpolationOption(TEscapeSequenceInterpolationOption.SupportEscapesInDoubleQuotedValues)
                  .Load;

(*
Demo .env file contents =
USER=admin
EMAIL="${USER}@example.org"
DATABASE_URL="postgres://${USER}@localhost/my_database"
*)

  WriteLn('USER=' + env.Get('USER'));   //should be:  "USER=admin"
  WriteLn('EMAIL=' + env.Get('EMAIL'));  //should be:  "EMAIL=admin@example.org"
  WriteLn('DATABASE_URL=' + env.Get('DATABASE_URL')); //should be: "DATABASEURL=postgres://admin@localhost/my_database"

  ReadLn;
end;

end.
