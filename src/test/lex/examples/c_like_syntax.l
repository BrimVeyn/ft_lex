%{
#include <stdio.h>
%}

%x STRING COMMENT BLOCKCMD

%%

^start_block             { printf("Start of block command\n"); BEGIN(BLOCKCMD); }

<BLOCKCMD>^end_block     { printf("End of block command\n"); BEGIN(INITIAL); }
<BLOCKCMD>^do[ \t]+[a-zA-Z_]+ {
    printf("BLOCKCMD do: %s\n", yytext);
}

^#[ \t]*include[ \t]+[a-zA-Z./_]+ {
    printf("Include directive: %s\n", yytext);
}

^#[ \t]*define[ \t]+[a-zA-Z_][a-zA-Z0-9_]*[ \t]+.+ {
    printf("Define directive: %s\n", yytext);
}

\"                       { printf("Start of string\n"); BEGIN(STRING); }
<STRING>[^\"\\\n]+       { printf("String part: %s\n", yytext); }
<STRING>\\[\"nrt\\]      { printf("String escape: %s\n", yytext); }
<STRING>\"               { printf("End of string\n"); BEGIN(INITIAL); }

"/*"                    { printf("Start comment block\n"); BEGIN(COMMENT); }
<COMMENT>"*/"           { printf("End comment block\n"); BEGIN(INITIAL); }
<COMMENT>.|\n           ; // ignore comment content

"//"[^\n]*                 { printf("Single-line comment: %s\n", yytext); }

^int[ \t]+[a-zA-Z_][a-zA-Z0-9_]*[ \t]*=[ \t]*[0-9]+; {
    printf("Integer declaration: %s\n", yytext);
}

^[a-zA-Z_][a-zA-Z0-9_]*:[ \t]*$ {
    printf("Label: %s\n", yytext);
}

[a-zA-Z_][a-zA-Z0-9_]*  { printf("Identifier: %s\n", yytext); }
[0-9]+                  { printf("Number: %s\n", yytext); }
[\n\t\r ]+              ; // skip whitespace
.                       { printf("Unknown char: %s\n", yytext); }

%%

