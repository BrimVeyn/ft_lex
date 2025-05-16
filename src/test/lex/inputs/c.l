%{
#include <stdio.h>
%}
%%
"auto"|"break"|"case"|"char"|"const"|"continue"|"default"|"do"|"double"|"else"|"enum"|"extern" |
"float"|"for"|"goto"|"if"|"inline"|"int"|"long"|"register"|"restrict"|"return"|"short"|"signed" |
"sizeof"|"static"|"struct"|"switch"|"typedef"|"union"|"unsigned"|"void"|"volatile"|"while"  { return KW; }

[a-zA-Z_][a-zA-Z_0-9]*              { return IDENT; }
0[xX][0-9a-fA-F]+                   { return HEX; }
[0-9]+                              { return INT; }
[0-9]+\.[0-9]*([eE][+-]?[0-9]+)?    { return FLOAT; }
\"(\\.|[^\"\\])*\"                  { return STRING; }
\'(\\.|[^\'\\])\'                   { return CHAR; }
"//".*                              { /* skip line comment */ }
"/*"([^*]|\*[^/])*"*/"              { /* skip block comment */ }

\+\+|--|->|==|!=|<=|>=|&&|\|\||<<|>>|[-+*/%&|^~=!<>]=?  { return OP; }
[(){}\[\];,\.]                      { return SYM; }
[ \t\r\n]+                          { /* skip whitespace */ }
.                                   { return UNKNOWN; }
