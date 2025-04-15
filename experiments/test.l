%{
#include <stdio.h>
%}

%s COMMENT
%x BLOCK

%%

"a"""*			{ printf("Match: %s\n", yytext); }

.                { printf("OTHER: %s\n", yytext); }

%%

