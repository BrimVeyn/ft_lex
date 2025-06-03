%x STR COMMENT

%%

^start              { printf("Matched 'start' at beginning of line\n"); }

"/*"                { BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); printf("End of comment block\n"); }
<COMMENT>.|\n       ; // Consume everything inside comment

\"                  { BEGIN(STR); }
<STR>[^\"\\\n]+     { printf("String fragment: %s\n", yytext); }
<STR>\\\"           { printf("Escaped quote\n"); }
<STR>\"             { BEGIN(INITIAL); printf("End of string\n"); }
<STR>\n             { printf("Unterminated string\n"); BEGIN(INITIAL); }

"switch"            { printf("Switching to STR state\n"); BEGIN(STR); }

[0-9]+              { printf("Integer: %s\n", yytext); }
[a-zA-Z_][a-zA-Z0-9_]* { printf("Identifier: %s\n", yytext); }

[ \t\r\n]+          ; // Skip whitespace

.                   { printf("Unknown character: %s\n", yytext); }

%%
