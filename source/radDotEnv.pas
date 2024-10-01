// DotEnv file (.env) support for Delphi
// Copyright 2024 Darian Miller, Licensed under Apache-2.0
// SPDX-License-Identifier: Apache-2.0
// More info: https://github.com/radprogrammer/rad-dotenv
unit radDotEnv;


interface

// Compiler define option to create a singleton DotEnv variable during initialization for ease of use
{.$DEFINE radDotEnv_SINGLETON }

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


  TRetrieveOption = (
    /// <summary> Try getting variable from DotEnv values, and if not found, try getting from system environment</summary>
    PreferDotEnv,
    /// <summary> Try getting from system environment, and if not found, try from DotEnv values</summary>
    PreferSys,
    /// <summary> Only access system environment variable values (do not use DotEnv values)</summary>
    /// <remarks> Some production systems never want to use DotEnv files and only utilize orchestrated system values/remarks>
    OnlyFromSys,
    /// <summary> Only get variable from DotEnv values (do not access system environment variables)</summary>
    OnlyFromDotEnv);


  TEscapeSequenceInterpolationOption = (
    SupportEscapesInDoubleQuotedValues,
    EscapeSequencesNotSupported);

  TVariableSubstitutionOption = (
    SupportSubstutionInDoubleQuotedValues,
    VariableSubstutionNotSupported);

  TEnvVarOptions = record
    RetrieveOption:TRetrieveOption;
    KeyNameCaseOption:TKeyNameCaseOption;
    EscapeSequenceInterpolationOption:TEscapeSequenceInterpolationOption;
    VariableSubstitutionOption:TVariableSubstitutionOption;
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
    defRetrieveOption:TRetrieveOption = TRetrieveOption.PreferDotEnv;
    defSetOption:TSetOption = TSetOption.DoNotOvewrite;
    defEscapeSequenceInterpolationOption = TEscapeSequenceInterpolationOption.SupportEscapesInDoubleQuotedValues;
    defVariableSubstitutionOption = TVariableSubstitutionOption.SupportSubstutionInDoubleQuotedValues;
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
    function UseRetrieveOption(const RetrieveOption:TRetrieveOption):iDotEnv;
    function UseSetOption(const SetOption:TSetOption):iDotEnv;
    function UseEscapeSequenceInterpolationOption(const EscapeSequenceInterpolationOption:TEscapeSequenceInterpolationOption):iDotEnv;
    function UseVariableSubstitutionOption(const VariableSubstitutionOption:TVariableSubstitutionOption):iDotEnv;
    function UseEnvFileName(const EnvFileName:string):iDotEnv;
    function UseEnvSearchPaths(const EnvSearchPaths:TArray<string>):iDotEnv;
    function UseFileEncoding(const FileEncoding:TEncoding):iDotEnv;
    function UseLogProc(const LogProc:TProc<string>):iDotEnv;
    function Load:iDotEnv;
    function LoadFromString(const DotEnvContents:string):iDotEnv;
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
  System.IOUtils,
  System.RegularExpressions;

var
  LoadGuard:TObject;

type
  TNameValueMap = TDictionary<string, string>; // Add + 1 to: https://embt.atlassian.net/servicedesk/customer/portal/1/RSS-1862
  TStringKeyValue = TPair<string, string>;
  TDotEnvSource = (FromFile, FromString);


  TDotEnv = class(TInterfacedObject, iDotEnv)
  private const
    LogPrefix = '(dotenv) ';
    SingleQuotedChar = '''';
    DoubleQuotedChar = '"';
    EscapeChar = '\';
    KeyNameRegexPattern = '([a-zA-Z_]+[a-zA-Z0-9_]*)';
    DefaultValueRegex = '-([^}]*)';
  strict private
    fMap:TNameValueMap;
    fOptions:TDotEnvOptions;
    procedure EnsureLoaded(const DotEnvSource:TDotEnvSource; const Contents:string='');
    procedure GuardedSearchFiles;
    procedure GuardedSetSystemEnvironmentVariables;
    procedure GuardedParseDotEnvFileContents(const Contents:string);
  strict protected
    procedure Log(const msg:string);

    procedure AddKeyPair(const KeyName:string; const KeyValue:string; const WhichQuotedValue:Char=#0);
    function FormattedKeyName(const KeyName:string; const KeyNameCaseOption:TKeyNameCaseOption):string;

    function TryGetFromDotEnv(const StdKeyName:string; out KeyValue:string):Boolean;
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
    function UseRetrieveOption(const RetrieveOption:TRetrieveOption):iDotEnv;
    function UseSetOption(const SetOption:TSetOption):iDotEnv;
    function UseEscapeSequenceInterpolationOption(const EscapeSequenceInterpolationOption:TEscapeSequenceInterpolationOption):iDotEnv;
    function UseVariableSubstitutionOption(const VariableSubstitutionOption:TVariableSubstitutionOption):iDotEnv;
    function UseEnvFileName(const EnvFileName:string):iDotEnv;
    function UseEnvSearchPaths(const EnvSearchPaths:TArray<string>):iDotEnv;
    function UseLogProc(const LogProc:TProc<string>):iDotEnv;
    function UseFileEncoding(const FileEncoding:TEncoding):iDotEnv;
    function Load:iDotEnv;
    function LoadFromString(const DotEnvContents:string):iDotEnv;
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
  Result.EnvVarOptions.RetrieveOption := defRetrieveOption;
  Result.EnvVarOptions.EscapeSequenceInterpolationOption := defEscapeSequenceInterpolationOption;
  Result.EnvVarOptions.VariableSubstitutionOption := defVariableSubstitutionOption;
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
  fMap := nil;
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


function TDotEnv.UseEscapeSequenceInterpolationOption(const EscapeSequenceInterpolationOption:TEscapeSequenceInterpolationOption):iDotEnv;
begin
  fOptions.EnvVarOptions.EscapeSequenceInterpolationOption := EscapeSequenceInterpolationOption;
  Result := self;
end;


function TDotEnv.UseVariableSubstitutionOption(const VariableSubstitutionOption:TVariableSubstitutionOption):iDotEnv;
begin
  fOptions.EnvVarOptions.VariableSubstitutionOption := VariableSubstitutionOption;
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
  self.EnsureLoaded(TDotEnvSource.FromFile);
  Result := self;
end;

function TDotEnv.LoadFromString(const DotEnvContents:string):iDotEnv;
begin
  self.EnsureLoaded(TDotEnvSource.FromString, DotEnvContents);
  Result := Self;
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


procedure TDotEnv.AddKeyPair(const KeyName:string; const KeyValue:string; const WhichQuotedValue:Char=#0);


  function ResolveEmbeddedVariables(const Input:string):string;
  var
    Regex:TRegEx;
    Match:TMatch;
    VarName, ResolvedValue, DefaultValue:string;
  begin
    Result := Input;

    RegEx := TRegEx.Create('\$\{' + TDotEnv.KeyNameRegexPattern + '\}' + '|' +
                           '\$\{' + TDotEnv.KeyNameRegexPattern + DefaultValueRegex + '\}');
    Match := Regex.Match(Result);
    while Match.Success do
    begin

      VarName := Match.Groups[1].Value;
      DefaultValue := '';
      if (Match.Groups[1].Success) and (Match.Groups.Count > 2) and Match.Groups[3].Success then //${KEY-default} found, extract default value
      begin
        DefaultValue := Match.Groups[3].Value;
      end;

      if not TryGet(VarName, ResolvedValue) then
        ResolvedValue := DefaultValue;

      Result := StringReplace(Result, Match.Value, ResolvedValue, []);
      Match := Match.NextMatch;
    end;
  end;

  function UnescapeString(const Input:string):string;
  var
    Src, Dst:PChar;
    Output:string;
    Ch:Char;
    Len:Integer;

    function GetEscapedChar(var P:PChar):Char;
    begin
      Inc(P); // Skip the backslash
      case P^ of
        'n': // Line feed
          Result := #10;
        't': // Tab
          Result := #9;
        'r': // Carriage return
          Result := #13;
        EscapeChar:
          Result := EscapeChar;
        '"':
          Result := '"';
        '''':
          Result := '''';
      else
        Result := P^;  //unknown, as-is
      end;
      Inc(P);
    end;


  begin
    Len := Length(Input);
    SetLength(Output, Len);
    Src := PChar(Input);
    Dst := PChar(Output);

    while Src^ <> #0 do
    begin
      if Src^ = EscapeChar then
      begin
        Ch := GetEscapedChar(Src);
        Dst^ := Ch;
      end
      else
      begin
        Dst^ := Src^;
        Inc(Src);
      end;
      Inc(Dst);
    end;

    SetLength(Output, Dst - PChar(Output));
    Result := Output;
  end;


var
  InterpolatedValue:string;
begin
  if WhichQuotedValue = #0 then
  begin
    InterpolatedValue := KeyValue.Trim;  //Unquoted values are always trimmed
  end
  else
  begin
    InterpolatedValue := KeyValue;  //Quoted values keep spacing  Key=" value "
  end;

  if not (fOptions.EnvVarOptions.EscapeSequenceInterpolationOption = TEscapeSequenceInterpolationOption.EscapeSequencesNotSupported) then
  begin
    if (WhichQuotedValue = TDotEnv.DoubleQuotedChar) and (fOptions.EnvVarOptions.EscapeSequenceInterpolationOption = TEscapeSequenceInterpolationOption.SupportEscapesInDoubleQuotedValues) then
    begin
      InterpolatedValue := UnescapeString(InterpolatedValue);
    end;
  end;

  if not (fOptions.EnvVarOptions.VariableSubstitutionOption = TVariableSubstitutionOption.VariableSubstutionNotSupported) then
  begin
    if (WhichQuotedValue = TDotEnv.DoubleQuotedChar) and (fOptions.EnvVarOptions.VariableSubstitutionOption = TVariableSubstitutionOption.SupportSubstutionInDoubleQuotedValues) then
    begin
      InterpolatedValue := ResolveEmbeddedVariables(InterpolatedValue);
    end;
  end;

  fMap.AddOrSetValue(FormattedKeyName(KeyName, fOptions.EnvVarOptions.KeyNameCaseOption), InterpolatedValue);
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
    EnsureLoaded(TDotEnvSource.FromFile);
  end;

  StdKeyName := FormattedKeyName(KeyName, EnvVarOptions.KeyNameCaseOption);

  case EnvVarOptions.RetrieveOption of
    TRetrieveOption.OnlyFromDotEnv:
      Result := TryGetFromDotEnv(StdKeyName, KeyValue);
    TRetrieveOption.OnlyFromSys:
      Result := TryGetFromSys(StdKeyName, KeyValue);
    TRetrieveOption.PreferSys:
      Result := TryGetFromSys(StdKeyName, KeyValue) or TryGetFromDotEnv(StdKeyName, KeyValue);
  else { PreferDotEnv }
    Assert(EnvVarOptions.RetrieveOption = TRetrieveOption.PreferDotEnv, Format('Unknown RetrieveOption (%d) in TDotEnv.TryGet', [Ord(EnvVarOptions.RetrieveOption)]));
    Result := TryGetFromDotEnv(StdKeyName, KeyValue) or TryGetFromSys(StdKeyName, KeyValue);
  end;

end;


function TDotEnv.TryGetFromDotEnv(const StdKeyName:string; out KeyValue:string):Boolean;
begin
  Result := fMap.TryGetValue(StdKeyName, KeyValue);
end;


function TDotEnv.TryGetFromSys(const StdKeyName:string; out KeyValue:string):Boolean;
begin
  KeyValue := GetEnvironmentVariable(StdKeyName);
  Result := not KeyValue.Trim.IsEmpty;
end;


procedure TDotEnv.EnsureLoaded(const DotEnvSource:TDotEnvSource; const Contents:string='');

begin
  TMonitor.Enter(LoadGuard);
  try
    if not Assigned(fMap) then
    begin
      fMap := TNameValueMap.Create;
    end;

    if DotEnvSource = TDotEnvSource.FromFile then
    begin
      GuardedSearchFiles;
    end
    else
    begin
      GuardedParseDotEnvFileContents(Contents);
    end;

    GuardedSetSystemEnvironmentVariables;
  finally
    TMonitor.Exit(LoadGuard);
  end;
end;


procedure TDotEnv.GuardedSearchFiles;
var
  SearchPath:string;
  FullPathName:string;
  Contents:string;
begin
  for SearchPath in fOptions.EnvSearchPaths do
  begin
    FullPathName := TPath.Combine(SearchPath, fOptions.EnvFileName);
    if TFile.Exists(FullPathName) then
    begin
      try
        Contents := TFile.ReadAllText(FullPathName, fOptions.FileEncoding);
      except on E: Exception do
        begin
          Log(Format('Failed to load DotEnv file %s, exception: %s', [FullPathName, E.Message]));
          Exit;
        end;
      end;
      GuardedParseDotEnvFileContents(Contents);
    end;
  end;
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
    SetVar := True; //TSetOption.AlwaysSet
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


procedure TDotEnv.GuardedParseDotEnvFileContents(const Contents:string);
type
  TEnvState = (StateNormal, StateKey, StateFirstValueChar, StateUnquotedValue, StateQuotedValue, StateIgnoreRestOfLine);

var
  Start, Current:PChar;
  State:TEnvState;
  Key, Value:string;
  WhichQuotedValue:Char;
  EscapePair:Boolean;

  procedure SetNormalState;
  begin
    State := StateNormal;
    Key := '';
    Value := '';
    WhichQuotedValue := #0;
    Start := Current;
    EscapePair := False;
  end;

begin
  if Contents = '' then
    Exit;

  Start := PChar(Contents);
  Current := Start;
  SetNormalState;
  while Current^ <> #0 do
  begin
    case State of
      StateNormal:
        begin
          if CharInSet(Current^, [#10, #13, #32, #9]) then
          begin
            Inc(Current);
            Continue;
          end;
          if Current^ = '#' then
          begin
            Inc(Current);
            State := StateIgnoreRestOfLine;
          end
          else
          begin
            Start := Current;
            State := StateKey;
          end;
        end;

      StateKey:
        begin
          if (Current^ = '=') then   {//toconsider: Option to allow "Key Value" pairs?     or CharInSet(Current^, [#32, #9]) then}
          begin
            Key := Copy(Start, 1, Current-Start);
            State := StateFirstValueChar;
            Inc(Current);
            Start := Current;
          end
          else if CharInSet(Current^, [#10, #13]) then  // A key was started but no = found to set a value before end of line, so it gets ignored
          begin
            Inc(Current);
            SetNormalState;
          end
          else
          begin
            Inc(Current);
          end;
        end;

      StateFirstValueChar:
        begin
          if CharInSet(Current^, [TDotEnv.DoubleQuotedChar, TDotEnv.SingleQuotedChar]) then  //start quoted value
          begin
            State := StateQuotedValue;
            WhichQuotedValue := Current^;
            Start := Current;
            Inc(Current);
          end
          else if CharInSet(Current^, [#10, #13]) then  //unquoted value ends with end of line characters
          begin
            Value := Copy(Start, 1, Current-Start);
            AddKeyPair(Key, Value);
            Inc(Current);
            SetNormalState;
          end
          else if Current^ = '#' then  //inline comment starting, grab current unquoted value, ignore rest of line
          begin
            Value := Copy(Start, 1, Current-Start);
            AddKeyPair(Key, Value);
            State := StateIgnoreRestOfLine;
          end
          else
          begin
            State := StateUnquotedValue;  //minor optimization/logic improvement - skip CharInSet for quoted check as we shouldn't start a new QuotedValue while collecting an unquoted value
            Inc(Current);
          end;
        end;

      StateUnquotedValue:
        begin
          if CharInSet(Current^, [#10, #13]) then  //unquoted value ends with end of line characters
          begin
            Value := Copy(Start, 1, Current-Start);
            AddKeyPair(Key, Value);
            Inc(Current);
            SetNormalState;
          end
          else if Current^ = '#' then  //inline comment starting, grab current unquoted value, ignore rest of line
          begin
            Value := Copy(Start, 1, Current-Start);
            AddKeyPair(Key, Value);
            State := StateIgnoreRestOfLine;
          end
          else
          begin
            Inc(Current);
          end;
        end;

      StateQuotedValue:
        begin
          if Current^ = WhichQuotedValue then //includes all characters (including end-of-line chars) for multi-line quoted values
          begin
            if (WhichQuotedValue = TDotEnv.DoubleQuotedChar)
               and (fOptions.EnvVarOptions.EscapeSequenceInterpolationOption = TEscapeSequenceInterpolationOption.SupportEscapesInDoubleQuotedValues)
               and EscapePair then
            begin
              // This escaped double quote shouldn't end the value
              EscapePair := False;
              Inc(Current);
            end
            else
            begin
              Value := Copy(Start, 2, Current-Start-1);
              AddKeyPair(Key, Value, WhichQuotedValue);
              Inc(Current);
              State := StateIgnoreRestOfLine;
            end;
          end
          else
          begin
            EscapePair := (not EscapePair) and (Current^ = TDotEnv.EscapeChar);
            Inc(Current);
          end;
        end;

      StateIgnoreRestOfLine:
        begin
          Inc(Current);
          if CharInSet(Current^, [#10, #13]) then
          begin
            SetNormalState;
          end;
        end;
    end;
  end;

  if (not Trim(Key).IsEmpty) and (State = StateUnquotedValue) then
  begin
    AddKeyPair(Key, Start);
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
