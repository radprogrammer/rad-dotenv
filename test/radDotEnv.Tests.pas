// DotEnv file (.env) support for Delphi
// More info: https://github.com/radprogrammer/rad-dotenv
unit radDotEnv.Tests;

interface

uses
  DUnitX.TestFramework,
  radDotEnv;

const
  //Also used by radDotEnv.TestFileGenerator project
  LargeGeneratedTestFileName = '.env.large';
  LargeVariableCount = 5000;


type
  [TestFixture]
  TTestDotEnv = class
  private
    fDotEnv:iDotEnv;
  public

  [SetUp]
  procedure SetUp;

  [TearDown]
  procedure TearDown;

    [TestCase('UnquotedValue', 'key=value,key,value')]
    [TestCase('UnquotedValueLeftTrimmed', 'key= value,key,value')]
    [TestCase('UnquotedValueRightTrimmed', 'key=value ,key,value')]
    [TestCase('UnquotedValueTrimmed', 'key= value ,key,value')]
    [TestCase('UnquotedValueWithEmbededDblQuoteMaintained', 'key=value"keep,key,value"keep')]  //arguably incorrect value format, but be generous on input
    [TestCase('UnquotedValueWithEmbededQuoteMaintained', 'key=value''keep,key,value''keep')]   //arguably incorrect value format, but be generous on input
    [TestCase('UnquotedInvalidNoKey', 'key' + #13#10 + 'key2=value2,key2,value2')]
    [TestCase('UnquotedInvalidStartsEqual', '=x' + #13#10 + 'key2=value2,key2,value2')]

    [TestCase('ValueSingleChar', 'k=v,k,v')]
    [TestCase('ValueNumeric', '0=1,0,1')]
    [TestCase('ValueEmpty', 'key=,key,')]
    [TestCase('ValueAllSpaces', 'key=   ,key,')]

    [TestCase('ValueInlineComment', 'key=value #test,key,value')]
    [TestCase('SimpleKeyValueInlineComment2', 'key=value # test,key,value')]
    [TestCase('UnquotedValueWithWhiteSpaceAroundPound', 'key=value      #   #  test #,key,value')]
    [TestCase('UnquotedValueWithNoSpaceBeforePoundIsComment', 'key=value# is a comment,key,value')]  //differs from some implementations
    [TestCase('UnquotedValueWithSpaceBeforePoundIsComment', 'key= # is a comment,key,')]

    //differs from some implementations that throw exceptions on invalid keys
    [TestCase('NoEqualKeyIsDumped', 'key value,key,')]
    [TestCase('NoEqualKeyDumpedWithNextLineParsedOk', 'key value' + sLineBreak + 'key2=value2,key2,value2')]

    [TestCase('DoubleQuotedValue', 'key="value",key,value')]
    [TestCase('DoubleQuotedErrorValue', 'key="val"ue",key,val')]
    [TestCase('DoubleQuotedValueNotLeftTrimmed', 'key=" value",key, value')]
    [TestCase('DoubleQuotedValueNotRightTrimmed', 'key="value ",key,value ')]
    [TestCase('DoubleQuotedValueNotTrimmed', 'key=" value  ",key, value  ')]
    [TestCase('DoubleQuotedValueWithCommentCharacter', 'key="value#keep",key,value#keep')]
    [TestCase('DoubleQuotedValueWithSingleQuote', 'key="value''keep",key,value''keep')]

    [TestCase('SingleQuotedValue', 'key=''value'',key,value')]
    [TestCase('SingleQuotedErrorValue', 'key=''val''ue'',key,val')]
    [TestCase('SingleQuotedValueNotLeftTrimmed', 'key='' value'',key, value')]
    [TestCase('SingleQuotedValueNotRightTrimmed', 'key=''value '',key,value ')]
    [TestCase('SingleQuotedValueNotTrimmed', 'key='' value  '',key, value  ')]
    [TestCase('SingleQuotedValueWithCommentCharacter', 'key=''value#keep'',key,value#keep')]
    [TestCase('SingleQuotedValueWithDoubleQuote', 'key=''value"keep'',key,value"keep')]

    [TestCase('DoubleQuotedMultiLineValue', 'key="line1' + sLineBreak + ' Line2 #val ' + sLineBreak + '#Line3",key,line1' + sLineBreak + ' Line2 #val ' + sLineBreak + '#Line3')]
    [TestCase('DoubleQuotedNoEndingQuoteKeyIgnored', 'key="line1' + sLineBreak + ' Line2 #val ' + sLineBreak + '#Line3,key,')]
    [TestCase('SingleQuotedMultiLineValue', 'key=''line1' + sLineBreak + ' Line2 #val ' + sLineBreak + '#Line3'',key,line1' + sLineBreak + ' Line2 #val ' + sLineBreak + '#Line3')]
    [TestCase('SingleQuotedNoEndingQuoteKeyIgnored', 'key=''line1' + sLineBreak + ' Line2 #val ' + sLineBreak + '#Line3,key,')]

    //Note: Escape sequeneces supported by default via defEscapeSequenceInterpolationOption
    [TestCase('EscapedDoubleQuoted\n', 'key="value\n",key,value'+#10)]
    [TestCase('EscapedDoubleQuoted\r', 'key="value\r",key,value'+#13)]
    [TestCase('EscapedDoubleQuoted\t', 'key="value\t",key,value'+#9)]
    [TestCase('EscapedDoubleQuoted\''', 'key="value\''",key,value''')]
    [TestCase('EscapedDoubleQuoted\"', 'key="value\"",key,value"')]
    [TestCase('EscapedDoubleQuoted\\', 'key="value\\",key,value\')]
    [TestCase('EscapedDoubleQuoted\\\\', 'key="value\\\\",key,value\\')]
    [TestCase('EscapedDoubleQuoted\\\"', 'key="value\\\"",key,value\"')]
    [TestCase('EscapedDoubleQuoted\\\"\"', 'key="value\\\"\"",key,value\""')]
    [TestCase('EscapedDoubleQuotedNoEndingQuote', 'key="value\",key,')]
    [TestCase('EscapedDoubleQuotedInvalid\', 'key="value\X",key,valueX')]
    [TestCase('EscapedDoubleQuotedInvalid\NoNull', 'key="value\0",key,value0')]
    [TestCase('EscapedDoubleQuotedCRLF', 'key="Line1\r\nLine2",key,Line1' + #13#10 + 'Line2')]

    [TestCase('EscapedSingleQuoted\nAsIs', 'key=''value\n'',key,value\n')]
    [TestCase('EscapedSingleQuoted\rAsIs', 'key=''value\r'',key,value\r')]
    [TestCase('EscapedSingleQuoted\tAsIs', 'key=''value\t'',key,value\t')]
    [TestCase('EscapedSingleQuoted\''IsNoEndingQuote', 'key=''value\'''',key,value\')]
    [TestCase('EscapedSingleQuoted\"AsIs', 'key=''value\"'',key,value\"')]
    [TestCase('EscapedSingleQuoted\\AsIs', 'key=''value\\'',key,value\\')]
    procedure TestSingleKeyValue(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);


    [TestCase('VarOK_Basic',           'key1=value1' + sLineBreak + 'key2="${KEY1}"'       + ',key2,value1')]
    [TestCase('VarOK_DefaultValue',    'key1=value1' + sLineBreak + 'key2="${NOKEY-123}"'  + ',key2,123')]
    [TestCase('VarOK_EmptyDefault',    'key1=value1' + sLineBreak + 'key2="${NOKEY-}"'     + ',key2,')]
    [TestCase('VarOK_QuoteDefault',    'key1=value1' + sLineBreak + 'key2="${NOKEY-''}"'   + ',key2,''')]
    [TestCase('VarOK_EscDblQuoteDef',  'key1=value1' + sLineBreak + 'key2="${NOKEY-\"1}"'  + ',key2,"1')]
    [TestCase('VarErr_InvalidKeyName', 'key1=value1' + sLineBreak + 'key2="${KE Y1}"'      + ',key2,${KE Y1}')]
    [TestCase('VarErr_TokenNotEnded',  'key1=value1"' + sLineBreak + 'key2="${NoKey-123}${KEY2",key2,123${KEY2')]
    [TestCase('VarErr_EndDash',        'key1=value1' + sLineBreak + 'key2="${KEY1-"'       + ',key2,${KEY1-')]
    [TestCase('VarErr_EndDefDash',     'key1=value1' + sLineBreak + 'key2="${KEY1-123"'    + ',key2,${KEY1-123')]
    [TestCase('VarErr_EndDefBrace',    'key1=value1' + sLineBreak + 'key2="${KEY1-123${"'  + ',key2,${KEY1-123${')]
    [TestCase('VarNo_NoQuoteAsIs',     'key1=value1' + sLineBreak + 'key2=ValueFromKey1=${KEY1}.,key2,ValueFromKey1=${KEY1}.')]
    [TestCase('VarNo_SingleQuoteAsIs', 'key1=value1' + sLineBreak + 'key2=''ValueFromKey1=${KEY1}.'',key2,ValueFromKey1=${KEY1}.')]
    procedure TestVarSub(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);

    [Test]
    procedure TestVarSubDelay;

    [Test]
    procedure TestVarSubOption;

    const JUNK = '$@#$%{${invalid keyname}*{(*}{(}${(}${ }${(#@@!#';  //as long as } not paired with a preceding ${ with valid key in between then ignore all ${}
    [TestCase('AllJunk_NoVarDetected', 'key="' + JUNK + JUNK + '",key,' + JUNK + JUNK)]
    [TestCase('MostlyJunk_WithEmbeddedVar', 'key="' + JUNK + '${ActualVar}' + JUNK + '"' + sLineBreak + 'ActualVar=Value2,key,' + JUNK + 'Value2' + JUNK)]
    //this sort of data should be single-quoted to prevent erroneous variable substitution
    [TestCase('AllJunk_SingleQuoteIgnores', 'key=''' + JUNK + '${ActualVar-123}' + JUNK + '''' + sLineBreak + 'ActualVar=Value2,key,' + JUNK + '${ActualVar-123}' + JUNK)]
    //unquoted will truncate junk at first pound sign found
    [TestCase('AllJunk_NoQuoteTruncatesAtHash','key=' + JUNK + '${ActualVar-123}' + JUNK + sLineBreak + 'ActualVar=Value2,key,$@')]
    procedure TestVarSubJunk(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);


    [Test]
    procedure TestEscapeSequenceInterpolationOption;

    [TestCase('Junk_EmptyContent', '')]
    [TestCase('Junk_SingleWhiteSpace', ' ')]
    [TestCase('Junk_MultipleWhiteSpace', '   ')]
    [TestCase('Junk_MultipleWhiteSpaceEndOfLines1', #10 + ' ' + #13)]
    [TestCase('Junk_MultipleWhiteSpaceEndOfLines2', #13 + ' ' + #10)]
    [TestCase('Junk_MultipleWhiteSpaceEndOfLines3', #13 + '  ' + #10 + '  ')]
    [TestCase('Junk_MultipleWhiteSpaceEndOfLinesTab', #10 + ' ' + #13 + ' ' + #9)]
    [TestCase('Junk_OneCommentLine', '#')]
    [TestCase('Junk_TwoCommentLine', '# #')]
    [TestCase('Junk_ConsecutivePounds', '####')]
    [TestCase('Junk_TwoCommentLines', '#' + sLineBreak + '#')]
    [TestCase('Junk_CommentWhiteSpaceCommentLine', '#' + sLineBreak + '  ' + '#')]
    procedure TestNoExceptions(const Contents:String);

    // Also tests custom EnvFileName option
    // LargeFile created with radDotEnv.TestFileGenerator
    [Test]
    procedure TestLargeFile;


    [Test]
    procedure TestSetEnv;

    [Test]
    procedure TestCustomPath;

  end;

implementation
uses
  System.SysUtils,
  System.IOUtils;


procedure TTestDotEnv.SetUp;
begin
  fDotEnv := NewDotEnv
            .UseRetrieveOption(TRetrieveOption.OnlyFromDotEnv)
            .UseSetOption(TSetOption.NeverSet);
end;

procedure TTestDotEnv.TearDown;
begin
  fDotEnv := nil;
end;


procedure TTestDotEnv.TestSingleKeyValue(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);
begin
  fDotEnv.LoadFromString(Contents);
  Assert.AreEqual(ExpectedKeyValue, fDotEnv.Get(KeyName));
end;


procedure TTestDotEnv.TestLargeFile;
var
  i:integer;
  Expected,Actual:string;
begin
  Assert.IsTrue(TFile.Exists(TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), LargeGeneratedTestFileName)), LargeGeneratedTestFileName + ' file not found');

  fDotEnv := NewDotEnv
            .UseEnvFileName(LargeGeneratedTestFileName)
            .UseRetrieveOption(TRetrieveOption.OnlyFromDotEnv)
            .UseSetOption(TSetOption.NeverSet)
            .Load;

  for i := 1 to LargeVariableCount do
  begin
    Expected := Format('Value_%d', [i]);
    Actual := fDotEnv.Get(Format('VAR_%d', [i]), 'Default');
    Assert.AreEqual(Expected, Actual);
  end;

end;


procedure TTestDotEnv.TestVarSub(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);
var
  DotEnv:iDotEnv;
begin
  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.OnlyFromDotEnv)
           .UseSetOption(TSetOption.NeverSet)
           .LoadFromString(Contents);

  Assert.AreEqual(ExpectedKeyValue, DotEnv.Get(KeyName));
end;


//https://github.com/radprogrammer/rad-dotenv/issues/9
procedure TTestDotEnv.TestVarSubDelay;
const
  //without delayed variable substitution, the FullName value would be " "
  ENV = 'FullName="${FirstName} ${LastName}"' + sLineBreak
      + 'FirstName=John' + sLineBreak
      + 'LastName=Doe';
var
  DotEnv:iDotEnv;
begin
  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.OnlyFromDotEnv)
           .UseSetOption(TSetOption.NeverSet)
           .LoadFromString(ENV);

  Assert.AreEqual('John Doe', DotEnv.Get('FullName'));
end;


procedure TTestDotEnv.TestVarSubOption;
const
  Key1Name = 'KEYx';
  Key1Value = 'VALUEx';

  KeyDoubleQuotedName = 'KEYD';
  KeySingleQuotedName = 'KEYS';
  KeyUnquotedName = 'KEYU';
  ValuePrefix = 'prefix';
  ValueSuffix = 'suffix';

  UnsubstitutedValue = ValuePrefix + '${' + Key1Name + '}' + ValueSuffix;
  ExpectedSubstitutedValue = ValuePrefix + Key1Value + ValueSuffix;
var
  Option:TVariableSubstitutionOption;
  DotEnv:iDotEnv;
  DotEnvString:string;
begin

  DotEnvString := Format('%s=%s',     [Key1Name, Key1Value]) + sLineBreak +                        //KEYx=VALUEx
                  Format('%s="%s"',   [KeyDoubleQuotedName,   UnsubstitutedValue]) + sLineBreak +  //KEYD="prefix${KEYx}suffix"
                  Format('%s=''%s''', [KeySingleQuotedName, UnsubstitutedValue]) + sLineBreak +    //KEYS='prefix${KEYx}suffix'
                  Format('%s=%s',     [KeyUnquotedName, UnsubstitutedValue]);                      //KEYU=prefix${KEYx}suffix

  for Option := Low(TVariableSubstitutionOption) to High(TVariableSubstitutionOption) do
  begin
    DotEnv := NewDotEnv
             .UseRetrieveOption(TRetrieveOption.OnlyFromDotEnv)
             .UseSetOption(TSetOption.NeverSet);

    case Option of
      TVariableSubstitutionOption.SupportSubstutionOnlyInDoubleQuotedValues:
        begin
          DotEnv.UseVariableSubstitutionOption(TVariableSubstitutionOption.SupportSubstutionOnlyInDoubleQuotedValues);   //Enabled by defVariableSubstitutionOption
          DotEnv.LoadFromString(DotEnvString);
          Assert.AreEqual(ExpectedSubstitutedValue, DotEnv.Get(KeyDoubleQuotedName));  //variable was substituted since Value was double quoted and option enabled
          Assert.AreEqual(UnsubstitutedValue, DotEnv.Get(KeyUnquotedName));            //variable was not substituted since Value was Unquoted (Option only applies to DoubleQuoted Values)
          Assert.AreEqual(UnsubstitutedValue, DotEnv.Get(KeySingleQuotedName));        //variable was not substituted since Value was Single Quoted (never subsituted)
        end;
      TVariableSubstitutionOption.SupportSubstitutionExceptInSingleQuotes:
        begin
          DotEnv.UseVariableSubstitutionOption(TVariableSubstitutionOption.SupportSubstitutionExceptInSingleQuotes);
          DotEnv.LoadFromString(DotEnvString);
          Assert.AreEqual(ExpectedSubstitutedValue, DotEnv.Get(KeyDoubleQuotedName));      //variable was substituted since Value was double quoted and option enabled
          Assert.AreEqual(UnsubstitutedValue, DotEnv.Get(KeySingleQuotedName));            //variable was substituted since Value was unquoted and option enabled
          Assert.AreEqual(ExpectedSubstitutedValue, DotEnv.Get(KeyUnquotedName));          //variable was not substituted since Value was Single Quoted (never subsituted)
        end;
      TVariableSubstitutionOption.VariableSubstutionNotSupported:
        begin
          DotEnv.UseVariableSubstitutionOption(TVariableSubstitutionOption.VariableSubstutionNotSupported);    //override to turn off option
          DotEnv.LoadFromString(DotEnvString);
          Assert.AreEqual(UnsubstitutedValue, DotEnv.Get(KeyDoubleQuotedName));       //variable was not substituted, regardless of quote state
          Assert.AreEqual(UnsubstitutedValue, DotEnv.Get(KeyUnquotedName));           //variable was not substituted, regardless of quote state
          Assert.AreEqual(UnsubstitutedValue, DotEnv.Get(KeySingleQuotedName));       //variable was not substituted since Value was Single Quoted (never subsituted)
        end;
    else
      Assert.Fail('Unknown TVariableSubstitutionOption ' + Ord(Option).ToString);
    end;

    DotEnv := nil;
  end;
end;


procedure TTestDotEnv.TestVarSubJunk(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);
begin
  fDotEnv.LoadFromString(Contents);
  Assert.AreEqual(ExpectedKeyValue, fDotEnv.Get(KeyName));
end;


procedure TTestDotEnv.TestEscapeSequenceInterpolationOption;
const
  KeyQuotedName = 'KEYQ';
  KeyUnquotedName = 'KEYU';
  ValueWithEscapeSequence = 'VALUE\t';
  ExpectedUnescapedValue = 'VALUE' + #9;
var
  Option:TEscapeSequenceInterpolationOption;
  DotEnv:iDotEnv;
  DotEnvString:string;
begin

  DotEnvString := Format('%s="%s"', [KeyQuotedName, ValueWithEscapeSequence]) + sLineBreak + //KEYQ="VALUE\t"
                  Format('%s=%s',   [KeyUnquotedName, ValueWithEscapeSequence]);             //KEYU=VALUE\t

  for Option := Low(TEscapeSequenceInterpolationOption) to High(TEscapeSequenceInterpolationOption) do
  begin
    DotEnv := NewDotEnv
             .UseRetrieveOption(TRetrieveOption.OnlyFromDotEnv)
             .UseSetOption(TSetOption.NeverSet);

    case Option of
      TEscapeSequenceInterpolationOption.SupportEscapesInDoubleQuotedValues:
        begin
          DotEnv.UseEscapeSequenceInterpolationOption(TEscapeSequenceInterpolationOption.SupportEscapesInDoubleQuotedValues);  //Enabled by defEscapeSequenceInterpolationOption
          DotEnv.LoadFromString(DotEnvString);
          Assert.AreEqual(ExpectedUnescapedValue, DotEnv.Get(KeyQuotedName));         //escapes replaced since Value was double quoted and option enabled
          Assert.AreEqual(ValueWithEscapeSequence, DotEnv.Get(KeyUnquotedName));      //escapes not replaced since Value was not double quoted (Option only applies to DoubleQuoted Values)
        end;
      TEscapeSequenceInterpolationOption.EscapeSequencesNotSupported:
        begin
          DotEnv.UseEscapeSequenceInterpolationOption(TEscapeSequenceInterpolationOption.EscapeSequencesNotSupported);        //override to turn off option
          DotEnv.LoadFromString(DotEnvString);
          Assert.AreEqual(ValueWithEscapeSequence, DotEnv.Get(KeyQuotedName));       //escapes not replaced, regardless of quote state
          Assert.AreEqual(ValueWithEscapeSequence, DotEnv.Get(KeyUnquotedName));     //escapes not replaced, regardless of quote state
        end;
    else
      Assert.Fail('Unknown TEscapeSequenceInterpolationOption ' + Ord(Option).ToString);
    end;

    DotEnv := nil;
  end;
end;


procedure TTestDotEnv.TestNoExceptions(const Contents:String);
begin
  fDotEnv.LoadFromString(Contents);
  Assert.IsTrue(True);
end;


procedure TTestDotEnv.TestSetEnv;
    function GuidWithoutBracesOrDashes: string;
    var
      Guid: TGUID;
    begin
      Guid := TGUID.NewGuid;
      Result := StringReplace(StringReplace(Guid.ToString, '{', '', [rfReplaceAll]), '}', '', [rfReplaceAll]);
      Result := StringReplace(Result, '-', '', [rfReplaceAll]);
    end;
var
  DotEnv:iDotEnv;
  KeyName, KeyValue1, KeyValue2:string;
begin
  KeyName := 'radDotEnv_' + GuidWithoutBracesOrDashes;
  KeyValue1 := '1_' + GuidWithoutBracesOrDashes;

  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.OnlyFromSys);
  Assert.IsFalse(DotEnv.TryGet(KeyName, KeyValue2)); //not yet set


  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.OnlyFromSys)
           .UseSetOption(TSetOption.AlwaysSet)
           .LoadFromString(Format('%s=%s', [KeyName, KeyValue1]));  //set system env var
  Assert.AreEqual(KeyValue1, DotEnv.Get(KeyName)); //has been set


  KeyValue2 := '2_' + GuidWithoutBracesOrDashes;
  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.OnlyFromSys)
           .UseSetOption(TSetOption.NeverSet)
           .LoadFromString(Format('%s=%s', [KeyName, KeyValue2])); //update DotEnv in-memory map to a new value
  Assert.AreEqual(KeyValue1, DotEnv.Get(KeyName));     //system maintains original value set, not overwritten

  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.OnlyFromSys)
           .UseSetOption(TSetOption.DoNotOvewrite)
           .LoadFromString(Format('%s=%s', [KeyName, KeyValue2]));  //Don't overwrite current value
  Assert.AreEqual(KeyValue1, DotEnv.Get(KeyName)); //has not been overwritten

  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.PreferSys)
           .UseSetOption(TSetOption.DoNotOvewrite)
           .LoadFromString(Format('%s=%s', [KeyName, KeyValue2]));  //Don't overwrite current value
  Assert.AreEqual(KeyValue1, DotEnv.Get(KeyName)); //has not been overwritten

  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.PreferDotEnv)
           .UseSetOption(TSetOption.DoNotOvewrite)
           .LoadFromString(Format('%s=%s', [KeyName, KeyValue2]));  //Don't overwrite current value
  Assert.AreEqual(KeyValue2, DotEnv.Get(KeyName)); //has not been overwritten, but retrieved from in-memory map


  DotEnv := NewDotEnv
           .UseRetrieveOption(TRetrieveOption.OnlyFromSys)
           .UseSetOption(TSetOption.AlwaysSet)
           .LoadFromString(Format('%s=%s', [KeyName, KeyValue2]));  //overwrite again
  Assert.AreEqual(KeyValue2, DotEnv.Get(KeyName)); //has been overwritten

end;


//bin folder was setup a subdirectory named "childpath" that inclues a .env file which contains "child=found"
procedure TTestDotEnv.TestCustomPath;
var
  DotEnv:iDotEnv;
begin
  DotEnv := NewDotEnv
           .UseEnvSearchPaths(['childpath'])
           .UseRetrieveOption(TRetrieveOption.OnlyFromDotEnv);
  Assert.AreEqual('found', DotEnv.Get('child'));
end;


initialization
  TDUnitX.RegisterTestFixture(TTestDotEnv);

end.
