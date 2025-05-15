%{
#include <stdio.h>
%}

%%

"if"        { printf("KEYWORD_IF\n"); }
"else"      { printf("KEYWORD_ELSE\n"); }
[a-zA-Z_][a-zA-Z0-9_]*  { printf("IDENTIFIER\n"); }

%%
