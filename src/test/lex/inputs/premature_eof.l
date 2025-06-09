%{
#include <stdio.h>
int line_num = 1;
%}

/* Define start conditions */
%x HTML CODE

%%

^section            { printf("[Line %d] Section header at line start\n", line_num); }

<INITIAL>"<html>"   { printf("[Line %d] Entering HTML mode\n", line_num); BEGIN(HTML); }

[a-zA-Z_]+" "/:[0-9]+ { printf("[Line %d] Identifier before colon-number context: %s\n", line_num, yytext); }

data/=[^\s]         { printf("[Line %d] Found 'data' before assignment\n", line_num); }

[a-zA-Z_]+          { printf("[Line %d] Identifier: %s\n", line_num, yytext); }

\n                  { line_num++; }

[ \t\r]+            { /* skip */ }

<HTML>"</html>"     { printf("[Line %d] Exiting HTML mode\n", line_num); BEGIN(INITIAL); }

<HTML><[^>]+>       { printf("[Line %d] HTML Tag: %s\n", line_num, yytext); }

<HTML>[^<\n]+       { printf("[Line %d] HTML Text: %s\n", line_num, yytext); }

<HTML>\n            { line_num++; }

<HTML>.             { printf("[Line %d] HTML Unknown: %s\n", line_num, yytext); }

%%

