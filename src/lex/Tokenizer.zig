const std = @import("std");
const print = std.debug.print;

pub const CCode = struct {
    lineNo: usize,
    code: []u8,
};

pub const Definition = struct {
    name: []u8,
    substitute: []u8,
};

pub const Definitions = struct {

    pub const StartConditions = struct {
        inclusive: std.ArrayListUnmanaged([]u8),
        exclusive: std.ArrayListUnmanaged([]u8),

        pub fn init(alloc: std.mem.Allocator) !StartConditions {
            return .{
                .inclusive = try std.ArrayListUnmanaged([]u8).initCapacity(alloc, 5),
                .exclusive = try std.ArrayListUnmanaged([]u8).initCapacity(alloc, 5),
            };
        }

        pub fn deinit(self: *StartConditions, alloc: std.mem.Allocator) void {
            self.exclusive.deinit(alloc);
            self.inclusive.deinit(alloc);
        }
    };

    pub const YYTextType = enum { Array, Pointer, };

    pub const Params = struct {
        nPositions: usize = 2500,               //%p n
        nStates: usize = 500,                   //%n n
        nTransitions: usize = 2000,             //%a n
        nParseTreeNodes: usize = 1000,          //%e n
        nPackedCharacterClass: usize = 1000,    //%k n
        nOutputArray: usize = 3000,             //%o n
    };

    yytextType: YYTextType = .Array,
    cCodeFragments: std.ArrayListUnmanaged(CCode),
    definitions: std.ArrayListUnmanaged(Definition),
    params: Params = .{},
    startConditions: StartConditions,

    pub fn init(alloc: std.mem.Allocator) !Definitions {
        return .{
            .cCodeFragments = try std.ArrayListUnmanaged(CCode).initCapacity(alloc, 5),
            .definitions = try std.ArrayListUnmanaged(Definition).initCapacity(alloc, 5),
            .startConditions = try StartConditions.init(alloc),
        };
    }

    pub fn deinit(self: *Definitions, alloc: std.mem.Allocator) void {
        self.cCodeFragments.deinit(alloc);
        for (self.definitions.items) |item| alloc.free(item.substitute);
        self.definitions.deinit(alloc);
        self.startConditions.deinit(alloc);
    }

};


pub const LexTokenizer = struct {

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
        cCode: CCode,
        definition: Definition,
        EndOfSection: void,
        EOF: void,
        param: ParamType,
        startCondition: struct {
            type: enum { Inclusive, Exclusive },
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
            switch (self.*) {
                .cCode => |item| try std.json.stringify(item, .{ .whitespace = .indent_2 }, writer),
                .definition => |item| try std.json.stringify(item, .{ .whitespace = .indent_2 }, writer),
                .startCondition => |s| try std.json.stringify(s, .{ .whitespace = .indent_2 }, writer),
                .param => |p| try std.json.stringify(p, .{ .whitespace = .indent_2 }, writer),
                .EndOfSection => _ = try writer.write("End of section\n"),
                .EOF => _ = try writer.write("EOF\n"),
            }
        }
    };

    alloc: std.mem.Allocator,
    nextFn: *const fn (*LexTokenizer) LexTokenizerError!LexToken,
    fileName: ?[]u8 = null,
    input: []u8,
    pos: struct {
        line: usize = 0,
        col: usize = 0,
        absolute: usize = 0,
    } = .{},

    pub fn init(alloc: std.mem.Allocator, input: []u8, ctx: LexTokenizerCtx, fileName: ?[]u8) LexTokenizer {
        return .{
            .alloc = alloc,
            .input = input,
            .fileName = fileName,
            .nextFn = switch (ctx) {
                .Definitions => &nextDefinitions,
                .Rules => &nextRules,
                .UserSubroutines => &nextUserSubroutines,
            },
        };
    }

    fn getFileName(self: LexTokenizer) []const u8 {
        return if (self.fileName) |name| std.fs.path.basename(name) else "stdin";
    }

    fn getLineNo(self: LexTokenizer) usize { return self.pos.line; }
    fn getColNo(self: LexTokenizer) usize { return self.pos.col; }

    pub fn next(self: *LexTokenizer) LexTokenizerError!LexToken {
        return self.nextFn(self);
    }

    fn getC(self: *LexTokenizer) ?u8 {
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
        return 
        if (self.pos.absolute < self.input.len) self.input[self.pos.absolute] 
            else null;
    }

    fn peekN(self: LexTokenizer, n: usize) ?u8 {
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
                    self.pos.absolute += it - 1;
                    break :blk true;
                }
                if (!std.ascii.isWhitespace(c)) {
                    break :blk false;
                }
                it += 1;
            } else break: blk false;
        };
    }

    inline fn eatWhitespacesAndNewline(self: *LexTokenizer) void {
        while (self.peekC()) |c| {
            if (c == '\n') {
                if (self.skipEmptyLine()) {
                    continue;
                } else {
                    _ = self.getC(); break;
                }
            }
            if (!std.ascii.isWhitespace(c)) break;
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

        return LexToken {
            .definition = .{
                .name = name,
                .substitute = @constCast(std.mem.trim(u8, substitute, &std.ascii.whitespace)),
            },
        };
    }

    fn getCLine(self: *LexTokenizer) LexTokenizerError!LexToken {
        const sLine: usize = self.pos.absolute;
        while (self.peekC()) |c| {
            if (c == '\n') break;
            _ = self.getC();
        }
        const eLine: usize = self.pos.absolute;
        self.eatWhitespacesAndNewline();

        return LexToken {
            .cCode  = .{
                .code = self.input[sLine..eLine],
                .lineNo = self.pos.line,
            },
        };
    }

    fn logError(self: LexTokenizer, err: LexTokenizerError) LexTokenizerError {
        switch (err) {
            error.UnrecognizedPercentDirective => std.log.err("{s}:{d}: unrecognized '%' directive", .{self.getFileName(), self.getLineNo()}),
            error.BadCharacter => std.log.err("{s}:{d}: bad character: {c}", .{self.getFileName(), self.getLineNo(), self.input[self.pos.absolute]}),
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
        const maybeNextChars = [3]?u8{ self.peekN(1), self.peekN(2), self.peekN(3) };
        var buffer: [3]u8 = undefined;
        if (allNotNull(maybeNextChars[0..], &buffer)) |nextChars| {
            return std.mem.eql(u8, nextChars, "\n%}");
        } else return error.UnexpectedEOF;

        // //NOTE: YOLO
        // for ("\n%}", 1..) |cmp, i| if (self.peekN(i)) |c| if (c == cmp) continue else return false else return error.UnexpectedEOF;
        // return true;
    }

    inline fn eatTillNewLine(self: *LexTokenizer) void {
        while (self.getC()) |c| {
            if (c == '\n') break;
        }
    }

    fn getCBlock(self: *LexTokenizer) LexTokenizerError!LexToken {
        _ = self.getN(2);
        const sLine: usize = self.pos.line;
        self.eatTillNewLine();
        const sBlock: usize = self.pos.absolute;
        while (!try self.isEndOfCBlock()) {
            _ = self.getC();
        }
        const eBlock: usize = self.pos.absolute;

        std.debug.assert(std.mem.eql(u8, self.input[self.pos.absolute..self.pos.absolute + 3], "\n%}"));
        _ = self.getN(3);
        self.eatTillNewLine();
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
        self.eatTillNewLine();
        self.eatWhitespacesAndNewline();
        return true;
    }

    fn getParam(self: *LexTokenizer) LexTokenizerError!LexToken {
        _ = self.getC();
        const id = self.getC().?;
        switch (id) {
            'a' => if (self.matchAndEatSlice("rray")) 
                return LexToken{ .param = .{ .YYTextType = .Array } },
            'p' => if (self.matchAndEatSlice("ointer")) 
                return LexToken{ .param = .{ .YYTextType = .Pointer } },
            else => {},
        }

        self.eatWhitespaces();
        const number = try self.getNumber();
        self.eatTillNewLine();
        self.eatWhitespacesAndNewline();

        return switch (id) {
            'p' => .{ .param = .{ .nPositions = number }},
            'n' => .{ .param = .{ .nStates = number }},
            'a' => .{ .param = .{ .nTransitions = number }},
            'e' => .{ .param = .{ .nParseTreeNodes = number }},
            'k' => .{ .param = .{ .nPackedCharacterClass = number }},
            'o' => .{ .param = .{ .nOutputArray = number }},
            else => unreachable,
        };
    }

    pub fn nextDefinitions(self: *LexTokenizer) LexTokenizerError!LexToken {
        return if (self.peekC()) |c| switch (c) {
            ' ', 0x09 ... 0x0D => self.getCLine() catch |e| return self.logError(e),
            '%' => if (self.peekN(2)) |cPeek| switch (cPeek) {
                    '%' => { _ = self.getC(); return .EndOfSection; },
                    '{' => self.getCBlock() catch |e| return self.logError(e),
                    's', 'S', 'x', 'X', => self.getStartCondition() catch |e| return self.logError(e),
                    'p', 'n', 'a', 'e', 'k', 'o' => self.getParam() catch |e| return self.logError(e),
                    else => self.logError(error.UnrecognizedPercentDirective),
                } else self.logError(error.UnexpectedEOF),
            else => self.getDefinition() catch |e| return self.logError(e),
        } else self.logError(error.UnexpectedEOF);
    }
    

    pub fn nextRules(self: *LexTokenizer) LexTokenizerError!LexToken {
        return LexToken{
            .definition = .{ .name = self.input[0..4], .substitute = self.input[0..4] },
        };
    }

    pub fn nextUserSubroutines(self: *LexTokenizer) LexTokenizerError!LexToken {
        return LexToken{
            .definition = .{ .name = self.input[0..4], .substitute = self.input[0..4] },
        };
    }
};
