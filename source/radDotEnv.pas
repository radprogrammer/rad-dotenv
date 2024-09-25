// DotEnv file (.env) support for Delphi
// Copyright 2024 Darian Miller, Licensed under Apache-2.0
// SPDX-License-Identifier: Apache-2.0
// More info: https://github.com/radprogrammer/rad-dotenv
unit radDotEnv;


interface

// toreview: Open issue, may change default behavior in the future  https://github.com/radprogrammer/rad-dotenv/issues/1
{ .$DEFINE radDotEnv_SINGLETON }

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Types;

type

  {$REGION Support Types}
  TKeyNameCaseOption = (
    AlwaysToUpperInvariant,
    AlwaysToUpper,
    UpperInvariantWindowsOtherwiseAsIs);  //Environment variables on other systems can be case sensitive, but it can get murky...


  TKeyValueTrimOption = (
    AlwaysRightTrim,                //Operating systems may allow trailing spaces, but many scripts/apps fail to provide for that
    AlwaysLeftAndRightTrim,
    NeverTrim);


  TRetrieveOption = (
    /// <summary> Try getting variable from DotEnv values, and if not found, try getting from system environment</summary>
    PreferFile,
    /// <summary> Try getting from system environment, and if not found, try from DotEnv values</summary>
    PreferSys,
    /// <summary> Only access system environment variable values (do not use DotEnv values)</summary>
    /// <remarks> Some production systems never want to use DotEnv files and only utilize orchestrated system values/remarks>
    OnlyFromSys,
    /// <summary> Only get variable from DotEnv values (do not access system environment variables)</summary>
    OnlyFromFile);


  TEnvVarOptions = record
    RetrieveOption:TRetrieveOption;
    KeyNameCaseOption:TKeyNameCaseOption;
    KeyValueTrimOption:TKeyValueTrimOption;
  end;


  // Note: this option is n/a when using the "OnlyFromSys" Retrieve Option as no need to set System Environment Variables when only source is System
  TSetOption = (
    /// <summary> After DotEnv file parsing is completed, set system environment variables based on DotEnv values only for system environment variables that have no value</summary>
    /// <remarks> System variables take priority over DotEnv files</remarks>
    DoNotOvewrite,
    /// <summary> After DotEnv file parsing is completed, do not set system environment variables based on DotEnv values</summary>
    /// <remarks> Only retrieve values from DotEnv files</remarks>
    NeverSet,
    /// <summary> After DotEnv file parsing is completed, always set system environment variables based on DotEnv values.</summary>
    /// <remarks> DotEnv files take priority over (and replace) system variables. Useful for interop with older code that only reads system environment variables)</remarks>
    AlwaysSet);


  TDotEnvOptions = record
  const
    defEnvFilename:string = '.env';
    defKeyNameCaseOption:TKeyNameCaseOption = TKeyNameCaseOption.AlwaysToUpperInvariant;
    defKeyValueTrimOption:TKeyValueTrimOption = TKeyValueTrimOption.AlwaysRightTrim;
    defRetrieveOption:TRetrieveOption = TRetrieveOption.PreferFile;
    defSetOption:TSetOption = TSetOption.DoNotOvewrite;
  public
    EnvVarOptions:TEnvVarOptions;
    SetOption:TSetOption;
    EnvFileName:string;
    EnvSearchPaths:TArray<string>;
    FileEncoding:TEncoding;
    LogProc:TProc<string>;
    class function DefaultOptions:TDotEnvOptions; static;
  end;
  {$ENDREGION}


  iDotEnv = interface
    ['{23318557-DA37-4030-B393-05EBC885E84C}']
    function Get(const KeyName:string; const DefaultKeyValue:string = ''):string; overload;
    function Get(const KeyName:string; const DefaultKeyValue:string; const EnvVarOptions:TEnvVarOptions):string; overload;

    function TryGet(const KeyName:string; out KeyValue:string):Boolean; overload;
    function TryGet(const KeyName:string; out KeyValue:string; const EnvVarOptions:TEnvVarOptions):Boolean; overload;

    {$REGION Optional usage for functional style initialization}
    function UseKeyNameCaseOption(const KeyNameCaseOption:TKeyNameCaseOption):iDotEnv;
    function UseKeyValueTrimOption(const KeyValueTrimOption:TKeyValueTrimOption):iDotEnv;
    function UseRetrieveOption(const RetrieveOption:TRetrieveOption):iDotEnv;
    function UseSetOption(const SetOption:TSetOption):iDotEnv;
    function UseEnvFileName(const EnvFileName:string):iDotEnv;
    function UseEnvSearchPaths(const EnvSearchPaths:TArray<string>):iDotEnv;
    function UseFileEncoding(const FileEncoding:TEncoding):iDotEnv;
    function UseLogProc(const LogProc:TProc<string>):iDotEnv;
    function Load:iDotEnv;
    {$ENDREGION}
  end;


function NewDotEnv:iDotEnv; overload;
function NewDotEnv(const Options:TDotEnvOptions):iDotEnv; overload;


{$IFDEF radDotEnv_SINGLETON}
var
  DotEnv:iDotEnv;
  {$IFEND}

implementation

uses
  System.Classes,
  {$IFDEF MSWINDOWS}
  WinAPI.Windows,
  {$ENDIF}
  {$IFDEF POSIX}
  Posix.Stdlib,
  {$ENDIF}
  System.IOUtils;

var
  LoadGuard:TObject;

type
  TNameValueMap = TDictionary<string, string>; // Add + 1 to: https://embt.atlassian.net/servicedesk/customer/portal/1/RSS-1862
  TStringKeyValue = TPair<string, string>;


  TDotEnv = class(TInterfacedObject, iDotEnv)
  private const
    LogPrefix = '(dotenv) ';
  strict private
    fMap:TNameValueMap;
    fOptions:TDotEnvOptions;
    procedure EnsureLoaded;
    procedure GuardedSearchFiles;
    procedure GuardedParseDotEnvFileContents(const Contents:string);
    procedure GuardedSetSystemEnvironmentVariables;
  strict protected
    procedure Log(const msg:string);

    function FormattedKeyName(const KeyName:string; const KeyNameCaseOption:TKeyNameCaseOption):string;
    function FormattedKeyValue(const KeyValue:string; const KeyValueTrimOption:TKeyValueTrimOption):string;

    function TryGetFromFile(const StdKeyName:string; out KeyValue:string):Boolean;
    function TryGetFromSys(const StdKeyName:string; out KeyValue:string):Boolean;
  public
    constructor Create; overload;
    constructor Create(const Options:TDotEnvOptions); overload;
    destructor Destroy; override;

    function Get(const KeyName:string; const DefaultKeyValue:string = ''):string; overload;
    function Get(const KeyName:string; const DefaultKeyValue:string; const EnvVarOptions:TEnvVarOptions):string; overload;

    function TryGet(const KeyName:string; out KeyValue:string):Boolean; overload;
    function TryGet(const KeyName:string; out KeyValue:string; const EnvVarOptions:TEnvVarOptions):Boolean; overload;

    {$REGION Optional usage for functional style initialization}
    function UseKeyNameCaseOption(const KeyNameCaseOption:TKeyNameCaseOption):iDotEnv;
    function UseKeyValueTrimOption(const KeyValueTrimOption:TKeyValueTrimOption):iDotEnv;
    function UseRetrieveOption(const RetrieveOption:TRetrieveOption):iDotEnv;
    function UseSetOption(const SetOption:TSetOption):iDotEnv;
    function UseEnvFileName(const EnvFileName:string):iDotEnv;
    function UseEnvSearchPaths(const EnvSearchPaths:TArray<string>):iDotEnv;
    function UseLogProc(const LogProc:TProc<string>):iDotEnv;
    function UseFileEncoding(const FileEncoding:TEncoding):iDotEnv;
    function Load:iDotEnv;
    {$ENDREGION}
  end;


function NewDotEnv:iDotEnv;
begin
  Result := NewDotEnv(TDotEnvOptions.DefaultOptions);
end;


function NewDotEnv(const Options:TDotEnvOptions):iDotEnv;
begin
  Result := TDotEnv.Create(Options);
end;


class function TDotEnvOptions.DefaultOptions:TDotEnvOptions;
begin
  Result := Default(TDotEnvOptions);
  Result.EnvVarOptions.KeyNameCaseOption := defKeyNameCaseOption;
  Result.EnvVarOptions.KeyValueTrimOption := defKeyValueTrimOption;
  Result.EnvVarOptions.RetrieveOption := defRetrieveOption;
  Result.SetOption := defSetOption;
  Result.EnvFileName := defEnvFilename;
  Result.EnvSearchPaths := [ExtractFilePath(ParamStr(0))]; // toreview: ParamStr(0) seems more generally appropriate than GetModuleName(HInstance)
  Result.FileEncoding := TEncoding.UTF8;
  Result.LogProc := nil;
end;


constructor TDotEnv.Create;
begin
  inherited;
  Create(TDotEnvOptions.DefaultOptions);
end;


constructor TDotEnv.Create(const Options:TDotEnvOptions);
begin
  inherited Create;
  fOptions := Options;
end;


destructor TDotEnv.Destroy;
begin
  fMap.Free;
  inherited;
end;


procedure TDotEnv.Log(const msg:string);
begin
  if Assigned(fOptions.LogProc) then
  begin
    fOptions.LogProc(LogPrefix + msg);
  end;
end;


function TDotEnv.UseKeyNameCaseOption(const KeyNameCaseOption:TKeyNameCaseOption):iDotEnv;
begin
  fOptions.EnvVarOptions.KeyNameCaseOption := KeyNameCaseOption;
  Result := self;
end;


function TDotEnv.UseKeyValueTrimOption(const KeyValueTrimOption:TKeyValueTrimOption):iDotEnv;
begin
  fOptions.EnvVarOptions.KeyValueTrimOption := KeyValueTrimOption;
  Result := self;
end;


function TDotEnv.UseRetrieveOption(const RetrieveOption:TRetrieveOption):iDotEnv;
begin
  fOptions.EnvVarOptions.RetrieveOption := RetrieveOption;
  Result := self;
end;


function TDotEnv.UseSetOption(const SetOption:TSetOption):iDotEnv;
begin
  fOptions.SetOption := SetOption;
  Result := self;
end;


function TDotEnv.UseEnvFileName(const EnvFileName:string):iDotEnv;
begin
  fOptions.EnvFileName := EnvFileName;
  Result := self;
end;


function TDotEnv.UseEnvSearchPaths(const EnvSearchPaths:TArray<string>):iDotEnv;
begin
  fOptions.EnvSearchPaths := EnvSearchPaths;
  Result := self;
end;


function TDotEnv.UseFileEncoding(const FileEncoding:TEncoding):iDotEnv;
begin
  fOptions.FileEncoding := FileEncoding;
  Result := self;
end;


function TDotEnv.UseLogProc(const LogProc:TProc<string>):iDotEnv;
begin
  fOptions.LogProc := LogProc;
  Result := self;
end;


function TDotEnv.Load:iDotEnv;
begin
  self.EnsureLoaded;
  Result := self;
end;


function TDotEnv.FormattedKeyName(const KeyName:string; const KeyNameCaseOption:TKeyNameCaseOption):string;
begin
  if KeyNameCaseOption = TKeyNameCaseOption.AlwaysToUpperInvariant then
  begin
    Result := KeyName.Trim.ToUpperInvariant;
  end
  else if KeyNameCaseOption = TKeyNameCaseOption.AlwaysToUpper then
  begin
    Result := KeyName.Trim.ToUpper;
  end
  else { UpperInvariantWindowsOtherwiseAsIs }
  begin
    Assert(KeyNameCaseOption = TKeyNameCaseOption.UpperInvariantWindowsOtherwiseAsIs, Format('Unknown KeyNameCaseOption (%d) in TDotEnv.FormattedKeyName', [Ord(KeyNameCaseOption)]));
    {$IFDEF MSWINDOWS}
    Result := KeyName.Trim.ToUpperInvariant;
    {$ELSE}
    Result := KeyName.Trim;
    {$IFEND}
  end;
end;


function TDotEnv.FormattedKeyValue(const KeyValue:string; const KeyValueTrimOption:TKeyValueTrimOption):string;
begin
  if KeyValueTrimOption = TKeyValueTrimOption.AlwaysRightTrim then
  begin
    Result := KeyValue.TrimRight;
  end
  else if KeyValueTrimOption = TKeyValueTrimOption.AlwaysLeftAndRightTrim then
  begin
    Result := KeyValue.Trim;
  end
  else { NeverTrim }
  begin
    Assert(KeyValueTrimOption = TKeyValueTrimOption.NeverTrim, Format('Unknown KeyValueTrimOption (%d) in TDotEnv.FormattedKeyValue', [Ord(KeyValueTrimOption)]));
    Result := KeyValue;
  end;
end;


function TDotEnv.Get(const KeyName:string; const DefaultKeyValue:string = ''):string;
begin
  Result := Get(KeyName, DefaultKeyValue, fOptions.EnvVarOptions);
end;


function TDotEnv.Get(const KeyName:string; const DefaultKeyValue:string; const EnvVarOptions:TEnvVarOptions):string;
begin
  if not TryGet(KeyName, Result, EnvVarOptions) then
  begin
    Result := DefaultKeyValue;
  end;
end;


function TDotEnv.TryGet(const KeyName:string; out KeyValue:string):Boolean;
begin
  Result := TryGet(KeyName, KeyValue, fOptions.EnvVarOptions);
end;


function TDotEnv.TryGet(const KeyName:string; out KeyValue:string; const EnvVarOptions:TEnvVarOptions):Boolean;
var
  StdKeyName:string;
begin
  if not Assigned(fMap) then
  begin
    EnsureLoaded;
  end;

  StdKeyName := FormattedKeyName(KeyName, EnvVarOptions.KeyNameCaseOption);

  case EnvVarOptions.RetrieveOption of
    TRetrieveOption.OnlyFromFile:
      Result := TryGetFromFile(StdKeyName, KeyValue);
    TRetrieveOption.OnlyFromSys:
      Result := TryGetFromSys(StdKeyName, KeyValue);
    TRetrieveOption.PreferSys:
      Result := TryGetFromSys(StdKeyName, KeyValue) or TryGetFromFile(StdKeyName, KeyValue);
  else { PreferFile }
    Assert(EnvVarOptions.RetrieveOption = TRetrieveOption.PreferFile, Format('Unknown RetrieveOption (%d) in TDotEnv.TryGet', [Ord(EnvVarOptions.RetrieveOption)]));
    Result := TryGetFromFile(StdKeyName, KeyValue) or TryGetFromSys(StdKeyName, KeyValue);
  end;

  KeyValue := FormattedKeyValue(KeyValue, EnvVarOptions.KeyValueTrimOption);
end;


function TDotEnv.TryGetFromFile(const StdKeyName:string; out KeyValue:string):Boolean;
begin
  Result := fMap.TryGetValue(StdKeyName, KeyValue);
end;


function TDotEnv.TryGetFromSys(const StdKeyName:string; out KeyValue:string):Boolean;
begin
  KeyValue := GetEnvironmentVariable(StdKeyName);
  Result := not KeyValue.Trim.IsEmpty;
end;


procedure TDotEnv.EnsureLoaded;
begin
  TMonitor.Enter(LoadGuard);
  try
    GuardedSearchFiles;
  finally
    TMonitor.Exit(LoadGuard);
  end;
end;


procedure TDotEnv.GuardedSearchFiles;
var
  SearchPath:string;
  FullPathName:string;
begin
  if not Assigned(fMap) then
  begin
    fMap := TNameValueMap.Create;
  end;

  for SearchPath in fOptions.EnvSearchPaths do
  begin
    FullPathName := TPath.Combine(SearchPath, fOptions.EnvFileName);
    if TFile.Exists(FullPathName) then
    begin
      GuardedParseDotEnvFileContents(TFile.ReadAllText(FullPathName, fOptions.FileEncoding));
    end;
  end;

  GuardedSetSystemEnvironmentVariables;
end;


procedure XPlatSetEnvironmentVariable(const AName, AValue:string);
{$IFDEF POSIX}
var
  s1, s2:RawByteString;
  {$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  SetEnvironmentVariable(PChar(AName), PChar(AValue));
  {$ENDIF}
  {$IFDEF POSIX}
  s1 := TFDEncoder.Enco(AName, ecUTF8);
  s2 := TFDEncoder.Enco(AValue, ecUTF8);
  setenv(MarshaledAString(PByte(s1)), MarshaledAString(PByte(s2)), 1);
  {$ENDIF}
end;


procedure TDotEnv.GuardedSetSystemEnvironmentVariables;
var
  KeyPair:TStringKeyValue;
  KeyPairArray:TArray<TStringKeyValue>;
  SetVar:Boolean;
  CurrentValue:string;
begin
  if fOptions.SetOption = TSetOption.NeverSet then
    Exit;

  KeyPairArray := fMap.ToArray;
  for KeyPair in KeyPairArray do
  begin
    SetVar := True;
    if fOptions.SetOption = TSetOption.DoNotOvewrite then
    begin
      CurrentValue := GetEnvironmentVariable(KeyPair.Key);
      SetVar := CurrentValue.Trim.IsEmpty;
    end;
    if SetVar then
    begin
      XPlatSetEnvironmentVariable(KeyPair.Key, KeyPair.Value);
      Log(Format('SET: %s=%s', [KeyPair.Key, KeyPair.Value]));
    end
  end;
end;


// todo: Create enhanced parser  (embedded vars, inline comments)
procedure TDotEnv.GuardedParseDotEnvFileContents(const Contents:string);
var
  sl:TStringList;
  i:Integer;
  KeyName:string;
  KeyValue:string;
begin
  sl := TStringList.Create;
  try
    sl.Text := Contents;
    for i := 0 to sl.Count - 1 do
    begin
      KeyName := sl.Names[i].Trim;
      if (not KeyName.IsEmpty) and (not KeyName.StartsWith('#')) then
      begin
        KeyName := FormattedKeyName(KeyName, fOptions.EnvVarOptions.KeyNameCaseOption);
        KeyValue := FormattedKeyValue(sl.ValueFromIndex[i], fOptions.EnvVarOptions.KeyValueTrimOption);
        fMap.AddOrSetValue(KeyName, KeyValue);
      end;
    end;
  finally
    sl.Free;
  end;
end;


initialization

LoadGuard := TObject.Create;
{$IFDEF radDotEnv_SINGLETON}
DotEnv := NewDotEnv;
{$IFEND}

finalization

LoadGuard.Free;


end.
