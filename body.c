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
        yy_buf_pos = 0;
        if (yy_buf_len == 0) return EOF;
    }
    return yy_buffer[yy_buf_pos++];
}

// --- Push back one character ---
static void yy_unread_char(void) {
    if (yy_buf_pos > 0) yy_buf_pos--;
}

static int yy_start;

//Addition for trailing context
static int yy_tc_start;
static int yy_tc_run = 0;
static int yy_matched_tc = 0;
static int yy_failed_tc = 0;

#define BEGIN(condition) ((yy_start) = (condition))
#define YY_AT_BOL() (yy_buf_pos == 0 || (yy_buf_pos > 0 && yy_buffer[yy_buf_pos - 1] == '\n'))
#define YY_BOL() ((yy_start >> 16))
static inline int yy_action(int accept_id) {
    switch (accept_id) {
        case 1:
{ printf("Exit!\n"); return 0; }
        break;
        case 2:
{ BEGIN(CMD); printf("-> Entering CMD mode\n"); }
        break;
        case 3:
{ BEGIN(INITIAL); printf("-> Exiting CMD mode\n"); }
        break;
        case 4:
{ printf("CMD token: %s\n", yytext); }
        break;
        case 5:
{ printf("Matched 'foo' before 'bar' or 'baz'\n"); }
        break;
        case 6:
{ printf("Matched 'hello' before 'world'\n"); }
        break;
        case 7:
{ printf("Matched putain before merde or dieu\n"); }
        break;
        case 8:
{ printf("Saw 'end'\n"); }
        break;
        case 9:
{ printf("Goodbye at line start before 'world'\n"); }
        break;
        case 10:
{ printf("Word: %s\n", yytext); }
        break;
        case 11:
{ /* consume unknown */ }
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
    int yy_failed_at_bol = 0;

    while (1) {
        int state = (yy_start & 0xFFFF);

        int yy_at_bol = yy_failed_at_bol ? 0 : YY_AT_BOL();
		int yy_tc = yy_failed_tc ? 0 : yy_tc_run;

        state = yy_at_bol ? YY_BOL() : state;
		state = yy_tc ? yy_tc_start : state;

		printf("yy_at_bol: %d\n", yy_at_bol);

        yy_failed_at_bol = 0;

        int last_accepting_state = -1;
        int last_accepting_pos = -1;

        int start_pos = yy_buf_pos;
        int cur_pos = start_pos;
        int last_read_c = -1;

        while (1) {
            last_read_c = yy_read_char();
            if (last_read_c == EOF) break;

            last_read_c = (unsigned char) last_read_c;

            int sym = yy_ec[last_read_c];

            /*fprintf(stderr, "-------- EC: %d\n", sym);*/
            /*fprintf(stderr, "-------- State: %d\n", state);*/
            int trans_index = yy_base[state] + sym;
            /*fprintf(stderr, "-------- TransIndex: %d\n", trans_index);*/
            int next_state = yy_next_state(state, sym);

			/*printf("next_state: %d\n", next_state);*/

            if (next_state < 0) {
                break;
            }

            state = next_state;
            cur_pos = yy_buf_pos;

            if (yy_accept[state] > 0) {
				if (yy_failed_tc == 1 && yy_accept[yy_accept[state]] != 0) {
					continue;
				}
				last_accepting_state = state;
				last_accepting_pos = cur_pos;
				//If the rule has a trailing context and we haven't tried it yet, try it
				if (yy_failed_tc == 0 && yy_acclist[yy_accept[state]] != 0) break;
            }
        }
		printf("Fails ? %d\n", last_accepting_pos <= 0);

		/*printf("tc_run: %d, yy_matched_tc: %d, yy_tc_start: %d\n", yy_tc_run, yy_matched_tc, yy_tc_start);*/

        if (last_accepting_state <= 0 && yy_at_bol) {
			printf("Reroll\n");
            while (yy_buf_pos > start_pos) {
                yy_unread_char();
            }
            yy_failed_at_bol = 1;
			if (yy_tc_run == 1) yy_failed_tc = 1;
            continue;
        }

        if (last_accepting_state > 0) {
			if (yy_tc_run) {
				yy_matched_tc = 1;
				return 0;
			}
            // Backtrack
            while (yy_buf_pos > last_accepting_pos) {
                yy_unread_char();
            }

            int accept_id = yy_accept[last_accepting_state];

			/*printf("Accept state: %d\n", accept_id);*/
			if (yy_tc_run == 0 && yy_acclist[accept_id] != 0) {
				int backup_pos = yy_buf_pos;
				yy_tc_start = yy_acclist[accept_id];

				yy_failed_tc = 0;
				yy_tc_run = 1;
				yylex();
				yy_tc_run = 0;

				if (yy_matched_tc == 1) {
					yy_buf_pos = backup_pos;
					yy_matched_tc = 0;
					yy_tc_start = 0;
					/*printf("Matched tc\n");*/
				} else {
					/*printf("Failed to matched tc\n");*/
					while (yy_buf_pos > start_pos) {
						yy_unread_char();
					}
					yy_failed_tc = 1;
					continue;
					/*return 0;*/
				}
			}

            yyleng = last_accepting_pos - start_pos;
            yytext = &yy_buffer[start_pos];

            //Save the last read character, in case yytext is used as a string in any action
            unsigned char yy_hold_char = yytext[yyleng];
            yytext[yyleng] = '\0'; 
			/*printf("yytext: %s\n", yytext);*/

            yy_action(accept_id);
            yytext[yyleng] = yy_hold_char;

            continue;
        }
		if (yy_tc_run == 1) return 0;
		printf("Salope\n");

        //DO BEFORE ACTION
        yytext = &yy_buffer[start_pos];
        yyleng = (int) (yy_buf_pos - start_pos);

        //ECHO
        fwrite(yytext, yyleng, 1, yyout);

        if (last_read_c == -1 || yy_buffer[yy_buf_pos] == 0) break;
		//Leave trailing context run
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




