%{
#include <stdio.h>
%}

%x STRING

%%

\"	{
	printf("Start of string\n");
	BEGIN(STRING);
}

<STRING>[^"]+ 
<STRING>\"	{
	printf("End of string\n");
	BEGIN(INITIAL);
}

%%

int main() {
    yylex();
    return 0;
}
