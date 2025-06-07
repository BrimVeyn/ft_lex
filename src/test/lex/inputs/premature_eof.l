%{
#include <stdio.h>
%}

%%

"load"+/"ing"         { printf("Matched load+/ing → yytext = \"%s\"\n", yytext); }

"loading"             { printf("Matched full loading → yytext = \"%s\"\n", yytext); }

"he"+"llo"/"world"    { printf("Matched he+llo/world → yytext = \"%s\"\n", yytext); }

"helloworld"          { printf("Matched full helloworld → yytext = \"%s\"\n", yytext); }

"test"/("case1"|"case2") { printf("Matched test before case1/case2 → yytext = \"%s\"\n", yytext); }

"testcase1"           { printf("Matched full testcase1 → yytext = \"%s\"\n", yytext); }

"testcase2"           { printf("Matched full testcase2 → yytext = \"%s\"\n", yytext); }

.|\n                  { /* skip unknown input */ }

