%{
#include <stdio.h>
%}
%%
"def"|"class"|"if"|"elif"|"else"|"while"|"for"|"in"|"return"|"import"|"from"|"as"|"try"|"except"|"finally"|"with"|"pass"|"break"|"continue"|"and"|"or"|"not"|"is"|"None"|"True"|"False"  { return KW; }
[a-zA-Z_][a-zA-Z_0-9]*              { return IDENT; }
[0-9]+                              { return INT; }
[0-9]+\.[0-9]*                      { return FLOAT; }
\"(\\.|[^\"\\])*\"                  { return STRING; }
\'(\\.|[^\'\\])*\'                  { return STRING; }
"#".*                               { /* skip comment */ }
[(){}\[\]:,\.]                      { return SYM; }
[ \t\r\n]+                          { /* skip whitespace */ }
.                                   { return UNKNOWN; }
