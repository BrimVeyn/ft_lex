%{
#include <stdio.h>
#include <stdlib.h>

void yyerror(const char *msg) {
    fprintf(stderr, "Error: %s\n", msg);
}

int depth = 0;  // Track nesting depth
%}

%x TEMPLATE

%%
"${"            { 
    if (depth++ == 0) {
        printf("START TEMPLATE\n"); 
        BEGIN(TEMPLATE); 
    }
    yymore();  // Accumulate "${"
}

<TEMPLATE>[^${}]+ { 
    yymore();  // Accumulate literal text
}

<TEMPLATE>"${"   { 
    depth++; 
    yymore();  // Handle nested "${"
}

<TEMPLATE>"}"    { 
    if (--depth == 0) {
        printf("COMPLETE TEMPLATE: %s\n", yytext); 
        BEGIN(INITIAL); 
    } else {
        yymore();  // Accumulate "}" for nested templates
    }
}

.|\n

%%

int main() {
    yylex();
    return 0;
}

int yywrap() {
    return 1;
}
