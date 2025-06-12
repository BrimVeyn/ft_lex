const Templates = @This();

pub const sectionOne = \\
\\#include <stdlib.h>
\\#include <stdio.h>
\\#include <string.h>
\\#define YY_READ_SIZE 256
\\
\\//Extern variables needed by the libl
\\extern int yymore(void);
\\extern int yyless(int);
\\extern int input(void);
\\extern int unput(int);
\\extern int yywrap(void);
\\
\\extern void buffer_realloc(size_t);
\\extern int yy_read_char(void);
\\
\\extern int yyleng;
\\extern char *yytext;
\\extern uint8_t yy_hold_char;
\\extern size_t yy_buf_pos;
\\extern int yy_more_flag;
\\extern int yy_more_len;
\\extern int yy_hold_char_restored;
\\extern char *yy_buffer;
\\extern size_t yy_buf_len;
\\
\\static size_t yy_buf_size = 0;    // total allocated size
\\static int yy_interactive = 0;
\\static int yy_start;
\\
\\//Global initialization
\\char *yy_buffer = NULL;
\\size_t yy_buf_len = 0;     // number of bytes currently filled
\\size_t yy_buf_pos = 0;     // current read position
\\int yy_hold_char_restored = 0; //used when calling input and unput in the same action
\\uint8_t yy_hold_char = 0;
\\char *yytext = NULL;
\\int yyleng = 0;
\\FILE *yyin = NULL; // input stream
\\FILE *yyout = NULL;
\\
\\//yymore specific variables
\\int yy_more_len = 0;
\\int yy_more_flag = 0;
\\
\\
\\void buffer_realloc(size_t min_required) {
\\    size_t new_size = yy_buf_size == 0 ? YY_READ_SIZE : yy_buf_size;
\\
\\    if (yy_buf_size >= min_required) return ;
\\
\\    while (new_size < min_required)
\\        new_size *= 2;
\\
\\    char *new_buffer = realloc(yy_buffer, new_size);
\\    if (!new_buffer) {
\\        fprintf(stderr, "Out of memory while reallocating buffer\n");
\\        exit(1);
\\    }
\\
\\    yy_buffer = new_buffer;
\\    yy_buf_size = new_size;
\\}
\\
\\static inline void buffer_join(size_t readSize, char *buffer) {
\\    if (yy_buf_len + readSize > yy_buf_size) {
\\        buffer_realloc(yy_buf_size + readSize);
\\    }
\\
\\    memcpy(&yy_buffer[yy_buf_pos], buffer, readSize);
\\}
\\
\\static inline void buffer_join_c(char c) {
\\    if (yy_buf_len + 1 > yy_buf_size)
\\        buffer_realloc(yy_buf_size + 1);
\\
\\    yy_buffer[yy_buf_len++] = c;
\\}
\\
\\int yy_read_char(void) {
\\    if (yy_buf_pos >= yy_buf_len) {
\\        if (yy_interactive) {
\\            char c = '*';
\\            for ( int n = 0; n < yy_buf_size && (c = getc( yyin )) != EOF && c != '\n'; ++n ) {
\\                buffer_join_c(c);
\\            }
\\            if (c == '\n')
\\                buffer_join_c(c);
\\
\\            if (c == EOF) {
\\                yy_buffer[yy_buf_pos] = EOF;
\\                return EOF;
\\            }
\\        } else {
\\            char buffer[YY_READ_SIZE];
\\            memset(buffer, 0, YY_READ_SIZE);
\\
\\            int rsize = fread(buffer, 1, YY_READ_SIZE, yyin);
\\            if (rsize == 0) {
\\                yy_buffer[yy_buf_pos] = EOF;
\\            } else {
\\                buffer_join(rsize, buffer);
\\            }
\\            yy_buf_len += rsize;
\\            if (rsize == 0) return EOF;
\\        }
\\    }
\\    return yy_buffer[yy_buf_pos++];
\\}
\\
\\
\\static void yy_free_buffer(void) {
\\    free(yy_buffer);
\\    yy_buffer = NULL;
\\    yy_buf_size = yy_buf_len = yy_buf_pos = 0;
\\}
\\
\\
\\#define ECHO do { if (fwrite( yytext, (size_t) yyleng, 1, yyout )) {} } while (0)
\\#define BEGIN(condition) ((yy_start) = (condition))
\\#define YY_AT_BOL() (yy_buf_pos == 0 || (yy_buf_pos > 0 && yy_buffer[yy_buf_pos - 1] == '\n'))
\\#define YY_BOL() ((yy_start >> 16))
\\#define YY_DO_BEFORE_ACTION do { \
\\    yy_hold_char = yytext[yyleng]; \
\\    yytext[yyleng] = '\0'; \
\\    yy_hold_char_restored = 0; \
\\} while(0); \
\\
\\
;


pub const sectionTwo = \\
\\static inline int yy_next_state(int s, int ec) {
\\    while (s != -1) {
\\        if (yy_check[yy_base[s] + ec] == s)
\\            return yy_next[yy_base[s] + ec];
\\        s = yy_default[s];
\\    }
\\    return s;
\\}
\\
\\// --- Core DFA scanning function ---
\\int yylex(void) {
\\    BEGIN(INITIAL);
\\//Added if the scanner is used in reentrant mode
\\    if (yy_hold_char && !yy_hold_char_restored) {
\\        yy_buffer[yy_buf_pos] = yy_hold_char;
\\    }
\\
\\    if (!yyin) yyin = stdin;
\\    if (!yyout) yyout = stdout;
\\
\\    while (1) {
\\        int state = (yy_start & 0xFFFF);
\\        int bol_state = YY_AT_BOL() ? YY_BOL() : -1;
\\
\\        int default_las = -1;
\\        int default_lap = -1;
\\        int bol_las = -1;
\\        int bol_lap = -1;
\\
\\        int start_pos = yy_buf_pos;
\\        int cur_pos = start_pos;
\\        int last_read_c = -1;
\\
;

pub const sectionThree =
\\
\\        while (1) {
\\            last_read_c = yy_read_char();
\\            /*printf("Read: %d %d at pos: %d\n", last_read_c, last_read_c, yy_buf_pos);*/
\\
\\            if (last_read_c == EOF) break;
\\            last_read_c = (unsigned char) last_read_c;
\\
\\            int sym = yy_ec[last_read_c];
\\
\\            int next_state = yy_next_state(state, sym);
\\            int bol_next_state = yy_next_state(bol_state, sym);
\\
\\            // printf("bol_next_state: %d, next_state: %d\n", bol_next_state, next_state);
\\
\\            if (next_state < 0 && bol_next_state < 0) break;
\\
\\            state = next_state;
\\            bol_state = bol_next_state;
\\            cur_pos = yy_buf_pos;
\\
\\            if (bol_state != -1 && yy_accept[bol_state] > 0) {
\\                bol_las = bol_state;
\\                bol_lap = cur_pos;
\\                /*printf("Match bol with: %d %d\n", default_las, default_lap);*/
\\            }
\\
\\            if (state != -1 && yy_accept[state] > 0) {
\\                default_las = state;
\\                default_lap = cur_pos;
\\                /*printf("Match normal with: %d %d\n", default_las, default_lap);*/
\\            }
\\        }
\\
\\        if (bol_las > 0) {
\\            if (bol_lap > default_lap) {
\\                default_las = bol_las;
\\                default_lap = bol_lap;
\\            } else if (bol_lap == default_lap && yy_accept[bol_las] < yy_accept[default_las]) {
\\                default_las = bol_las;
\\                default_lap = bol_lap;
\\            }
\\        }
\\
\\
\\        /*printf("buf_pos: %d, default_lap: %d, default_las: %d\n", yy_buf_pos, default_lap, default_las);*/
\\        if (default_las > 0) {
\\            // Backtrack
\\            yy_buf_pos = default_lap;
\\
\\            int accept_id = yy_accept[default_las];
\\
\\
;

pub const sectionFour = 
\\
\\            yytext = &yy_buffer[start_pos];
\\            yyleng = default_lap - start_pos;
\\            YY_DO_BEFORE_ACTION
\\
\\
;

pub const sectionFive = 
\\
\\            if (!yy_more_flag) yy_more_len = 0;
\\
\\            if (!yy_hold_char_restored) {
\\                yy_buffer[yy_buf_pos] = yy_hold_char;
\\            }
\\            // printf("Continue\n");
\\            continue;
\\        }
\\
\\        if (yy_more_len) {
\\            yyleng += (int) (yy_buf_pos - start_pos);
\\        } else {
\\            yyleng = (int) (yy_buf_pos - start_pos);
\\        }
\\        yytext = &yy_buffer[start_pos - yy_more_len];
\\        yy_more_len = 0;
\\
\\        //ECHO
\\        fwrite(yytext, yyleng, 1, yyout);
\\        if (yy_buffer[yy_buf_pos] == EOF) break;
\\    }
\\
\\    yy_free_buffer();
\\    fclose(yyin);
\\    yywrap();
\\
\\    return 0;
\\}
\\
;
