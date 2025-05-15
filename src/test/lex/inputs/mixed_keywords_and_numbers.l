%%
if              { printf("IF\n"); }
else            { printf("ELSE\n"); }
[0-9]+          { printf("NUMBER\n"); }
[a-zA-Z_][a-zA-Z0-9_]*    { printf("IDENTIFIER\n"); }
[ \t\n]+        { /* skip whitespace */ }
.               { printf("UNKNOWN\n"); }
%%
