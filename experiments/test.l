%{
/* Need this for the call to atof() below. */
#include <math.h>
/* Need this for printf(), fopen(), and stdin below. */
#include <stdio.h>
%}

			%%

\%%+ {
   printf("Wow: %s (%d)\n", yytext, atoi(yytext));
}

%%

int main(int argc, char *argv[])
{
   ++argv, --argc;  /* Skip over program name. */
   if (argc > 0)
	   yyin = fopen(argv[0], "r");
   else
	   yyin = stdin;

   yylex();
}
