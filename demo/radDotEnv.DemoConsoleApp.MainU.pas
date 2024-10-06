// DotEnv file (.env) support for Delphi
// More info: https://github.com/radprogrammer/rad-dotenv
unit radDotEnv.DemoConsoleApp.MainU;

interface

procedure MainDemo;

implementation
uses
  radDotEnv;

procedure MainDemo;
begin
(*
Demo .env file contents =
USER=admin
EMAIL="${USER}@example.org"
DATABASE_URL="postgres://${USER}@localhost/my_database"
*)

  WriteLn('USER=' + DotEnv.Get('USER'));   //should be:  "USER=admin"
  WriteLn('EMAIL=' + DotEnv.Get('EMAIL'));  //should be:  "EMAIL=admin@example.org"
  WriteLn('DATABASE_URL=' + DotEnv.Get('DATABASE_URL')); //should be: "DATABASEURL=postgres://admin@localhost/my_database"

  ReadLn;
end;

end.
