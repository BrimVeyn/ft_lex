%{
#include <stdio.h>
%}
%%
"as"|"break"|"const"|"continue"|"crate"|"else"|"enum"|"extern"|"false"|"fn"|"for"|"if"|"impl"|"in"|"let"|"loop" |
"match"|"mod"|"move"|"mut"|"pub"|"ref"|"return"|"self"|"Self"|"static"|"struct"|"super"|"trait"|"true" |
"type"|"unsafe"|"use"|"where"|"while"  { return KW; }

[a-zA-Z_][a-zA-Z_0-9]*              { return IDENT; }
0[xX][0-9a-fA-F_]+[uUiI]?[0-9]*     { return HEX; }
[0-9_]+[uUiI]?[0-9]*                { return INT; }
[0-9]+\.[0-9]+([eE][+-]?[0-9]+)?[fF]?[32|64]? { return FLOAT; }
\"(\\.|[^\"\\])*\"                  { return STRING; }
\'(\\.|[^\'\\])\'                   { return CHAR; }
\/\/.*                              { /* skip line comment */ }
\/\*([^*]|\*[^/])*\*\/              { /* skip block comment */ }

==|!=|<=|>=|=>|&&|\|\||[-+*/%&|^~=!<>]=?|::|->|<<|>>  { return OP; }
[(){}\[\];,\.]                      { return SYM; }
[ \t\r\n]+                          { /* skip whitespace */ }
.                                   { return UNKNOWN; }
