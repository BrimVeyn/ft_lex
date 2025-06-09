%{
#include <stdio.h>
%}

%%

^start             { printf("Found 'start' at the beginning of a line\n"); }
end$              { printf("Found 'end' at the end of a line\n"); }

foo/bar           { printf("Matched 'foo' only when followed by 'bar'\n"); }
"foo"             { printf("Matched 'foo' (not followed by 'bar')\n"); }

[0-9]+            { printf("Number: %s\n", yytext); }
[a-zA-Z]+         { printf("Word: %s\n", yytext); }
\n                { /* do nothing for newline */ }
.                 { printf("Other: %s\n", yytext); }

%%
