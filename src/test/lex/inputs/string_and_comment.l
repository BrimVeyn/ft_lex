%{
#include <stdio.h>
%}

%%

"//".*              { printf("COMMENT\n"); }
\"([^\"\\]|\\.)*\"  { printf("STRING\n"); }

%%
