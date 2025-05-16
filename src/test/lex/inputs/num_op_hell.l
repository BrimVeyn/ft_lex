%%
"=="|"!="|"<="|">="|"<"|">"|"&&"|"||"|"+"|"-"|"*"|"/"|"%"|"!"|"~"|"&"|"|"|"^"|"<<"|">>"  { return OPERATOR; }
[0-9]+                                               { return INTEGER; }
[0-9]+\.[0-9]+                                       { return FLOAT; }
0[xX][0-9a-fA-F]+                                    { return HEX; }
0[bB][01]+                                           { return BINARY; }
[ \t\r\n]+                                           { /* skip whitespace */ }
.                                                    { return UNKNOWN; }
