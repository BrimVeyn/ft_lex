%%
"aaaaaaaaaaaaaaaaaaaaaaa"                            { return LITERAL1; }
"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"                  { return LITERAL2; }
"cccccccccccccccccccccccccccccccccccccccc"          { return LITERAL3; }
"ddddddddddddddddddddddddddddddddddddddddddddd"     { return LITERAL4; }
"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"   { return LITERAL5; }
[ \t\r\n]+                                           { /* skip whitespace */ }
.                                                    { return UNKNOWN; }
