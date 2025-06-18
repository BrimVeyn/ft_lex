const Templates = @This();

pub const sectionOne = \\
\\var yy_hold_char: u8 = 0;
\\var yy_hold_char_restored: bool = false;
\\
\\var yytext: []u8 = undefined;
\\var yy_buffer: []u8 = undefined;
\\var yy_buffer_initialized: bool = false;
\\var yy_buf_pos: usize = 0;
\\var yy_start: usize = 0;
\\
\\//yymore specific variables
\\var yy_more_len: usize = 0;
\\var yy_more_flag: bool = false;
\\
\\//REJECT specific
\\var yy_rejected: bool = false;
\\
\\var yyin: ?std.fs.File = null;
\\var yyout: ?std.fs.File = null;
\\
\\var yy_is_tty: bool = false;
\\const YY_BUFSIZE: usize = 2048;
\\
\\var start_pos: usize = 0;
\\var default_las: i32 = -1;
\\
\\const EOF: i32 = -1;
\\
\\fn readWholeFile(file: std.fs.File) ![]u8 {
\\    return file.readToEndAlloc(std.heap.smp_allocator, 1e9);
\\}
\\
\\fn readLine(file: std.fs.File) ![]u8 {
\\    var buffer: [YY_BUFSIZE]u8 = .{0} ** YY_BUFSIZE;
\\    var it: usize = 0;
\\    while (true): (it += 1) {
\\        buffer[it] = file.reader().readByte() catch |e| switch (e) {
\\            error.EndOfStream => 0x00,
\\            else => @panic("fatal: error while reading yyin"),
\\        };
\\        if (buffer[it] == '\n' or buffer[it] == 0x00) 
\\            return std.heap.smp_allocator.dupe(u8, buffer[0..it + 1]);
\\    }
\\    unreachable;
\\}
\\
\\fn yy_read_char() i32 {
\\    if (!yy_is_tty) {
\\        if (!yy_buffer_initialized) {
\\            yy_buffer = readWholeFile(yyin.?) catch {
\\                @panic("fatal: error while reading yyin");
\\            };
\\            yy_buffer_initialized = true;
\\        }
\\    } else {
\\        if (!yy_buffer_initialized) {
\\            const buf = readLine(yyin.?) catch return EOF;
\\            yy_buffer = buf;
\\            yy_buffer_initialized = true;
\\        }
\\        if (yy_buf_pos >= yy_buffer.len) {
\\            if (yy_buffer[yy_buffer.len - 1] == 0x00) return EOF;
\\            const rhs = readLine(yyin.?) catch return EOF;
\\            const old_len = yy_buffer.len;
\\            yy_buffer = std.heap.smp_allocator.realloc(yy_buffer, yy_buffer.len + rhs.len) catch {
\\                @panic("fatal: allocation error");
\\            };
\\            @memcpy(yy_buffer[old_len..], rhs[0..]);
\\        }
\\    }
\\
\\    if (yy_buf_pos == yy_buffer.len) return EOF;
\\
\\    defer yy_buf_pos += 1;
\\    return yy_buffer[yy_buf_pos];
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
\\inline fn YY_BOL() i16 {
\\    return @as(i16, @intCast(yy_start >> @as(u6, 16)));
\\}
\\
\\
\\inline fn yymore() void {
\\    yy_more_len = yytext.len;
\\    yy_more_flag = true;
\\}
\\
\\inline fn yyless(n: usize) void {
\\    yy_buf_pos = yy_buf_pos - yytext.len + n;
\\    yytext = yytext[0..n];
\\}
\\
\\fn input() i32 {
\\    const c = yy_read_char();
\\    return if (c == EOF) 0x00 else c;
\\}
\\
\\fn unput(c: u8) void {
\\    yy_buffer = std.heap.smp_allocator.realloc(yy_buffer, yy_buffer.len + 1) catch {
\\        @panic("fatal: allocation error");
\\    };
\\
\\    std.mem.copyBackwards(u8, yy_buffer[yy_buf_pos + 1..], yy_buffer[yy_buf_pos..yy_buffer.len - 1]);
\\    yy_buffer[yy_buf_pos] = c;
\\}
\\
;

pub const nextStateFn =
\\inline fn yy_next_state(state: usize, symbol: u8) i16 {
\\    var s = state;
\\    while (true) {
\\        if (yy_check[@intCast(yy_base[s] + symbol)] == s)
\\            return yy_next[@intCast(yy_base[s] + symbol)];
\\        s = if (yy_default[s] == -1) 
\\                return -1 
\\            else @intCast(yy_default[s]);
\\    }
\\}
\\
;

pub const defaultYyWrap =
\\
\\fn yywrap() i32 {
\\    return 1;
\\}
\\
\\
;


pub const sectionTwo = \\
\\
\\fn yylex() !i32 {
\\    BEGIN(.INITIAL);
\\
\\    if (yyin == null) yyin = stdin;
\\    if (yyout == null) yyout = stdout;
\\
\\    if (yyin.?.isTty()) yy_is_tty = true;
\\
\\    while (true) {
\\        var state: i16 = @intCast(yy_start & 0xFFFF);
\\        var bol_state: i16 = if (YY_AT_BOL()) YY_BOL() else -1;
\\
\\        default_las = -1;
\\        var bol_las: i32 = -1;
\\        var bol_lap: usize = 0;
\\        var default_lap: usize = 0;
\\
\\
\\        start_pos = yy_buf_pos;
\\        var cur_pos = start_pos;
\\        var last_read_c = EOF;
\\
\\
;

pub const nextLogic =
\\            const sym = yy_ec[@intCast(last_read_c)];
\\
\\            const next_state = yy_next_state(@intCast(state), sym);
\\            const bol_next_state = if (bol_state == -1) -1 
\\                else yy_next_state(@intCast(bol_state), sym);
;

pub const nextLogicFast =
\\            const next_state = yy_next[@intCast(state)][@intCast(last_read_c)];
\\            const bol_next_state = if (bol_state == -1) -1 
\\                else yy_next[@intCast(bol_state)][@intCast(last_read_c)];
\\
;

pub const sectionThree =
\\
\\        while (true) {
\\            last_read_c = yy_read_char();
\\            if (last_read_c == EOF) break;
\\
;

pub const sectionThreeP2 =
\\
\\            if (next_state == -1 and bol_next_state == -1) break;
\\
\\            state = next_state;
\\            bol_state = bol_next_state;
\\            cur_pos = yy_buf_pos;
\\
\\            if (bol_state != -1 and yy_accept[@intCast(bol_state)] > 0) {
\\                bol_las = bol_state;
\\                bol_lap = cur_pos;
\\            }
\\
\\            if (state != -1 and yy_accept[@intCast(state)] > 0) {
\\                default_las = state;
\\                default_lap = cur_pos;
\\            }
\\        }
\\
\\        if (bol_las > 0) {
\\            if (bol_lap > default_lap) {
\\                default_las = bol_las;
\\                default_lap = @intCast(bol_lap);
\\            } else if (bol_lap == default_lap and yy_accept[@intCast(bol_las)] < yy_accept[@intCast(default_las)]) {
\\                default_las = bol_las;
\\                default_lap = @intCast(bol_lap);
\\            }
\\        }
\\
\\
\\        if (default_las > 0) {
\\            yy_buf_pos = default_lap;
\\            const accept_id: usize = @intCast(yy_accept[@intCast(default_las)]);
\\
;

pub const sectionFour = 
\\
\\            yytext = yy_buffer[start_pos..yy_buf_pos];
\\
\\
;


pub const sectionFive = 
\\            continue;
\\        }
\\
;

pub const sectionSix =
\\        yytext = yy_buffer[start_pos..yy_buf_pos];
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



pub const defaultMain =
\\
\\pub fn main() !u8 {
\\    var argIt = std.process.args();
\\    _ = argIt.skip();
\\
\\    if (argIt.next()) |filename| {
\\        yyin = try std.fs.cwd().openFile(filename, .{});
\\    } else {
\\        yyin = stdin;
\\    }
\\    _ = try yylex();
\\    return 0;
\\}
\\
;
