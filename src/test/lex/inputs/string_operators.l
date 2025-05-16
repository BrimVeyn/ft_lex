%%
\"([^"\\]|\\.)*\"      { printf("STRING\n"); }
"=="                   { printf("EQ\n"); }
"!="                   { printf("NEQ\n"); }
"<="                   { printf("LEQ\n"); }
">="                   { printf("GEQ\n"); }
"="                    { printf("ASSIGN\n"); }
"&&"                   { printf("AND\n"); }
"\|\|"                 { printf("OR\n"); }
"!"                    { printf("NOT\n"); }
[+\-*/%]               { printf("OP\n"); }
.                      { /* skip */ }
