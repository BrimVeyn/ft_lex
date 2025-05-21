%{
#include <stdio.h>
%}

%s INCLUSIVE
%x EXCLUSIVE

%%

"start_incl" {
    printf("Entered inclusive mode\n");
    BEGIN(INCLUSIVE);
}

<INCLUSIVE>"hello" {
    printf("INCLUSIVE: hello matched\n");
}

<INCLUSIVE>"exit" {
    printf("Exiting to INITIAL from INCLUSIVE\n");
    BEGIN(INITIAL);
}

"start_excl" {
    printf("Entered exclusive mode\n");
    BEGIN(EXCLUSIVE);
}

<EXCLUSIVE>"world" {
    printf("EXCLUSIVE: world matched\n");
}

<EXCLUSIVE>"exit" {
    printf("Exiting to INITIAL from EXCLUSIVE\n");
    BEGIN(INITIAL);
}

"always" {
    printf("Matched in any state: always\n");
}

.|\n ; // ignore everything else

%%

int main(void) {
    yylex();
    return 0;
}
