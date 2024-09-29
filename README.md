# rad-dotenv
## DotEnv file (.env) support for Delphi

- Add DotEnv file support in your Delphi projects by including one source code file from this repository
- Complies with DotEnv Draft RFC: https://github.com/radprogrammer/dotenv-RFC
  - TODO: Variable interpolation with {$KEY}

## Key Value Syntax Examples
- `KEY=TEXT`  Value="TEXT"
- `KEY=   Unquoted Values are trimmed   `  Value="Unquoted Values are trimmed"
- `# line comments supported`
- `KEY=TEXT #inline comments supported`  Value="TEXT"
- `KEY="DoubleQuoted"`  Value="DoubleQuoted"
- `KEY='SingleQuoted'`  Value="SingleQuoted"
- `KEY TEXT improperly formatted lines are ignored`
- `KEY="TEXT"InvalidTextIgnored"`  Value="TEXT"

- Escape sequence expansion supported within double-quoted values (option can be disabled)
  - `KEY="Line1\nLine2"  Value = "Line1{LF}Line2"
  - `KEY="Line1\r\nLine2"  Value = "Line1{CRLF}Line2"
  - `KEY="Line1\"Line2"  Value = "Line1"Line2"
  - `KEY="Line1\\Line2"  Value = "Line1\Line2"

- `${KEY}` variable substitution supported within double-quoted values (option can be disabled)
````
KEY1=VALUE1
KEY2=ValueFromKey1=$(KEY1)   # Value="ValueFromKey1=VALUE1"
````

- Either double-quoted or single-quoted multi-line values supported
````
ONE=`First line
Second line
Third line`
TWO="First line
Second line
Third line"
````

## License
`rad-dotenv` is licensed under either of the following two licenses, at your discretion.

- [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
- [MIT License](http://opensource.org/licenses/MIT)

Unless you explicitly state otherwise, any contribution submitted for inclusion in 
this project by you shall be dual licensed as above (as defined in the Apache v2 License), 
without any additional terms or conditions.
