%%
0[xX][0-9a-fA-F]+                { printf("HEX\n"); }
[0-9]+[uU]?[lL]?                 { printf("INT\n"); }
[0-9]+\.[0-9]*([eE][-+]?[0-9]+)? { printf("FLOAT\n"); }
\.[0-9]+([eE][-+]?[0-9]+)?       { printf("FLOAT\n"); }
[0-9]+[eE][-+]?[0-9]+            { printf("EXP_FLOAT\n"); }
.                                { /* skip */ }
