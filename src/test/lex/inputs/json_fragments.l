%%
\"(\\.|[^\"\\])*\"                                     { return STRING; }
[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?                   { return NUMBER; }
"true"|"false"|"null"                                 { return CONST; }
"{"|"}"|"["|"]"|":"|","                               { return PUNCT; }
[ \t\r\n]+                                            { /* skip whitespace */ }
.                                                     { return UNKNOWN; }
