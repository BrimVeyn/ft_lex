const std               = @import("std");
const print             = std.debug.print;
const mem               = std.mem;

const G                 = @import("../globals.zig");
const DefinitionModule  = @import("Definitions.zig");
const Definitions       = DefinitionModule.Definitions;

const RulesModule       = @import("Rules.zig");
const Rule              = RulesModule.Rule;

pub const LexTokenizer = struct {

    pub const SCKind = enum {
        Inclusive,
        Exclusive,
    };
    
    pub const LexTokenizerError = error {
        UnrecognizedPercentDirective,
        UnexpectedEOF,
        BadCharacter,
        BadNumber,
        IncompleteNameDefinition,
    } || error { OutOfMemory };

    pub const LexTokenizerCtx = enum {
        Definitions,
        Rules,
        UserSubroutines,
    };

    pub const ParamType = union(enum) {
        nPositions: usize,
        nStates: usize,
        nTransitions: usize,
        nParseTreeNodes: usize,
        nPackedCharacterClass: usize,
        nOutputArray: usize,
        YYTextType: Definitions.YYTextType,
    }; 

    pub const LexToken = union(enum) {
        comment: void,
        cCode: Definitions.CCode,
        definition: Definitions.Definition,
        EndOfSection: void,
        EOF: void,
        param: ParamType,
        rule: Rule,
        userSuboutines: []u8,
        startCondition: struct {
            type: LexTokenizer.SCKind,
            name: std.ArrayList([]u8),

            pub fn jsonStringify(self: @This(), jws: anytype) !void {
                try jws.beginObject();
                try jws.objectField("type");
                try jws.write(@tagName(self.type));
                try jws.objectField("names");
                try jws.beginArray();
                for (self.name.items) |seq| { try jws.print("{s}", .{seq}); }
                try jws.endArray();
                try jws.endObject();
            }
        },

        pub fn format(self: *const LexToken, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt; _ = options;
            const jsonOpts: std.json.StringifyOptions = .{ .whitespace = .indent_2 };
            switch (self.*) {
                .rule => |rule| try std.json.stringify(rule, jsonOpts, writer),
                .cCode => |item| try std.json.stringify(item, jsonOpts, writer),
                .definition => |item| try std.json.stringify(item, jsonOpts, writer),
                .startCondition => |s| try std.json.stringify(s, jsonOpts, writer),
                .param => |p| try std.json.stringify(p, jsonOpts, writer),
                .userSuboutines => |routine| try std.json.stringify(routine, jsonOpts, writer),
                .EndOfSection => _ = try writer.write("End of section\n"),
                .EOF => _ = try writer.write("EOF\n"),
                .comment => _ = try writer.write("COMMENT\n"),
            }
        }
    };

    alloc: std.mem.Allocator,
    file: std.fs.File,
    fileName: ?[]u8 = null,
    input: []u8,
    nextFn: *const fn (*LexTokenizer) LexTokenizerError!LexToken,
    eofReached: bool = false,
    inputInitialized: bool = false,
    pos: struct {
        line: usize = 1,
        col: usize = 0,
        absolute: usize = 0,
    } = .{},

    const BUFSIZE = 2048;

    fn readWholeFile(self: *LexTokenizer) ![]u8 {
        self.eofReached = true;
        self.inputInitialized = true;
        return self.file.readToEndAlloc(self.alloc, 10e9);
    }

    fn readLine(self: *LexTokenizer) ![]u8 {
        var buffer: [BUFSIZE]u8 = .{0} ** BUFSIZE;
        var it: usize = 0;
        while (true): (it += 1) {
            buffer[it] = self.file.reader().readByte() catch |e| switch (e) {
                error.EndOfStream => { self.eofReached = true; return e; },
                else => return e,
            };
            if (buffer[it] == '\n' or buffer[it] == 0x00) 
            return self.alloc.dupe(u8, buffer[0..it + 1]);
        }
        unreachable;
    }

    pub fn readMore(self: *LexTokenizer) !void {
        if (self.eofReached) return;

        if (self.file.isTty()) {
            if (!self.inputInitialized) {
                self.input = try self.readLine();
                self.inputInitialized = true;
                return;
            }
            const rhs = try self.readLine();
            const old_len = self.input.len;
            self.input = try self.alloc.realloc(self.input, self.input.len + rhs.len);
            @memcpy(self.input[old_len..], rhs[0..]);
            self.alloc.free(rhs);
        } else {
            self.input = try readWholeFile(self);
        }
    }

    pub fn init(alloc: std.mem.Allocator, fileName: ?[]u8, file: std.fs.File) LexTokenizer {
        return .{
            .file = file,
            .alloc = alloc,
            .input = undefined,
            .fileName = fileName,
            .nextFn = &nextDefinitions,
        };
    }

    pub fn changeContext(self: *LexTokenizer, ctx: LexTokenizerCtx) void {
        self.nextFn = switch (ctx) {
            .Rules => &nextRules,
            .Definitions => &nextDefinitions,
            .UserSubroutines => &nextUserSubroutines,
        };
    }

    pub fn getFileName(self: LexTokenizer) []const u8 {
        return if (self.fileName) |name| std.fs.path.basename(name) else "stdin";
    }

    fn getLineNo(self: LexTokenizer) usize { return self.pos.line; }
    fn getColNo(self: LexTokenizer) usize { return self.pos.col; }

    pub fn next(self: *LexTokenizer) LexTokenizerError!LexToken {
        return self.nextFn(self);
    }

    fn ensureSteamIsReady(self: *LexTokenizer) void {
        if (!self.inputInitialized or self.pos.absolute >= self.input.len) {
            self.readMore() catch {};
        }
    }

    fn getC(self: *LexTokenizer) ?u8 {
        self.ensureSteamIsReady();

        const c: u8 =
            if (self.pos.absolute < self.input.len) self.input[self.pos.absolute] 
            else return null;

        self.pos.absolute += 1;
        switch (c) {
            '\n' => {
                self.pos.line += 1;
                self.pos.col = 0;
            },
            else => self.pos.col += 1,
        }
        return c;
    }

    fn getN(self: *LexTokenizer, n: usize) ?u8 {
        for (0..n - 1) |_| _ = self.getC();
        return self.getC();
    }

    fn peekC(self: *LexTokenizer) ?u8 {
        self.ensureSteamIsReady();
        return 
        if (self.pos.absolute < self.input.len) self.input[self.pos.absolute] 
            else null;
    }

    fn peekN(self: *LexTokenizer, n: usize) ?u8 {
        self.ensureSteamIsReady();
        return 
        if (self.pos.absolute + n - 1 < self.input.len) self.input[self.pos.absolute + n - 1]
            else null;
    }

    inline fn eatWhitespaces(self: *LexTokenizer) void {
        while (self.peekC()) |c| {
            if (!std.ascii.isWhitespace(c) or c == '\n') break;
            _ = self.getC();
        }
    }

    inline fn skipEmptyLine(self: *LexTokenizer) bool {
        var it: usize = 2;
        return blk: {
            while (self.peekN(it)) |c| {
                if (c == '\n') {
                    _ = self.getN(it - 1);
                    break :blk true;
                }
                if (!std.ascii.isWhitespace(c)) {
                    break :blk false;
                }
                it += 1;
            } else break: blk false;
        };
    }

    inline fn eatComment(self: *LexTokenizer) !LexToken {
        const nextChar = self.peekN(2);
        if (nextChar == null or nextChar != '*') return error.BadCharacter;

        while (true) {
            const currC, const nextC = .{self.peekN(1), self.peekN(2)};
            if (currC != null and nextC != null and 
                currC == '*' and nextC == '/') 
            {
                _ = self.getN(2);
                break;
            }
            _ = self.getC();
        }
        self.eatWhitespacesAndNewline();
        return LexToken{.comment ={}};
    }

    pub inline fn eatWhitespacesAndNewline(self: *LexTokenizer) void {
        while (true) {
            const currC = self.peekC();
            if (currC == null)
                break;

            if (currC == '\n') {
                if (self.skipEmptyLine()) {
                    continue;
                } else {
                    _ = self.getC(); break;
                }
            }
            if (!std.ascii.isWhitespace(currC.?)) break;
            _ = self.getC();
        }
    }

    fn getDefName(self: *LexTokenizer) ![]u8 {
        const sName: usize = self.pos.absolute;
        if (self.peekC()) |c| {
            if (!(std.ascii.isAlphabetic(c) or c == '_')) {
                return error.BadCharacter;
            }
        } else return error.UnexpectedEOF;
        _ = self.getC();

        while (self.peekC()) |c| {
            if (!(std.ascii.isAlphanumeric(c) or c == '_')) {
                if (!std.ascii.isWhitespace(c)) {
                    return error.BadCharacter;
                } else break;
            }
            _ = self.getC();
        }
        return self.input[sName..self.pos.absolute];
    }

    fn getDefSubstitute(self: *LexTokenizer) ![]u8 {
        if (self.peekC()) |c| {
            if (c == '\n') return error.IncompleteNameDefinition;
        } else return error.UnexpectedEOF;

        const sSub: usize = self.pos.absolute;
        while (self.peekC()) |c| {
            defer _ = self.getC();
            if (c == '\n') break;
        }
        return self.input[sSub..self.pos.absolute];
    }

    fn getDefinition(self: *LexTokenizer) !LexToken {
        const name = try self.getDefName();
        self.eatWhitespaces();
        const substitute = try self.getDefSubstitute();
        self.eatWhitespacesAndNewline();

        var groupedSubstitute = mem.trim(u8, substitute, &std.ascii.whitespace);
        groupedSubstitute = try mem.join(self.alloc, "", &[_][]const u8{ "(", groupedSubstitute, ")" });


        return LexToken {
            .definition = .{
                .name = name,
                .substitute = @constCast(groupedSubstitute),
            },
        };
    }

    fn getCLine(self: *LexTokenizer) LexTokenizerError!LexToken {
        const sLine: usize = self.pos.absolute;
        const sLineNo: usize = self.pos.line;
        while (self.peekC()) |c| {
            if (c == '\n') break;

            if (mem.startsWith(u8, self.input[self.pos.absolute..], "yymore"))
                G.options.needYYMore = true;
            if (mem.startsWith(u8, self.input[self.pos.absolute..], "REJECT"))
                G.options.needYYMore = true;

            _ = self.getC();
        }
        const eLine: usize = self.pos.absolute;
        self.eatWhitespacesAndNewline();

        return LexToken {
            .cCode  = .{
                .code = @constCast(mem.trim(u8, self.input[sLine..eLine], &std.ascii.whitespace)),
                .lineNo = sLineNo,
            },
        };
    }

    fn logError(self: *LexTokenizer, err: LexTokenizerError) LexTokenizerError {
        switch (err) {
            error.UnrecognizedPercentDirective => std.log.err("{s}:{d}: unrecognized '%' directive", .{self.getFileName(), self.getLineNo()}),
            error.BadCharacter => std.log.err("{s}:{d}: bad character: {c}", .{self.getFileName(), self.getLineNo(), self.peekC() orelse '.'}),
            error.UnexpectedEOF => std.log.err("{s}:{d}: premature EOF", .{self.getFileName(), self.getLineNo()}),
            error.IncompleteNameDefinition => std.log.err("{s}:{d}: incomplete name definition", .{self.getFileName(), self.getLineNo()}),
            error.BadNumber => std.log.err("{s}:{d}: bad number format", .{self.getFileName(), self.getLineNo()}),
            error.OutOfMemory => std.log.err("fatal: out of memory", .{}),
        }
        return err;
    }


    inline fn allNotNull(maybeChars: []const ?u8, buffer: []u8) ?[]u8 { 
        return for (maybeChars, 0..) |maybeC, i| {
            buffer[i] = if (maybeC) |c| c else break null;
        } else buffer;
    }

    inline fn isEndOfCBlock(self: *LexTokenizer) !bool {
        for ("\n%}", 1..) |cmp, i| {
            if (self.peekN(i)) |c| 
                if (c == cmp) 
                    continue 
                else return false 
            else return error.UnexpectedEOF;
        }
        return true;
    }

    inline fn eatTillNewLine(self: *LexTokenizer) bool {
        while (self.getC()) |c| {
            if (c == '\n') break;
        }
        return true;
    }

    fn getCBlockDef(self: *LexTokenizer) LexTokenizerError!LexToken {
        _ = self.getN(2);
        const sLine: usize = self.pos.line;
        _ = self.eatTillNewLine();
        const sBlock: usize = self.pos.absolute;
        while (!try self.isEndOfCBlock()) {
            _ = self.getC();
        }
        const eBlock: usize = self.pos.absolute;
        std.debug.assert(std.mem.eql(u8, self.input[self.pos.absolute..self.pos.absolute + 3], "\n%}"));

        _ = self.getN(3);
        _ = self.eatTillNewLine();
        self.eatWhitespacesAndNewline();
        return LexToken{
            .cCode = .{
                .code = self.input[sBlock..eBlock],
                .lineNo = sLine,
            },
        };
    }

    fn getStartCondition(self: *LexTokenizer) LexTokenizerError!LexToken {
        _ = self.getC();
        const cType = self.getC().?;

        var ret = LexToken {
            .startCondition = .{
                .type = if (cType == 's' or cType == 'S') .Inclusive else .Exclusive,
                .name = std.ArrayList([]u8).init(self.alloc),
            }
        };
        errdefer ret.startCondition.name.deinit();

        while (self.peekC() != '\n') {
            self.eatWhitespaces();
            try ret.startCondition.name.append(try self.getDefName());
        }
        self.eatWhitespacesAndNewline();

        return ret;
    }

    fn getNumber(self: *LexTokenizer) !usize {
        if (self.peekC()) |c| 
            if (c == '\n')
                return error.BadNumber;

        const s = self.pos.absolute;
        while (self.peekC()) |c| {
            if (std.ascii.isWhitespace(c)) break;
            _ = self.getC();
        }
        return std.fmt.parseInt(usize, self.input[s..self.pos.absolute], 10) catch return error.BadNumber;
    }

    fn matchAndEatSlice(self: *LexTokenizer, slice: []const u8) bool {
        for (slice, 1..) |c, i| {
            if (self.peekN(i)) |lexem| if (lexem == c) continue;
            return false;
        }
        _ = self.getN(slice.len);
        _ = self.eatTillNewLine();
        self.eatWhitespacesAndNewline();
        return true;
    }

    fn getParam(self: *LexTokenizer) LexTokenizerError!void {
        _ = self.getC();
        const id = self.getC().?;
        switch (id) {
            'a' => if (self.matchAndEatSlice("rray")) { G.options.yyTextType = .Array; },
            'p' => if (self.matchAndEatSlice("ointer")) { G.options.yyTextType = .Pointer; },
            else => {},
        }

        self.eatWhitespaces();
        const number = try self.getNumber();

        _ = self.eatTillNewLine();
        self.eatWhitespacesAndNewline();

        switch (id) {
            'p' => G.options.maxPositions = number,
            'n' => G.options.maxStates = number,
            'a' => G.options.maxTransitions = number,
            'e' => G.options.maxParseTreeNodes = number,
            'k' => G.options.maxPackedCharClass = number,
            'o' => G.options.maxSizeDFA = number,
            else => unreachable,
        }
    }

    pub fn nextDefinitions(self: *LexTokenizer) LexTokenizerError!LexToken {
        //Skip potential blanks on first call
        if (self.pos.absolute == 0) self.eatWhitespacesAndNewline();

        return if (self.peekC()) |c| switch (c) {
            ' ', 0x09 ... 0x0D => self.getCLine() catch |e| self.logError(e),
            '/' => self.eatComment() catch |e| self.logError(e),
            '%' => if (self.peekN(2)) |cPeek| switch (cPeek) {
                    '%' => { _ = self.getN(2); return .EndOfSection; },
                    '{' => self.getCBlockDef() catch |e| return self.logError(e),
                    's', 'S', 'x', 'X', => self.getStartCondition() catch |e| self.logError(e),
                    'p', 'n', 'a', 'e', 'k', 'o' => { self.getParam() catch |e| return self.logError(e); return self.nextDefinitions(); },
                    else => self.logError(error.UnrecognizedPercentDirective),
                } else self.logError(error.UnexpectedEOF),
            else => self.getDefinition() catch |e| self.logError(e),
        } else self.logError(error.UnexpectedEOF);
    }

    fn getCBlockRule(self: *LexTokenizer) LexTokenizerError!LexToken {
        const sBlock: usize = self.pos.absolute;
        const sLine: usize = self.pos.line;
        _ = self.getC();

        var depth: usize = 1;
        var sQuote: bool, var dQuote = .{ false, false };
        var multiLineComment, var oneLineComment = .{ false, false };
        while (depth != 0) {
            const nextCs = [_]u8 {
                self.peekN(1) orelse return error.UnexpectedEOF,
                self.peekN(2) orelse return error.UnexpectedEOF
            };

            if (!dQuote and !sQuote and mem.eql(u8, &nextCs, "//")) oneLineComment = true;
            if (!dQuote and !sQuote and mem.eql(u8, &nextCs, "/*")) multiLineComment = true;

            if (oneLineComment and nextCs[0] != '\\' and nextCs[1] == '\n') 
            { _ = self.getN(2); oneLineComment = false; continue; }

            if (multiLineComment and mem.eql(u8, &nextCs, "*/")) 
            { _ = self.getN(2); multiLineComment = false; continue; }

            if (oneLineComment or multiLineComment) 
            { _ = self.getC(); continue; }

            //NOTE: Not the best way to match yymore/REJECT, tho if the user declares a 
            //variable x_yymore, we consider that it's his fault.
            if (mem.startsWith(u8, self.input[self.pos.absolute..], "yymore")) {
                G.options.needYYMore = true;
            } else if (mem.startsWith(u8, self.input[self.pos.absolute..], "REJECT")) {
                G.options.needREJECT = true;
            }

            switch (nextCs[0]) {
                '\\' => _ = self.getC(),
                '\'' => sQuote = if (!dQuote) !sQuote else sQuote,
                '"' => dQuote = if (!sQuote) !dQuote else dQuote,
                '{' => depth += if (!dQuote and !sQuote) 1 else 0,
                '}' => depth -|= if (!dQuote and !sQuote) 1 else 0,
                else => {},
            }
            _ = self.getC();
        }
        _ = self.peekC() orelse return error.UnexpectedEOF;

        const eBlock: usize = self.pos.absolute;
        _ = self.eatTillNewLine();
        self.eatWhitespacesAndNewline();

        return LexToken {
            .cCode = .{
                .code = self.input[sBlock + 1..eBlock - 1],
                .lineNo = sLine,
            },
        };
    }

    fn getRule(self: *LexTokenizer) !LexToken {
        var quote = false;
        var brace: usize = 0;
        const sRegex: usize = self.pos.absolute;
        while (true) {
            const curr = self.peekC() orelse break;
            // std.debug.print("Curr: {c}, quote: {}, brace: {d}\n", .{curr, quote, brace});
            switch (curr) {
                '"' => quote = if (brace == 0) !quote else quote,
                '[' => brace += if (!quote) 1 else 0,
                ']' => brace -|= if (!quote) 1 else 0,
                '\\' => { 
                    _ = self.getC() orelse return error.BadCharacter; 
                    const nextC = self.getC() orelse return error.BadCharacter; 
                    if (nextC == '\n') { return error.BadCharacter; }
                    else continue;
                },
                ' ', '\t' => if (!quote and brace == 0) break,
                else => {},
            }
            if (
                !quote and brace == 0 and 
                mem.indexOfScalar(u8, &std.ascii.whitespace, curr) != null
            ) { break; }
            _ = self.getC();
        }
        const regex = self.input[sRegex..self.pos.absolute];
        self.eatWhitespaces();
        // std.debug.print("got regex: {s}: lineno: {d}\n", .{regex, self.getLineNo()});

        const code = if (self.peekC()) |c| switch (c) {
            '{' => try self.getCBlockRule(),
            else => try self.getCLine(),
        } else try self.getCLine();

        self.eatWhitespacesAndNewline();

        return LexToken {
            .rule = .{
                .regex = regex,
                .code = code.cCode,
            }
        };
    }
    
    pub fn nextRules(self: *LexTokenizer) LexTokenizerError!LexToken {
        return if (self.peekC()) |c| switch (c) {
            ' ', 0x09 ... 0x0D => {self.eatWhitespaces(); return LexToken{.comment = {}}; },
            '/' => self.eatComment() catch |e| self.logError(e),
            '%' => if (self.peekN(2)) |cPeek| switch (cPeek) {
                '%' => { _ = self.getN(2); return .EndOfSection; },
                else => self.logError(error.BadCharacter),
            } else self.logError(error.UnexpectedEOF),
            else => self.getRule() catch |e| self.logError(e),
        } else return LexToken{.EOF = {}};
    }

    pub fn nextUserSubroutines(self: *LexTokenizer) LexTokenizerError!LexToken {
        while (!self.eofReached) {
            self.readMore() catch |e| {
                switch (e) {
                    error.EndOfStream => {},
                    else => return error.UnexpectedEOF,
                }
            };
        }

        if (self.pos.absolute == self.input.len) return LexToken{.EOF = {}};
        return LexToken {
            .userSuboutines = self.input[self.pos.absolute..],
        };
    }
};
