// DotEnv file (.env) support for Delphi
// More info: https://github.com/radprogrammer/rad-dotenv
unit radDotEnv.Tests;
{$DEFINE ALLTESTS}

interface

uses
  DUnitX.TestFramework,
  radDotEnv;

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
{$IFDEF ALLTESTS}
    [TestCase('UnquotedValue', 'key=value,key,value')]
    [TestCase('UnquotedValueLeftTrimmed', 'key= value,key,value')]
    [TestCase('UnquotedValueRightTrimmed', 'key=value ,key,value')]
    [TestCase('UnquotedValueTrimmed', 'key= value ,key,value')]

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
    //Note: this set of tests is configured "OnlyFromDotEnv" and "NeverSet"
    [TestCase('SimpleVariableSubstitution', 'key1=value1' + sLineBreak + 'key2="ValueFromKey1=${KEY1}.",key2,ValueFromKey1=value1.')]
    [TestCase('UnknownVariableIsBlankByDefault', 'key="value${NonExistingVariableNameHere}test",key,valuetest')]
    [TestCase('UnknownVariableDefaultValueProvided', 'key="value${NonExistingVariableNameHere-DefValue}test",key,valueDefValuetest')]
{$ENDIF}
    procedure TestSingleKeyValue(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);


{$IFDEF ALLTESTS}
    [TestCase('EmptyContent', '')]
    [TestCase('SingleWhiteSpace', ' ')]
    [TestCase('MultipleWhiteSpace', '   ')]
    [TestCase('MultipleWhiteSpaceEndOfLines1', #10 + ' ' + #13)]
    [TestCase('MultipleWhiteSpaceEndOfLines2', #13 + ' ' + #10)]
    [TestCase('MultipleWhiteSpaceEndOfLines3', #13 + '  ' + #10 + '  ')]
    [TestCase('MultipleWhiteSpaceEndOfLinesTab', #10 + ' ' + #13 + ' ' + #9)]
    [TestCase('OneCommentLine', '#')]
    [TestCase('TwoCommentLine', '# #')]
    [TestCase('ConsecutivePounds', '####')]
    [TestCase('TwoCommentLines', '#' + sLineBreak + '#')]
    [TestCase('CommentWhiteSpaceCommentLine', '#' + sLineBreak + '  ' + '#')]
{$ENDIF}
    procedure TestNoExceptionsOnJunkParse(const Contents:String);

  end;

implementation


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
procedure TTestDotEnv.TestNoExceptionsOnJunkParse(const Contents:String);
begin
  fDotEnv.LoadFromString(Contents);
  Assert.IsTrue(True);
end;

procedure TTestDotEnv.TestSingleKeyValue(const Contents:String; const KeyName:string; const ExpectedKeyValue:string);
begin
  fDotEnv.LoadFromString(Contents);
  Assert.AreEqual(ExpectedKeyValue, fDotEnv.Get(KeyName));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDotEnv);

end.
