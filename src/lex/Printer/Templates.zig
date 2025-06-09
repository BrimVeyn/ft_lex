const Templates = @This();

pub const bodyFirstPart = \\
\\#include <stdlib.h>
\\#include <unistd.h>
\\#include <stdio.h>
\\#include <string.h>
\\#define YY_READ_SIZE 16
\\
\\static char *yy_buffer = NULL;
\\static size_t yy_buf_size = 0;    // total allocated size
\\static size_t yy_buf_len = 0;     // number of bytes currently filled
\\static size_t yy_buf_pos = 0;     // current read position
\\
\\static char *yytext = NULL;
\\static int yyleng = 0;
\\
\\FILE *yyin = NULL; // input stream
\\FILE *yyout = NULL;
\\
\\static int yy_interactive = 0;
\\
\\static void buffer_realloc(size_t min_required) {
\\    size_t new_size = yy_buf_size == 0 ? YY_READ_SIZE : yy_buf_size;
\\
\\    if (yy_buf_size >= min_required) return ;
\\
\\    while (new_size < min_required)
\\        new_size *= 2;
\\
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
\\static int yy_read_char(void) {
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
\\static inline void yy_unread_char(void) {
\\    if (yy_buf_pos > 0) yy_buf_pos--;
\\}
\\
\\static void yy_free_buffer(void) {
\\    free(yy_buffer);
\\    yy_buffer = NULL;
\\    yy_buf_size = yy_buf_len = yy_buf_pos = 0;
\\}
\\static int yy_start;
\\
\\#define BEGIN(condition) ((yy_start) = (condition))
\\#define YY_AT_BOL() (yy_buf_pos == 0 || (yy_buf_pos > 0 && yy_buffer[yy_buf_pos - 1] == '\n'))
\\#define YY_BOL() ((yy_start >> 16))
\\
\\
;

pub const bodySecondPart = \\
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
\\
\\    if (!yyin) yyin = stdin;
\\    if (!yyout) yyout = stdout;
\\    int yy_failed_at_bol = 0;
\\
\\    while (1) {
\\        int state = (yy_start & 0xFFFF);
\\
\\        int yy_at_bol = yy_failed_at_bol ? 0 : YY_AT_BOL();
\\
\\        state = yy_at_bol ? YY_BOL() : state;
\\
\\        yy_failed_at_bol = 0;
\\
\\        int last_accepting_state = -1;
\\        int last_accepting_pos = -1;
\\
\\        int start_pos = yy_buf_pos;
\\        int cur_pos = start_pos;
\\        int last_read_c = -1;
\\
\\        while (1) {
\\            last_read_c = yy_read_char();
\\            if (last_read_c == EOF) break;
\\
\\            last_read_c = (unsigned char) last_read_c;
\\
\\            int sym = yy_ec[last_read_c];
\\
\\            /*fprintf(stderr, "-------- EC: %d\n", sym);*/
\\            /*fprintf(stderr, "-------- State: %d\n", state);*/
\\            int trans_index = yy_base[state] + sym;
\\            /*fprintf(stderr, "-------- TransIndex: %d\n", trans_index);*/
\\            int next_state;
\\
\\            next_state = yy_next_state(state, sym);
\\
\\            if (next_state < 0) {
\\                break;
\\            }
\\
\\            state = next_state;
\\            cur_pos = yy_buf_pos;
\\
\\            if (yy_accept[state] > 0) {
\\                last_accepting_state = state;
\\                last_accepting_pos = cur_pos;
\\            }
\\        }
\\        // fprintf(stderr, "BREAK\n");
\\        if (last_accepting_state <= 0 && yy_at_bol) {
\\            while (yy_buf_pos > start_pos) {
\\                yy_unread_char();
\\            }
\\            yy_failed_at_bol = 1;
\\            continue;
\\        }
\\
\\        if (last_accepting_state > 0) {
\\            // Backtrack
\\            while (yy_buf_pos > last_accepting_pos) {
\\                yy_unread_char();
\\            }
\\
\\            yyleng = last_accepting_pos - start_pos;
\\            yytext = &yy_buffer[start_pos];
\\
\\            //Save the last read character, in case yytext is used as a string in any action
\\            unsigned char yy_hold_char = yytext[yyleng];
\\            yytext[yyleng] = '\0'; 
\\
\\            int accept_id = yy_accept[last_accepting_state];
\\            yy_action(accept_id);
\\
\\            yytext[yyleng] = yy_hold_char;
\\            continue;
\\        }
\\
\\        //DO BEFORE ACTION
\\        yytext = &yy_buffer[start_pos];
\\        yyleng = (int) (yy_buf_pos - start_pos);
\\
\\        //ECHO
\\        fwrite(yytext, yyleng, 1, yyout);
\\
\\        if (last_read_c == -1 || yy_buffer[yy_buf_pos] == 0) break;
\\    }
\\
\\    return 0;
\\}
\\
;


pub const bodySecondPartWithTc = \\
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
\\        // printf("state: %d, bol_state: %d\n", state, bol_state);
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
\\            // printf("bol_next_state: %d, next_state: %d\n", bol_state, next_state);
\\
\\            if (next_state < 0 && bol_state < 0) break;
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
\\            while (yy_buf_pos > default_lap) {
\\                /*printf("pos: %d, default_lap: %d\n", yy_buf_pos, default_lap);*/
\\                yy_unread_char();
\\            }
\\
\\            int accept_id = yy_accept[default_las];
\\
\\            if (yy_acclist[accept_id] != 0) {
\\                while (yy_buf_pos > start_pos) yy_unread_char();
\\
\\                // printf("Started backtraking\n");
\\                int tc_state = yy_acclist[accept_id];
\\                int tc_las = -1;
\\                int tc_lap = -1;
\\
\\                int tc_cur_pos = start_pos;
\\                int last_read_c = -1;
\\
\\                while (1) {
\\                    last_read_c = yy_read_char();
\\                    if (last_read_c == EOF) break;
\\
\\                    last_read_c = (unsigned char) last_read_c;
\\
\\                    int sym = yy_ec[last_read_c];
\\                    int next_state = yy_next_state(tc_state, sym);
\\
\\                    if (next_state < 0) break;
\\
\\                    tc_state = next_state;
\\                    tc_cur_pos = yy_buf_pos;
\\
\\                    if (yy_accept[tc_state] > 0) {
\\                        tc_las = tc_state;
\\                        tc_lap = tc_cur_pos;
\\                    }
\\                }
\\                while (yy_buf_pos > tc_lap) yy_unread_char();
\\                default_lap = tc_lap;
\\            }
\\
\\            yyleng = default_lap - start_pos;
\\            yytext = &yy_buffer[start_pos];
\\
\\            //Save the last read character, in case yytext is used as a string in any action
\\            unsigned char yy_hold_char = yytext[yyleng];
\\            yytext[yyleng] = '\0'; 
\\
\\            yy_action(accept_id);
\\
\\            yytext[yyleng] = yy_hold_char;
\\            // printf("Continue\n");
\\            continue;
\\        }
\\
\\        //DO BEFORE ACTION
\\        yytext = &yy_buffer[start_pos];
\\        yyleng = (int) (yy_buf_pos - start_pos);
\\
\\        //ECHO
\\        fwrite(yytext, yyleng, 1, yyout);
\\        if (yy_buffer[yy_buf_pos] == EOF) break;
\\    }
\\
\\    yy_free_buffer();
\\    fclose(yyin);
\\
\\    return 0;
\\}
\\
;


pub const defaultMain = \\
\\int main(int ac, char *av[]) {
\\    ++av; --ac;
\\    if (ac > 0) {
\\        yyin = fopen(*av, "r");
\\    } else {
\\        yyin = fopen("test.lang", "r");
\\    }
\\    yyout = stdout;
\\    yylex();
\\}
\\
;
