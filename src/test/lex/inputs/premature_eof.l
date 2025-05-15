DIGIT    [0-9]
ID       [a-z][a-z0-9]*

%%
{DIGIT}+ {
    printf("An integer: %s (%d)\n", yytext,
        atoi(yytext));
    }
{DIGIT}+"."{DIGIT}*        {
    printf("A float: %s (%g)\n", yytext,
        atof(yytext));
    }
.  printf("Unrecognized character: %s\n", yytext);
