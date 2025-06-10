%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int line_number = 1;
void count_lines(void);
void process_identifier(void);
void handle_quoted_string(void);
%}

DIGIT    [0-9]
LETTER   [a-zA-Z]
ID       {LETTER}({LETTER}|{DIGIT}|_)*
NUMBER   {DIGIT}+(\.{DIGIT}+)?([eE][+-]?{DIGIT}+)?
WHITESPACE [ \t\r]

%x STRING COMMENT INCLUDE

%%

"/*"            { BEGIN(COMMENT); printf("Entering comment\n"); }
<COMMENT>"*/"   { BEGIN(INITIAL); printf("Exiting comment\n"); }
<COMMENT>.      { /* Discard comment text */ }
<COMMENT>\n     { line_number++; }

\"              { BEGIN(STRING); printf("Starting string\n"); unput('"'); }
<STRING>\"      { 
    BEGIN(INITIAL); 
    printf("Complete string: %s\n", yytext); 
    /* Test unput chain */
    unput('!');
    unput('D');
    unput('L');
    unput('R');
    unput('O');
    unput('W');
}
<STRING>.       { printf("String char: %c\n", yytext[0]); }
<STRING>\n      { printf("Unterminated string at line %d\n", line_number); exit(1); }

"#include"      { BEGIN(INCLUDE); printf("Include directive\n"); }
<INCLUDE>{WHITESPACE}+   { /* Skip whitespace */ }
<INCLUDE>"<"[^>]+">"     { 
    printf("System include: %s\n", yytext); 
    BEGIN(INITIAL);
    /* Test input during state transition */
    char *extra = "EXTRA";
    while (*extra) unput(*extra++);
}
<INCLUDE>\"[^"]+\"       { 
    printf("Local include: %s\n", yytext); 
    BEGIN(INITIAL);
}

"input_test"    {
    printf("Testing input() function\n");
    char c;
    int count = 0;
    while ((c = input()) != 0 && count++ < 10) {
        printf("Read via input(): %c (0x%02x)\n", c, c);
        if (c == '\n') line_number++;
    }
    /* Now push some back */
    unput('X');
    unput('Y');
    unput('Z');
}

"unput_test"    {
    printf("Testing unput chain\n");
    char *str = "PUSHED1";
    while (*str) unput(*str++);
    
    /* Nested unput */
    unput('A');
    unput('B');
    unput('C');
    
    /* Now read them back */
    char c;
    for (int i = 0; i < 10; i++) {
        c = input();
        if (c == 0) break;
        printf("Read after unput: %c\n", c);
    }
}

"buffer_boundary" {
    printf("Testing buffer boundary conditions\n");
    /* Fill the buffer */
    for (int i = 0; i < 500; i++) {
        unput('0' + (i % 10));
    }
    
    /* Now read back */
    char c;
    int count = 0;
    while ((c = input()) != 0 && count++ < 1000) {
        if (count % 40 == 0) printf("\n");
        putchar(c);
    }
    printf("\n");
}

{NUMBER}        { printf("Number: %s\n", yytext); }
{ID}            { printf("Identifier: %s\n", yytext); }
{WHITESPACE}+   { /* Skip whitespace */ }
\n              { line_number++; }
.               { printf("Unexpected character: %c (0x%02x)\n", yytext[0], yytext[0]); }

%%

int yywrap() {
    return 1;
}

int main() {
    printf("Starting lexer test...\n");
    yylex();
    printf("Lexer test complete. Processed %d lines.\n", line_number);
    return 0;
}
