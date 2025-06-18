pub const noRejectFallback =
\\inline fn REJECT() void { @panic("REJECT used but not detected"); }
;

pub const rejectDefinition =
\\inline fn REJECT() void {
\\    yy_rejected = true;
\\    yy_buf_pos = start_pos;
\\    yy_reject[@intCast(default_las)] += 1;
\\}
\\
;

pub const rejectResetDirective =
\\        if (!yy_rejected) @memset(yy_reject[0..], 0);
\\
;

pub const rejectBodySectionThree = 
\\
\\        yy_rejected = false;
\\
\\        while (true) {
\\            last_read_c = yy_read_char();
\\            if (last_read_c == EOF) break;
\\
;

pub const rejectBodySectionThreeP2 =
\\
\\            if (next_state == -1 and bol_next_state == -1) break;
\\
\\            state = next_state;
\\            bol_state = bol_next_state;
\\            cur_pos = yy_buf_pos;
\\
\\            if (bol_state != -1 and yy_accept[@intCast(bol_state)][yy_reject[@intCast(bol_state)]] > 0) {
\\                bol_las = bol_state;
\\                bol_lap = cur_pos;
\\            }
\\
\\            if (state != -1 and yy_accept[@intCast(state)][yy_reject[@intCast(state)]] > 0) {
\\                default_las = state;
\\                default_lap = cur_pos;
\\            }
\\        }
\\
\\        if (bol_las > 0) {
\\            if (bol_lap > default_lap) {
\\                default_las = bol_las;
\\                default_lap = bol_lap;
\\            } else if (bol_lap == default_lap 
\\                and yy_accept[@intCast(bol_las)][yy_reject[@intCast(bol_las)]] < 
\\                    yy_accept[@intCast(default_las)][yy_reject[@intCast(default_las)]]) 
\\            {
\\                default_las = bol_las;
\\                default_lap = bol_lap;
\\            }
\\        }
\\
\\        if (default_las > 0) {
\\            yy_buf_pos = default_lap;
\\
\\            const accept_id: usize = @intCast(yy_accept[@intCast(default_las)][yy_reject[@intCast(default_las)]]);
\\
;


