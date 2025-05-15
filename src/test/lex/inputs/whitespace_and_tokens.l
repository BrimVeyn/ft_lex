%{
#include <stdio.h>
%}

%%

[ \t\r\n]+          { /* skip whitespace */ }
"return"            { printf("RETURN\n"); }
"("                 { printf("LPAREN\n"); }
")"                 { printf("RPAREN\n"); }

%%
