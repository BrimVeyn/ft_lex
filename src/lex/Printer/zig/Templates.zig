const Templates = @This();

pub const sectionOne = \\
\\var yy_hold_char: u8 = 0;
\\var yy_hold_char_restored: bool = false;
\\
\\var yytext: []u8 = undefined;
\\var yy_buffer: []u8 = undefined;
\\var yy_buf_pos: usize = 0;
\\
\\var yy_interactive: bool = 0;
\\var yy_start: usize = 0;
\\
\\//yymore specific variables
\\var yy_more_len: usize = 0;
\\var yy_more_flag: bool = false;
\\
\\//REJECT specific
\\var yy_rejected: bool = 0;
\\
\\var yyin: ?std.fs.File = null;
\\var yyout: ?std.fs.File = null;
\\
\\
\\fn readWholeFile(file: std.fs.File) ![]u8 {
\\    return file.readToEndAlloc(std.heap.smp_allocator, 1e9);
\\}
\\
\\fn yy_free_buffer() void {
\\    std.heap.smp_allocator.free(yy_buffer);
\\}
\\
\\inline fn BEGIN(condition: SC) void {
\\    yy_start = @intFromEnum(condition);
\\}
\\
\\inline fn ECHO() void {
\\    if (yyout) |out| {
\\        _ = out.writer().print("{s}", .{yytext}) catch @panic("fatal: yyout write error");
\\    } else @panic("fatal: yyout is not defined");
\\}
\\
\\inline fn YY_AT_BOL() bool {
\\    return (yy_buf_pos == 0 or (yy_buf_pos > 0 and yy_buffer[yy_buf_pos - 1] == '\n'));
\\}
\\
\\inline fn YY_BOL() usize {
\\    return yy_start >> @as(u6, 16);
\\}
\\
\\inline fn YY_DO_BEFORE_ACTION() void {
\\    yy_hold_char = yytext[yytext.len];
\\    yytext[yytext.len] = 0x00;
\\    yy_hold_char_restored = false;
\\}
\\
\\inline fn yy_next_state(state: usize, symbol: u8) i16 {
\\    var s = state;
\\    while (true) {
\\        if (yy_check[@as(usize, @intCast(yy_base[s])) + symbol] == s)
\\        return yy_next[@as(usize, @intCast(yy_base[s])) + symbol];
\\        s = if (yy_default[s] == -1) return -1 else @intCast(yy_default[s]);
\\    }
\\}
\\
;


pub const sectionTwo = \\
\\
\\fn yylex(void) i32 {
\\    BEGIN(INITIAL);
\\
\\    if (yy_hold_char and !yy_hold_char_restored) {
\\        yy_buffer[yy_buf_pos] = yy_hold_char;
\\    }
\\
\\    if (yyin == null) yyin = stdin;
\\    if (yyout == null) yyout = stdout;
\\
\\    while (true) {
\\        var state: usize = (yy_start & 0xFFFF);
\\        var bol_state: i32 = if (YY_AT_BOL()) YY_BOL() else -1;
\\
\\        var default_las: i32 = -1;
\\        var default_lap: i32 = -1;
\\        var bol_las: i32 = -1;
\\        var bol_lap: i32 = -1;
\\
\\        var start_pos = yy_buf_pos;
\\        var cur_pos = start_pos;
\\        var last_read_c: i32 = -1;
\\
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
\\            if (!yy_hold_char_restored) {
\\                yy_buffer[yy_buf_pos] = yy_hold_char;
\\            }
\\            continue;
\\        }
\\
;

pub const sectionSix =
\\        yyleng = (int) (yy_buf_pos - start_pos);
\\        yytext = &yy_buffer[start_pos];
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
