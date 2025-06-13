const Templates = @This();

pub const noYYmoreFallback =
\\fn yymore() void { @panic("yymore used but not detected"); }
\\
;

pub const yyMoreSectionOne =
\\        yy_more_flag = 0;
;

pub const tcBacktracking = 
\\
\\            if (yy_acclist[accept_id] != 0) {
\\                yy_buf_pos = start_pos;
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
\\                yy_buf_pos = tc_lap;
\\                default_lap = tc_lap;
\\            }
;

//Actions


pub const yyMoreSectionTwo =
\\
\\            if (yy_more_len != 0) {
\\                /*printf("Start pos: %d, yyleng: %d\n", start_pos, yyleng);*/
\\                yytext = &yy_buffer[start_pos - yyleng];
\\                yyleng += (default_lap - start_pos);
\\            } else {
\\                yytext = &yy_buffer[start_pos];
\\                yyleng = default_lap - start_pos;
\\                yy_more_len = 0;
\\            }
\\
\\            YY_DO_BEFORE_ACTION
\\
\\
;

pub const yyMoreBodySectionFive = 
\\
\\            if (!yy_more_flag) yy_more_len = 0;
\\
\\            if (!yy_hold_char_restored) {
\\                yy_buffer[yy_buf_pos] = yy_hold_char;
\\            }
\\            continue;
\\        }
\\
;

pub const yyMoreBodySectionSix =
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
