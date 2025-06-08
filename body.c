#define YY_BUF_SIZE 8192
static char yy_buffer[YY_BUF_SIZE];
static char *yytext = NULL;
static int yyleng = 0;

static int yy_buf_pos = 0;
static int yy_buf_len = 0;

FILE *yyin = NULL; // input stream
FILE *yyout = NULL;


// --- Read one character ---
static int yy_read_char(void) {
    if (yy_buf_pos >= yy_buf_len) {
        yy_buf_len = fread(yy_buffer, 1, YY_BUF_SIZE, yyin);
		// yy_buf_pos = 0;
        if (yy_buf_len == 0) return EOF;
    }
    return yy_buffer[yy_buf_pos++];
}

// --- Push back one character ---
inline static void yy_unread_char(void) {
    if (yy_buf_pos > 0) yy_buf_pos--;
}

static int yy_start;

#define BEGIN(condition) ((yy_start) = (condition))
#define YY_AT_BOL() (yy_buf_pos == 0 || (yy_buf_pos > 0 && yy_buffer[yy_buf_pos - 1] == '\n'))
#define YY_BOL() ((yy_start >> 16))
static inline int yy_action(int accept_id) {
    switch (accept_id) {
        case 1:
{
	printf("Matched foobar at bol\n");
}
        break;
        case 2:
{
	printf("Matched foobar+\n");
}
        break;
        case 3:
{
	printf("Unknow character\n");
}
        break;
        default:
            fprintf(stderr, "Unknown action id: %d\n", accept_id);
            break;
        }
    return 0;
}

static inline int yy_next_state(int s, int ec) {
    while (s != -1) {
        if (yy_check[yy_base[s] + ec] == s)
            return yy_next[yy_base[s] + ec];
        s = yy_default[s];
    }
    return s;
}

// --- Core DFA scanning function ---
int yylex(void) {
    BEGIN(INITIAL);

    if (!yyin) yyin = stdin;
    if (!yyout) yyout = stdout;

    while (1) {
        int state = (yy_start & 0xFFFF);
        int bol_state = YY_AT_BOL() ? YY_BOL() : -1;

        int default_las = -1;
		int default_lap = -1;
		int bol_las = -1;
		int bol_lap = -1;

        int start_pos = yy_buf_pos;
        int cur_pos = start_pos;
        int last_read_c = -1;
		// printf("state: %d, bol_state: %d\n", state, bol_state);

        while (1) {
            last_read_c = yy_read_char();
			printf("Read: %d %d at pos: %d\n", last_read_c, last_read_c, yy_buf_pos);

            if (last_read_c == EOF) break;
            last_read_c = (unsigned char) last_read_c;

            int sym = yy_ec[last_read_c];

            int next_state = yy_next_state(state, sym);
			int bol_next_state = yy_next_state(bol_state, sym);

			// printf("bol_next_state: %d, next_state: %d\n", bol_state, next_state);

            if (next_state < 0 && bol_state < 0) break;

			state = next_state;
			bol_state = bol_next_state;
            cur_pos = yy_buf_pos;

			if (yy_accept[bol_state] > 0) {
				bol_las = bol_state;
				bol_lap = cur_pos;
				// printf("Match bol with: %d %d\n", default_las, default_lap);
			}

            if (yy_accept[state] > 0) {
                default_las = state;
                default_lap = cur_pos;
				// printf("Match normal with: %d %d\n", default_las, default_lap);
            }
        }

		if (bol_las > 0) {
			if (bol_lap > default_lap) {
				default_las = bol_las;
				default_lap = bol_lap;
			} else if (bol_lap == default_lap && yy_accept[bol_las] < yy_accept[default_las]) {
				default_las = bol_las;
				default_lap = bol_lap;
			}
		}


        if (default_las > 0) {
			printf("buf_pos: %d, default_lap: %d\n", yy_buf_pos, default_lap);
            // Backtrack
            while (yy_buf_pos > default_lap) {
				// printf("pos: %d, default_lap: %d\n", yy_buf_pos, default_lap);
                yy_unread_char();
            }

            int accept_id = yy_accept[default_las];

            if (yy_acclist[accept_id] != 0) {
                while (yy_buf_pos > start_pos) yy_unread_char();

                // printf("Started backtraking\n");
                int tc_state = yy_acclist[accept_id];
                int tc_las = -1;
                int tc_lap = -1;

                int tc_cur_pos = start_pos;
                int last_read_c = -1;

                while (1) {
                    last_read_c = yy_read_char();
                    if (last_read_c == EOF) break;

                    last_read_c = (unsigned char) last_read_c;

                    int sym = yy_ec[last_read_c];
                    int next_state = yy_next_state(tc_state, sym);

                    if (next_state < 0) break;

                    tc_state = next_state;
                    tc_cur_pos = yy_buf_pos;

                    if (yy_accept[tc_state] > 0) {
                        tc_las = tc_state;
                        tc_lap = tc_cur_pos;
                    }
                }
                while (yy_buf_pos > tc_lap) yy_unread_char();
                default_lap = tc_lap;
            }

            yyleng = default_lap - start_pos;
            yytext = &yy_buffer[start_pos];

            //Save the last read character, in case yytext is used as a string in any action
            unsigned char yy_hold_char = yytext[yyleng];
            yytext[yyleng] = '\0'; 

            yy_action(accept_id);

            yytext[yyleng] = yy_hold_char;
			// printf("Continue\n");
            continue;
        }

        //DO BEFORE ACTION
        yytext = &yy_buffer[start_pos];
        yyleng = (int) (yy_buf_pos - start_pos);

        //ECHO
        fwrite(yytext, yyleng, 1, yyout);
		if (yy_buf_pos >= yy_buf_len) break;
	}

    return 0;
}

int main(int ac, char *av[]) {
    ++av; --ac;
    if (ac > 0) {
        yyin = fopen(*av, "r");
    } else {
        yyin = fopen("test.lang", "r");
    }
    yyout = stdout;
    yylex();
}



