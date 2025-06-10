%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Test both input() and unput() functions */
int line_num = 1;
void count_lines(void);
void process_identifier(const char *text);
void handle_quoted_string(void);
void handle_backtracking(char c);
%}

DIGIT    [0-9]
LETTER   [a-zA-Z]
IDENT    {LETTER}({LETTER}|{DIGIT}|_)*
WS       [ \t]+
NEWLINE  \n

%%

{WS}      /* Skip whitespace */
{NEWLINE} { line_num++; }

"/*"      { 
            /* Test input() in a comment */
            int c;
            while ((c = input()) != EOF) {
                if (c == '*' && (c = input()) == '/') {
                    break;
                }
                if (c == '\n') line_num++;
            }
          }

\"        { 
            /* Test unput() in string handling */
            handle_quoted_string(); 
          }

"if"|"else"|"while"|"for" { 
            /* Save yytext before any potential unput() */
            char *kw = strdup(yytext);
            printf("KEYWORD(%s) ", kw); 
            free(kw);
          }

{IDENT}   { 
            /* Save yytext before any potential unput() */
            char *id = strdup(yytext);
            process_identifier(id);
            free(id);
          }

{DIGIT}+  { 
            /* Save yytext before any potential unput() */
            char *num = strdup(yytext);
            printf("NUMBER(%s) ", num);
            free(num);
          }

.         { 
            /* Save the character before any potential unput() */
            char c = yytext[0];
            handle_backtracking(c);
          }

%%

void count_lines(void) {
    /* Count lines using input() */
    int c;
    while ((c = input()) != EOF) {
        if (c == '\n') line_num++;
    }
    unput(c); /* Push back EOF */
}

void process_identifier(const char *text) {
    /* Peek ahead using input() and unput() */
    int c = input();
    if (c == '(') {
        printf("FUNCTION(%s) ", text);
    } else {
        unput(c);
        printf("IDENTIFIER(%s) ", text);
    }
}

void handle_quoted_string(void) {
    /* Process quoted string with input() and error recovery */
    int c;
    char *buf = malloc(100);
    int i = 0;
    
    while ((c = input()) != EOF && c != '"' && i < 99) {
        if (c == '\\') {
            c = input(); /* Handle escape */
            if (c == EOF) break;
        }
        buf[i++] = c;
        if (c == '\n') line_num++;
    }
    
    buf[i] = '\0';
    
    if (c == '"') {
        printf("STRING(%s) ", buf);
    } else {
        unput(c); /* Push back the non-quote character */
        printf("UNTERMINATED_STRING(%s) ", buf);
    }
    
    free(buf);
}

void handle_backtracking(char c) {
    /* Demonstrate backtracking with unput() */
    switch (c) {
        case '+': {
            int next = input();
            if (next == '+') {
                printf("INCREMENT ");
            } else {
                unput(next);
                printf("PLUS ");
            }
            break;
        }
        case '-': {
            int next = input();
            if (next == '-') {
                printf("DECREMENT ");
            } else {
                unput(next);
                printf("MINUS ");
            }
            break;
        }
        case '=': {
            int next = input();
            if (next == '=') {
                printf("EQUALS ");
            } else {
                unput(next);
                printf("ASSIGN ");
            }
            break;
        }
        default:
            printf("UNKNOWN_CHAR(%c) ", c);
            break;
    }
}

int main(int ac, char *av[]) {
    ++av; --ac;
    if (ac > 0) {
        yyin = fopen(*av, "r");
    } else {
        yyin = stdin;
    }
    yyout = stdout;

    yylex();
	printf("\nTotal lines processed: %d\n", line_num);
}


