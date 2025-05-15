%%
"//".*                { /* single-line comment */ }
"/*"[^*]*"*"+([^/*][^*]*"*"+)*"/"   { /* multi-line comment */ }
"=="                  { printf("EQ\n"); }
"="                   { printf("ASSIGN\n"); }
"+"                   { printf("PLUS\n"); }
"-"                   { printf("MINUS\n"); }
[0-9]+                { printf("INT\n"); }
[a-z]+                { printf("IDENT\n"); }
[ \t\n]+              { /* skip */ }
%%
