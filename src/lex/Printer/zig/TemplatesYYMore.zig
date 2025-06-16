const Templates = @This();

pub const noYYmoreFallback = "";

pub const yyMoreSectionOne =
\\        yy_more_flag = false;
;

pub const tcBacktracking = 
\\
\\            if (yy_acclist[accept_id] != 0) {
\\                yy_buf_pos = start_pos;
\\
\\                var tc_state: i16 = yy_acclist[accept_id];
\\                var tc_cur_pos: usize = start_pos;
\\
\\                var tc_lap: usize = 0;
\\                var tc_last_c: i32 = -1;
\\
\\                while (true) {
\\                    tc_last_c = yy_read_char();
\\                    if (tc_last_c == EOF) break;
\\
\\                    const sym: u8 = yy_ec[@intCast(tc_last_c)];
\\                    const next_state: i16 = yy_next_state(@intCast(tc_state), sym);
\\
\\                    if (next_state < 0) break;
\\
\\                    tc_state = next_state;
\\                    tc_cur_pos = yy_buf_pos;
\\
\\                    if (yy_accept[@intCast(tc_state)] > 0)
\\                        tc_lap = tc_cur_pos;
\\                }
\\                yy_buf_pos = tc_lap;
\\            }
\\
;

//Actions

pub const yyMoreSectionTwo =
\\
\\            if (yy_more_len != 0) 
\\                yytext = yy_buffer[(start_pos - yy_more_len)..yy_buf_pos]
\\            else {
\\                yytext = yy_buffer[start_pos..yy_buf_pos];
\\                yy_more_len = 0;
\\            }
\\
\\            YY_DO_BEFORE_ACTION();
\\
;

pub const yyMoreBodySectionFive = 
\\
\\            if (!yy_more_flag) 
\\                yy_more_len = 0;
\\
\\            continue;
\\        }
\\
;

pub const yyMoreBodySectionSix =
\\        yytext = yy_buffer[start_pos - yy_more_len..yy_buf_pos];
\\        yy_more_len = 0;
\\
\\        _ = yyout.?.write(yytext) catch {};
\\        if (yy_buf_pos == yy_buffer.len and last_read_c == EOF) break;
\\    }
\\
\\    yy_free_buffer();
\\    yyin.?.close();
\\    _ = yywrap();
\\    return 0;
\\}
\\
;
