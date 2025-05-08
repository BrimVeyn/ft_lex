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
if|then|begin|end|procedure|function        {
    printf("A keyword: %s\n", yytext);
    }
{ID}    printf("An identifier: %s\n", yytext);
"+"|"-"|"*"|"/"        printf("An operator: %s\n", yytext);
"{"[^}\n]*"}"    /* Eat up one-line comments. */
[ \t\n]+        /* Eat up white space. */
.  printf("Unrecognized character: %s\n", yytext);
