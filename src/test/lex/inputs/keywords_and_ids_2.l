%%
"if"        { printf("IF\n"); }
"else"      { printf("ELSE\n"); }
"while"     { printf("WHILE\n"); }
"for"       { printf("FOR\n"); }
"return"    { printf("RETURN\n"); }
"function"  { printf("FUNCTION\n"); }
"switch"    { printf("SWITCH\n"); }
"case"      { printf("CASE\n"); }
"break"     { printf("BREAK\n"); }
"continue"  { printf("CONTINUE\n"); }
[a-zA-Z_][a-zA-Z0-9_]*  { printf("ID\n"); }
.           { /* skip */ }
