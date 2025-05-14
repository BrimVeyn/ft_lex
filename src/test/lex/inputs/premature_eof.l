%{
#include <stdio.h>
%}

%%

"if"            { printf("KEYWORD: if\n"); }
"else"          { printf("KEYWORD: else\n"); }
"while"         { printf("KEYWORD: while\n"); }
"return"        { printf("KEYWORD: return\n"); }

[0-9]+          { printf("INTEGER: %s\n", yytext); }
[0-9]+\.[0-9]+  { printf("FLOAT: %s\n", yytext); }

[a-zA-Z_][a-zA-Z0-9_]* {
                    printf("IDENTIFIER: %s\n", yytext);
}

"=="|"!="|"<="|">=" { printf("RELOP: %s\n", yytext); }
"="|"+"|"-"|"*"|"/" { printf("OPERATOR: %s\n", yytext); }

"("             { printf("LPAREN\n"); }
")"             { printf("RPAREN\n"); }
";"             { printf("SEMICOLON\n"); }
","             { printf("COMMA\n"); }

[ \t\r\n]+      { /* skip whitespace */ }

.               { printf("UNKNOWN: %s\n", yytext); }
