%s   INITIAL  MAIN   PARSER1
%x   EXCLUSIVE1  EXCLUSIVE2 EXTRA

%array
%pointer

%k  42069
%n   666   9001  // Comment after transition count

%p 123

%a 007
%e 0042

%{
    // Start of C preamble
    #include <stdio.h>
    #define INIT_STATE(x) do { if (x) { printf("Init {state}"); } } while (0)

    const char *tricky = "This string has a fake %} and real { brace";
    const char *nested = "Nested \"quote { %} inside\" another";

    /*
     * Comment with fake %{ and %} inside
     * %{ not real
     * %} not real either
     */

    #define BLOCK \
        { \
            printf("In macro block\n"); \
        }

%}

DIGIT    [0-9]
LETTER   [a-zA-Z]
WORDCHAR [_a-zA-Z0-9]

NUM1     {DIGIT}+
NUM2     {NUM1}\.{DIGIT}*
HEX      0[xX][0-9a-fA-F]+
OCT      0[0-7]*

ID       {LETTER}({WORDCHAR})*

STR      \"([^"\\]|\\.)*\"

SPC      [ \t\r]+
NL       (\n|\r\n)
ESC      \\\\.
BOM      \xEF\xBB\xBF

COMMENT     (//[^\n]*|/\*([^*]|\*+[^*/])*\*+/)

MIXED       {ID}|{NUM2}|{STR}|{COMMENT}

TRICK       if|else|for|while|return|{ID}{SPC}?={SPC}?{NUM1}

DEF_MACRO   {TRICK}{COMMENT}?

%%
