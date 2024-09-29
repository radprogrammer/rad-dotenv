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
