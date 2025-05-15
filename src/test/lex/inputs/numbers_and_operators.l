%{
#include <stdio.h>
%}

%%

[0-9]+              { printf("INTEGER\n"); }
[0-9]+\.[0-9]+      { printf("FLOAT\n"); }
"+"|"-"|"*"|"/"     { printf("OPERATOR\n"); }

%%
