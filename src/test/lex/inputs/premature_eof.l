
DIGIT [0-9]\ d

%%

[0-9]\ d printf("salut !\n");

"if"               { printf("IF keyword\n"); }
"else"             { printf("ELSE keyword\n"); }

"then"				|			
"defer" printf("other keyword\n");

[a-zA-Z_][a-zA-Z0-9_]*    { printf("Identifier: %s\n", yytext); }

{NUM}              { printf("Number: %s\n", yytext); }

"\""([^\"\\]|\\.)* "\""   { printf("String: %s\n", yytext); }

"//".*             { /* single-line comment */ }

"/*"               {
                      BEGIN(COMMENT);
                  }

<COMMENT>"*/"      {
                      BEGIN(INITIAL);
                  }

<COMMENT>.|\n      { /* eat all characters in comment mode */ }

"="                { return ASSIGN; }
"=="               { return EQ; }


[ \t\r\n]+         ;  // skip whitespace

.                  { printf("Unexpected char: %c\n", yytext[0]); }

<START>"start_rule" { printf("In START mode!\n"); }

<NINO,NINOUCH>{ID} { printf("Exclusive mode ID: %s\n", yytext); }

%%
