// DotEnv file (.env) support for Delphi
// Copyright 2024 Darian Miller, Licensed under Apache-2.0
// SPDX-License-Identifier: Apache-2.0
// More info: https://github.com/radprogrammer/rad-dotenv
unit radDotEnv;


interface

// Compiler define option to disable the creation of a singleton DotEnv variable during initialization if desired
{.$DEFINE radDotEnv_DisableSingleton }

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Types;

type

  {$REGION Support Types}
  TStringKeyValue = TPair<string, string>;
  TLogProc = procedure(const Msg:string) of object;

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
    SupportSubstutionOnlyInDoubleQuotedValues,
    SupportSubstitutionExceptInSingleQuotes,   //DoubleQuoted or Unquoted support
    VariableSubstutionNotSupported);

  TEnvVarOptions = record
    RetrieveOption:TRetrieveOption;
    KeyNameCaseOption:TKeyNameCaseOption;
    EscapeSequenceInterpolationOption:TEscapeSequenceInterpolationOption;
    VariableSubstitutionOption:TVariableSubstitutionOption;
  end;


  // Note: this option is n/a when using the "OnlyFromSys" Retrieve Option as no need to set System Environment Variables when only source is System
  TSetOption = (
    /// <summary> After DotEnv file parsing is completed, always set system environment variables based on DotEnv values.</summary>
    /// <remarks> DotEnv files take priority over (and replace) system variables. Useful for interop with older code that only reads system environment variables)</remarks>
    AlwaysSet,
    /// <summary> After DotEnv file parsing is completed, set system environment variables based on DotEnv values only for system environment variables that have no value</summary>
    /// <remarks> System variables take priority over DotEnv files</remarks>
    DoNotOvewrite,
    /// <summary> After DotEnv file parsing is completed, do not set system environment variables based on DotEnv values</summary>
    /// <remarks> Only retrieve values from DotEnv files</remarks>
    NeverSet);


  TDotEnvOptions = record
  const
    defEnvFilename:string = '.env';
    defKeyNameCaseOption:TKeyNameCaseOption = TKeyNameCaseOption.AlwaysToUpperInvariant;
    defRetrieveOption:TRetrieveOption = TRetrieveOption.PreferDotEnv;
    defSetOption:TSetOption = TSetOption.AlwaysSet;
    defEscapeSequenceInterpolationOption = TEscapeSequenceInterpolationOption.SupportEscapesInDoubleQuotedValues;
    defVariableSubstitutionOption = TVariableSubstitutionOption.SupportSubstutionOnlyInDoubleQuotedValues;
  public
    EnvVarOptions:TEnvVarOptions;
    SetOption:TSetOption;
    EnvFileName:string;
    EnvSearchPaths:TArray<string>;
    FileEncoding:TEncoding;
    LogProc:TLogProc;
    class function DefaultOptions:TDotEnvOptions; static;
  end;
  {$ENDREGION}


  iDotEnv = interface
    ['{23318557-DA37-4030-B393-05EBC885E84C}']
    function Get(const KeyName:string; const DefaultKeyValue:string = ''):string; overload;
    function Get(const KeyName:string; const DefaultKeyValue:string; const EnvVarOptions:TEnvVarOptions):string; overload;

    function TryGet(const KeyName:string; out KeyValue:string):Boolean; overload;
    function TryGet(const KeyName:string; out KeyValue:string; const EnvVarOptions:TEnvVarOptions):Boolean; overload;

    function ToArray:TArray<TStringKeyValue>;

    {$REGION Optional usage for functional style initialization}
    function UseKeyNameCaseOption(const KeyNameCaseOption:TKeyNameCaseOption):iDotEnv;
    function UseRetrieveOption(const RetrieveOption:TRetrieveOption):iDotEnv;
    function UseSetOption(const SetOption:TSetOption):iDotEnv;
    function UseEscapeSequenceInterpolationOption(const EscapeSequenceInterpolationOption:TEscapeSequenceInterpolationOption):iDotEnv;
    function UseVariableSubstitutionOption(const VariableSubstitutionOption:TVariableSubstitutionOption):iDotEnv;
    function UseEnvFileName(const EnvFileName:string):iDotEnv;
    function UseEnvSearchPaths(const EnvSearchPaths:TArray<string>):iDotEnv;
    function UseFileEncoding(const FileEncoding:TEncoding):iDotEnv;
    function UseLogProc(const LogProc:TLogProc):iDotEnv;
    function Load:iDotEnv;
    function LoadFromString(const DotEnvContents:string):iDotEnv;
    {$ENDREGION}
  end;


function NewDotEnv:iDotEnv; overload;
function NewDotEnv(const Options:TDotEnvOptions):iDotEnv; overload;


{$IFNDEF radDotEnv_DisableSingleton}
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
    fNameValueMap:TNameValueMap;
    fKeyQuoteMap:TDictionary<string, Char>;
    fOptions:TDotEnvOptions;
    procedure EnsureLoaded(const DotEnvSource:TDotEnvSource; const Contents:string='');
    procedure GuardedSearchFiles;
    procedure GuardedSetSystemEnvironmentVariables;
    procedure GuardedParseDotEnvFileContents(const Contents:string);
    procedure GuardedDelayedVariableSubstitution;
  strict protected
    procedure Log(const msg:string);
    procedure AddKeyPair(const KeyName:string; const KeyValue:string; const WhichQuotedValue:Char=#0);
    function FormattedKeyName(const KeyName:string; const KeyNameCaseOption:TKeyNameCaseOption):string;

    function TryGetFromDotEnv(const StdKeyName:string; out KeyValue:string):Boolean;
    function TryGetFromSys(const StdKeyName:string; out KeyValue:string):Boolean;

    function IsValidKeyNameChar(C:Char; IsFirstChar:Boolean):Boolean;
  public
    constructor Create(const Options:TDotEnvOptions);
    destructor Destroy; override;

    function Get(const KeyName:string; const DefaultKeyValue:string = ''):string; overload;
    function Get(const KeyName:string; const DefaultKeyValue:string; const EnvVarOptions:TEnvVarOptions):string; overload;

    function TryGet(const KeyName:string; out KeyValue:string):Boolean; overload;
    function TryGet(const KeyName:string; out KeyValue:string; const EnvVarOptions:TEnvVarOptions):Boolean; overload;

    function ToArray:TArray<TStringKeyValue>;

    {$REGION Optional usage for functional style initialization}
    function UseKeyNameCaseOption(const KeyNameCaseOption:TKeyNameCaseOption):iDotEnv;
    function UseRetrieveOption(const RetrieveOption:TRetrieveOption):iDotEnv;
    function UseSetOption(const SetOption:TSetOption):iDotEnv;
    function UseEscapeSequenceInterpolationOption(const EscapeSequenceInterpolationOption:TEscapeSequenceInterpolationOption):iDotEnv;
    function UseVariableSubstitutionOption(const VariableSubstitutionOption:TVariableSubstitutionOption):iDotEnv;
    function UseEnvFileName(const EnvFileName:string):iDotEnv;
    function UseEnvSearchPaths(const EnvSearchPaths:TArray<string>):iDotEnv;
    function UseLogProc(const LogProc:TLogProc):iDotEnv;
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


constructor TDotEnv.Create(const Options:TDotEnvOptions);
begin
  inherited Create;
  fOptions := Options;
  fNameValueMap := nil;
  fKeyQuoteMap := nil;
end;


destructor TDotEnv.Destroy;
begin
  fKeyQuoteMap.Free;
  fNameValueMap.Free;
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


function TDotEnv.UseLogProc(const LogProc:TLogProc):iDotEnv;
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


function TDotEnv.ToArray:TArray<TStringKeyValue>;
begin
  if Assigned(fNameValueMap) then
  begin
    Result := fNameValueMap.ToArray;
  end
  else
  begin
    Result := nil;
  end;
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


  function UnescapeString(const Input:string):string;
  var
    Src, Dst:PChar;
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
    SetLength(Result, Len);
    Src := PChar(Input);
    Dst := PChar(Result);

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

    SetLength(Result, Dst - PChar(Result));
    Result := Result;
  end;


var
  InterpolatedValue:string;
  NormalizedKeyName:string;
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

  NormalizedKeyName := FormattedKeyName(KeyName, fOptions.EnvVarOptions.KeyNameCaseOption);

  fKeyQuoteMap.AddOrSetValue(NormalizedKeyName, WhichQuotedValue);
  fNameValueMap.AddOrSetValue(NormalizedKeyName, InterpolatedValue);
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
  if not Assigned(fNameValueMap) then
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

  //toconsider: support variable substitution on load only, or also on Key value retrieval?  If also here on Key value retrieval, prevent loop condition
end;


function TDotEnv.TryGetFromDotEnv(const StdKeyName:string; out KeyValue:string):Boolean;
begin
  Result := fNameValueMap.TryGetValue(StdKeyName, KeyValue);
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
    if not Assigned(fNameValueMap) then
    begin
      fNameValueMap := TNameValueMap.Create;
      fKeyQuoteMap := TDictionary<string, Char>.Create;
    end;

    if DotEnvSource = TDotEnvSource.FromFile then
    begin
      GuardedSearchFiles;
    end
    else
    begin
      GuardedParseDotEnvFileContents(Contents);
    end;

    GuardedDelayedVariableSubstitution;

    GuardedSetSystemEnvironmentVariables;
  finally
    TMonitor.Exit(LoadGuard);
  end;
end;



function TDotEnv.IsValidKeyNameChar(C:Char; IsFirstChar:Boolean):Boolean;
begin
  if IsFirstChar then
    Result := CharInSet(C, ['A'..'Z', 'a'..'z', '_'])  // First character: only a letter or underscore allowed
  else
    Result := CharInSet(C, ['A'..'Z', 'a'..'z', '_', '0'..'9']);   // Subsequent characters: letter, digit, or underscore
end;


procedure TDotEnv.GuardedDelayedVariableSubstitution;

  // [Data][${VAR[-[defaul]]}][DATA][EOL]
  function ResolveEmbeddedVariables(const Input:string; var NumberOfTokensReplaced:Integer):string;  //Replaces regex matching https://github.com/radprogrammer/rad-dotenv/issues/10
  type
    TParseState = (StartNewBlockOfText, StartPossibleVariableName, CollectPossibleVariableNameChars, CollectPossibleDefaultValueChars);
  var
    P, PossibleVarNameStart, PossibleVarNameEnd, PossibleDefaultValueStart:PChar;
    VarName, DefaultValue, Value:string;
    State:TParseState;
  begin
    Result := '';
    NumberOfTokensReplaced := 0;

    PossibleDefaultValueStart := nil;
    PossibleVarNameStart := nil;
    PossibleVarNameEnd := nil;

    P := PChar(Input);
    State := StartNewBlockOfText;
    while P^ <> #0 do
    begin
      case State of

        StartNewBlockOfText:
          begin
            if (P^ = '$') and ((P + 1)^ = '{') then // Entering a potential token
            begin
              Inc(P, 2);  // Skip "${"
              State := StartPossibleVariableName;
              PossibleVarNameEnd := nil;
              PossibleVarNameStart := P;
            end
            else  // Collect all non-tokenized text
            begin
              Result := Result + P^;
              Inc(P);
            end;
          end;


        StartPossibleVariableName:
          begin
            if IsValidKeyNameChar(P^, {IsFirstChar=}True) then
            begin
              PossibleVarNameStart := P;
              State := CollectPossibleVariableNameChars;
            end
            else  // could have been a token, but wasn't because the key name is invalid, treat as normal text
            begin
              Result := Result + '${' + Copy(PossibleVarNameStart, 0, P - PossibleVarNameStart + 1);
              Inc(P);
              State := StartNewBlockOfText;
            end;
          end;


        CollectPossibleVariableNameChars:
          begin
            if IsValidKeyNameChar(P^, {IsFirstChar=}False) then  // Accumulate valid variable name characters
            begin
              PossibleVarNameEnd := P;
              Inc(P);
            end
            else if P^ = '-' then // Start parsing default value after '-'
            begin
              State := CollectPossibleDefaultValueChars;
              Inc(P);
              PossibleDefaultValueStart := P;
            end
            else if P^ = '}' then  // Close variable expression, no default value
            begin
              { Replace A Valid Token }
              Inc(NumberOfTokensReplaced);

              SetString(VarName, PossibleVarNameStart, P-PossibleVarNameStart);
              Result := Result + Get(VarName);  //todo: VarSubstitutionTokenNotFoundOption   ReplaceTokenWithBlankValue, LeaveTokenAsIs
              //Result := Result + '${' + VarName + '}';
              Inc(P);  // Skip '}'
              State := StartNewBlockOfText;  // Go back to normal text processing
            end
            else  // could have been a token, but wasn't because the key name is invalid, treat as normal text
            begin
              Result := Result + '${' + Copy(PossibleVarNameStart, 0, P - PossibleVarNameStart + 1);
              Inc(P);
              State := StartNewBlockOfText;
            end;
          end;


        CollectPossibleDefaultValueChars:
          begin
            if P^ = '}' then  // Close variable expression with a default value specified
            begin
              { Replace A Valid Token }
              Inc(NumberOfTokensReplaced);

              SetString(VarName, PossibleVarNameStart, PossibleVarNameEnd-PossibleVarNameStart);
              SetString(DefaultValue, PossibleDefaultValueStart, P-PossibleDefaultValueStart);
              Value := Get(VarName);
              if Value.IsEmpty then
                Value := DefaultValue;

              Result := Result + Value;  //todo: VarSubstitutionTokenNotFoundOption   ReplaceTokenWithBlankValue, LeaveTokenAsIs
              Inc(P);  // Skip '}'
              State := StartNewBlockOfText;
            end
            else // Accumulate default value characters
            begin
              Inc(P);
            end;
          end;
      end;
    end;


    if NumberOfTokensReplaced = 0 then Exit(Input);

    if State <> StartNewBlockOfText then
    begin
      // Append any remaining text that was under consideration as a possible token
      if not (PossibleVarNameStart = nil) then
      begin
        Result := Result + '${' + Copy(PossibleVarNameStart, 0, P - PossibleVarNameStart + 1);
      end;
    end;

  end;


var
  KeyName:string;
  Value, InterpolatedValue:string;
  WhichQuoteType:Char;
  NumberOfTokensReplaced:Integer;
begin
  if not (fOptions.EnvVarOptions.VariableSubstitutionOption = TVariableSubstitutionOption.VariableSubstutionNotSupported) then
  begin
    Assert(fOptions.EnvVarOptions.VariableSubstitutionOption in [TVariableSubstitutionOption.SupportSubstitutionExceptInSingleQuotes, TVariableSubstitutionOption.SupportSubstutionOnlyInDoubleQuotedValues], 'Unhandled TVariableSubstitutionOption');

    for KeyName in fNameValueMap.Keys do
    begin
      if fKeyQuoteMap.TryGetValue(KeyName, WhichQuoteType) then
      begin
        //variable substitution doesn't ever happen in Single Quoted values
        if WhichQuoteType = TDotEnv.SingleQuotedChar then Continue;

        if (WhichQuoteType = TDotEnv.DoubleQuotedChar) or (fOptions.EnvVarOptions.VariableSubstitutionOption = SupportSubstitutionExceptInSingleQuotes) then
        begin
          if fNameValueMap.TryGetValue(KeyName, Value) then
          begin
            InterpolatedValue := ResolveEmbeddedVariables(Value, NumberOfTokensReplaced);
            if NumberOfTokensReplaced > 0 then
            begin
              fNameValueMap.AddOrSetValue(KeyName, InterpolatedValue);
            end;
          end;
        end;
      end;
    end;

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

  KeyPairArray := fNameValueMap.ToArray;
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
            if Start=Current then //Junk:  The line starts with =, ignore it
            begin
              Inc(Current);
              State := StateIgnoreRestOfLine;
            end
            else
            begin
              SetString(Key, Start, Current-Start);
              State := StateFirstValueChar;
              Inc(Current);
              Start := Current;
            end;
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
            SetString(Value, Start, Current-Start);
            AddKeyPair(Key, Value);
            Inc(Current);
            SetNormalState;
          end
          else if Current^ = '#' then  //inline comment starting, grab current unquoted value, ignore rest of line
          begin
            SetString(Value, Start, Current-Start);
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
              SetString(Value, Start+1, Current-Start-1);
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

  if State = StateUnquotedValue then
  begin
    SetString(Value, Start, Current-Start);
    AddKeyPair(Key, Value);
  end;
end;


initialization

LoadGuard := TObject.Create;

{$IFNDEF radDotEnv_DisableSingleton}
DotEnv := NewDotEnv.Load;
{$IFEND}

finalization

LoadGuard.Free;


end.
