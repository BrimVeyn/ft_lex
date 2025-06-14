%x STRING COMMENT CMD

%%

^cmd[ ]+start            { printf("CMD start detected\n"); BEGIN(CMD); }

<CMD>^cmd[ ]+end         { printf("CMD end detected\n"); BEGIN(INITIAL); }
<CMD>^print[ ]+.+        { printf("CMD print: %s\n", yytext); }

^\/\/.*                    { printf("Single-line comment: %s\n", yytext); }

^#[ ]*define             { printf("Found #define directive\n"); }

\"                       { printf("Start of string\n"); BEGIN(STRING); }
<STRING>[^\"\\\n]+       { printf("String fragment: %s\n", yytext); }
<STRING>\\[\"nrt\\]      { printf("Escape sequence: %s\n", yytext); }
<STRING>\"               { printf("End of string\n"); BEGIN(INITIAL); }

"/*"                    { printf("Start of comment block\n"); BEGIN(COMMENT); }
<COMMENT>"*/"           { printf("End of comment block\n"); BEGIN(INITIAL); }
<COMMENT>.|\n           ; // Consume comment content

<INITIAL>[a-zA-Z_][a-zA-Z0-9_]* {
    printf("Identifier: %s\n", yytext);
}

[0-9]+                  { printf("Integer: %s\n", yytext); }

[ \t\r\n]+              ; // Ignore whitespace

.                       { printf("Unknown: %s\n", yytext); }

%%

