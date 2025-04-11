%{
#include <stdio.h>
%}

%%
a/bar   { printf("Matched 'foo' followed by 'bar' (but only 'foo' consumed)\n"); }
goo		   { printf("Match bar\n"); }
\n	
.       { printf("Unknonk\n"); }
%%

int main() {
    yylex();
    return 0;
}

