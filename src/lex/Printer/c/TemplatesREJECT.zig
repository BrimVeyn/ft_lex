pub const noRejectFallback =
\\#define REJECT reject_used_but_not_detected
\\
;

pub const rejectDefinition =
\\#define REJECT do  {\
\\    if (!yy_hold_char_restored) { \
\\        yy_buffer[yy_buf_pos] = yy_hold_char; \
\\        yy_hold_char_restored = 1; \
\\    } \
\\    yy_rejected = 1; \
\\    yy_buf_pos = start_pos; \
\\    yy_reject[default_las] += 1; \
\\    goto find_rule; \
\\} while(0);
\\
;

pub const rejectResetDirective =
\\        if (!yy_rejected) memset(yy_reject, 0, sizeof(yy_reject));
;

pub const rejectBodySectionThree = 
\\        yy_rejected = 0;
\\
\\        while (1) {
\\            last_read_c = yy_read_char();
\\
\\            if (last_read_c == EOF) break;
\\            last_read_c = (unsigned char) last_read_c;
\\
;

pub const rejectBodySectionThreeP2 =
\\
\\            if (next_state < 0 && bol_next_state < 0) break;
\\
\\            state = next_state;
\\            bol_state = bol_next_state;
\\            cur_pos = yy_buf_pos;
\\
\\            if (bol_state != -1 && yy_accept[bol_state][yy_reject[bol_state]] > 0) {
\\                bol_las = bol_state;
\\                bol_lap = cur_pos;
\\            }
\\
\\            if (state != -1 && yy_accept[state][yy_reject[state]] > 0) {
\\                default_las = state;
\\                default_lap = cur_pos;
\\            }
\\        }
\\
\\        if (bol_las > 0) {
\\            if (bol_lap > default_lap) {
\\                default_las = bol_las;
\\                default_lap = bol_lap;
\\            } else if (bol_lap == default_lap && yy_accept[bol_las][yy_reject[bol_las]] < yy_accept[default_las][yy_reject[default_las]]) {
\\                default_las = bol_las;
\\                default_lap = bol_lap;
\\            }
\\        }
\\
\\        if (default_las > 0) {
\\            yy_buf_pos = default_lap;
\\
\\            int accept_id = yy_accept[default_las][yy_reject[default_las]];
;


