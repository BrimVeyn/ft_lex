%%
[0-9]+          { printf("INT\n"); }
"=="            { printf("EQ\n"); }
"!="            { printf("NEQ\n"); }
">="            { printf("GE\n"); }
"<="            { printf("LE\n"); }
">"             { printf("GT\n"); }
"<"             { printf("LT\n"); }
"+"             { printf("PLUS\n"); }
"-"             { printf("MINUS\n"); }
"*"             { printf("MUL\n"); }
"/"             { printf("DIV\n"); }
"="             { printf("ASSIGN\n"); }
[a-zA-Z_][a-zA-Z0-9_]*    { printf("IDENT\n"); }
[ \t\n]+        { /* ignore whitespace */ }
%%
