%%
[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}  { printf("EMAIL\n"); }
[0-9]{4}-[0-9]{2}-[0-9]{2}                     { printf("DATE\n"); }
[0-9]+                                          { printf("NUMBER\n"); }
[a-zA-Z_][a-zA-Z0-9_]*                          { printf("IDENTIFIER\n"); }
[ \t\n]+                                        { /* skip */ }
.                                               { printf("UNKNOWN\n"); }
%%
