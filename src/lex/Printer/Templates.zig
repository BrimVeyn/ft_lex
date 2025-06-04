const Templates = @This();

pub const bodyFirstPart = \\
\\#define YY_BUF_SIZE 8192
\\static char yy_buffer[YY_BUF_SIZE];
\\static char *yytext = NULL;
\\static int yyleng = 0;
\\
\\static int yy_buf_pos = 0;
\\static int yy_buf_len = 0;
\\
\\FILE *yyin = NULL; // input stream
\\FILE *yyout = NULL;
\\
\\
\\// --- Read one character ---
\\static int yy_read_char(void) {
\\    if (yy_buf_pos >= yy_buf_len) {
\\        yy_buf_len = fread(yy_buffer, 1, YY_BUF_SIZE, yyin);
\\        yy_buf_pos = 0;
\\        if (yy_buf_len == 0) return EOF;
\\    }
\\    return yy_buffer[yy_buf_pos++];
\\}
\\
\\// --- Push back one character ---
\\static void yy_unread_char(void) {
\\    if (yy_buf_pos > 0) yy_buf_pos--;
\\}
\\
\\static int yy_start;
\\
\\#define BEGIN(condition) ((yy_start) = (condition))
\\#define YY_AT_BOL() (yy_buf_pos == 0 || (yy_buf_pos > 0 && yy_buffer[yy_buf_pos - 1] == '\n'))
\\#define YY_BOL() ((yy_start >> 16))
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
\\    int yy_failed_at_bol = 0;
\\
\\    int i = 0;
\\    while (i++ < 1000) {
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
\\        if (yy_buffer[yy_buf_pos] == 0) break;
\\    }
\\
\\    return 0;
\\}
;

pub const defaultMain = \\
\\int main(int ac, char *av[]) {
\\    ++av; --ac;
\\      if (ac > 0) {
\\          yyin = fopen(*av, "r");
\\      } else {
\\          yyin = fopen("test.lang", "r");
\\      }
\\    yyout = stdout;
\\    yylex();
\\}
\\
;
