# rad-dotenv
## DotEnv file (.env) support for Delphi

- Add DotEnv file support by including `radDotEnv.pas` in your project
- `DotEnv` singleton variable created at startup (option can be disabled)
  - Simply add the `radDotEnv` unit to your uses clause and use `DotEnv.Get('VariableName')`
- Fully complies with DotEnv Draft RFC: https://github.com/radprogrammer/dotenv-RFC
- No exceptions are raised on parsing issues to prevent difficult to debug application startup issues (a logging hook is available)
- Custom paths can be searched (only the directory of the application is searched by default)
- Custom filenames can be used (utilizes `.env` by default)
- Custom file encoding can be specified (defaults to UTF8 by default)
- Extremely fast dotenv file parser (fastest parser tested)

## Key Value Syntax Examples
- `KEY=TEXT`  Value=`TEXT`
- `KEY=   Unquoted Values are trimmed   `  Value=`Unquoted Values are trimmed`
- `# full line comments supported`
- `KEY=TEXT #inline comments supported`  Value=`TEXT`
- `KEY=TEXT#also inline comment (no space required)`  Value=`TEXT`  (see [Open Issue 12](https://github.com/radprogrammer/rad-dotenv/issues/12))
- `KEY="DoubleQuoted"`  Value=`DoubleQuoted`
- `KEY='SingleQuoted'`  Value=`SingleQuoted`
- `KEY TEXT improperly formatted lines are ignored`
- `KEY="TEXT"InvalidTextIgnored"`  Value=`TEXT`
- Empty lines are ignored
- **Escape sequence expansion** supported within double-quoted values (option can be disabled)
  - `KEY="Line1\nLine2"`  Value = `Line1{LF}Line2`
  - `KEY="Line1\r\nLine2"`  Value = `Line1{CRLF}Line2`
  - `KEY="Line1\"Line2"`  Value = `Line1"Line2`
  - `KEY="Line1\\Line2"`  Value = `Line1\Line2`
- `${KEY}` **variable substitution** supported within double-quoted values (option can be disabled)
````
KEY1=VALUE1
KEY2="ValueFromKey1=${KEY1}"   # Value=ValueFromKey1=VALUE1
````
- **Default values** can be provided with variable substitution via `${KEY-default}`
````
KEY="Value${UnknownKey-123}"   # Value=Value123
````
- Available option to support variable substitution within Unquoted values (option is disabled by default)
````
KEY1=VALUE1
KEY2=ValueFromKey1=${KEY1}   # Value=ValueFromKey1=VALUE1
````
- Single-Quoted values always avoid variable substitution and escape sequence expansion
````
KEY1=VALUE1
KEY2='ValueFromKey1=${KEY1}'   # Value=ValueFromKey1=${KEY1}
````
- Either double-quoted or single-quoted **multi-line values** supported
````
ONE=`First line
Second line
Third line`
TWO="First line
Second line
Third line"
````


## DevTool
A sample DevTool project included that loads an .env file and displays the contents in an editable memo field. A grid is displayed of the parsed entries and another grid that reveals the current system Environment Variables.  A "Save and Reload env" button allows you to save the contents of the DotEnv file and see that parsed results along with a refreshed list of Environment Variables to offer a handy way of debugging .env file parsing.
![DevTool ScreenShot](https://github.com/radprogrammer/rad-dotenv/blob/master/devtool/radDotEnv.DevTool.ScreenShot.png)

## License
`rad-dotenv` is licensed under either of the following two licenses, at your discretion.

- [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
- [MIT License](http://opensource.org/licenses/MIT)

Unless you explicitly state otherwise, any contribution submitted for inclusion in 
this project by you shall be dual licensed as above (as defined in the Apache v2 License), 
without any additional terms or conditions.
