#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern int yy_hold_char_restored;
extern char *yytext; 
extern int yyleng;
extern uint8_t yy_hold_char;
extern int yy_buf_len;
extern char *yy_buffer;
extern size_t yy_buf_pos;
extern int yy_more_len;
extern int yy_more_flag;
extern int yy_read_char(void);
extern void buffer_realloc(size_t);
extern int yylex(void);

int unput(int c) {
    char *yy_cp;

    buffer_realloc(yy_buf_len + 1);

    if (!yy_hold_char_restored) {
        yy_cp = &yy_buffer[yy_buf_pos];
        *yy_cp = yy_hold_char;
    }

    memmove(&yy_buffer[yy_buf_pos + 1], &yy_buffer[yy_buf_pos], (yy_buf_len - yy_buf_pos));
    yy_buffer[yy_buf_pos] = (unsigned char) c;
    yy_buf_len += 1;

    if (!yy_hold_char_restored) {
        yy_hold_char = *yy_cp;
    }

	return c;
}

int input(void) {
    if (!yy_hold_char_restored) {
        yytext[yyleng] = yy_hold_char;
        yy_hold_char_restored = 1;
    }
    int c = yy_read_char();
    return c == EOF ? 0 : c;
}

int yyless(int n) {
    yytext[yyleng] = yy_hold_char;
    yy_hold_char = yytext[n];
    yy_buf_pos = yy_buf_pos - yyleng + n;
    yyleng = n;
    yytext[yyleng] = '\0';
    return 0;
}

int yymore(void) {
    yy_more_len = yyleng;
    yy_more_flag = 1;
    return 0;
}

__attribute__((weak))
int yywrap(void) {
	return 1;
}

__attribute__((weak))
int	 main(void) {
	yylex();
	return 0;
}
