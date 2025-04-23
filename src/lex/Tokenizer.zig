const std = @import("std");
const print = std.debug.print;

pub const Definitions = struct {
    pub const YYTextType = enum {
        Array,
        Pointer,
    };

    pub const CCode = struct {
        lineNo: usize,
        code: []u8,
    };

    pub const Definition = struct {
        name: []u8,
        substitute: []u8,
    };

    yytextType: YYTextType = .Array,
    cCodeFragments: std.ArrayList(CCode),

    pub const StartConditions = struct {
        inclusive: std.ArrayList([]u8),
        exclusive: std.ArrayList([]u8),
    };

    pub const Params = struct {
        nPositions: usize = 2500,               //%p n
        nStates: usize = 500,                   //%n n
        nTransitions: usize = 2000,             //%a n
        nParseTreeNodes: usize = 1000,          //%e n
        nPackedCharacterClass: usize = 1000,    //%k n
        nOutputArray: usize = 3000,             //%o n
    };
};


pub const LexTokenizer = struct {

    pub const LexTokenizerError = error {
        UnrecognizedPercentDirective,
        UnexpectedEOF,
        BadCharacter,
    };

    pub const LexTokenizerCtx = enum {
        Definitions,
        Rules,
        UserSubroutines,
    };

    pub const LexToken = union(enum) {
        cCode: Definitions.CCode,
        definition: Definitions.Definition,
        EndOfSection: void,
        EOF: void,

        pub fn format(self: *const LexToken, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            return try std.json.stringify(self, .{ .whitespace = .indent_2 }, writer);
        }
    };

    pos: struct {
        line: usize = 0,
        col: usize = 0,
        absolute: usize = 0,
    } = .{},

    input: []u8,
    nextFn: *const fn (*LexTokenizer) LexTokenizerError!LexToken,
    fileName: ?[]u8 = null,

    pub fn init(input: []u8, ctx: LexTokenizerCtx, fileName: ?[]u8) LexTokenizer {
        return .{
            .input = input,
            .fileName = fileName,
            .nextFn = switch (ctx) {
                .Definitions => &nextDefinitions,
                .Rules => &nextRules,
                .UserSubroutines => &nextUserSubroutines,
            },
        };
    }

    pub fn next(self: *LexTokenizer) LexTokenizerError!LexToken {
        return self.nextFn(self);
    }

    pub fn getC(self: *LexTokenizer) ?u8 {
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

    pub fn peekC(self: *LexTokenizer) ?u8 {
        return 
        if (self.pos.absolute < self.input.len) self.input[self.pos.absolute] 
        else null;
    }

    pub fn getCCode(self: *LexTokenizer) LexToken {
        while (self.getC()) |c| switch (c) {
            ' ', 0x09 ... 0x0D => continue,
            else => break,
        };
        return LexToken {
            .definition = .{
                .name = self.input[self.pos.absolute..self.pos.absolute],
                .substitute = self.input[self.pos.absolute..self.pos.absolute],
            },
        };
    }

    pub fn getDefinition(self: *LexTokenizer) LexToken {
        const s: usize = self.pos.absolute;
        while (self.getC()) |char| {
            if (std.ascii.isAlphanumeric(char)) {
                
            }
        }
        return LexToken {
            .definition = .{
                .name = self.input[self.pos.absolute..self.pos.absolute],
                .substitute = self.input[self.pos.absolute..self.pos.absolute],
            },
        };
    }

    pub fn getFileName(self: LexTokenizer) []const u8 {
        return if (self.fileName) |name| std.fs.path.basename(name) else @as([]const u8, &[_]u8{'s', 't', 'd', 'i', 'n'});
    }

    pub fn logError(self: LexTokenizer, err: LexTokenizerError) LexTokenizerError {
        switch (err) {
            error.UnrecognizedPercentDirective => std.log.err("{s}:{d}: unrecognized '%' directive", .{self.getFileName(), self.pos.line}),
            error.UnexpectedEOF => std.log.err("{s}:{d}: premature EOF", .{self.getFileName(), self.pos.line}),
            else => {}
        }
        return err;
    }

    pub fn nextDefinitions(self: *LexTokenizer) LexTokenizerError!LexToken {
        return if (self.getC()) |c| switch (c) {
            ' ', 0x09 ... 0x0D => self.getCCode(),
            '%' => if (self.peekC()) |cPeek| switch (cPeek) {
                    '%' => {
                        _ = self.getC();
                        return .EndOfSection;
                    },
                    // '}' => self.getCSection(),
                    // 's', 'S', 'x', 'X', => self.getStartCondition(c),
                    // 'p', 'n', 'a', 'e', 'k', 'o' => self.getParam(c),
                    else => self.logError(error.UnrecognizedPercentDirective),
                } else self.logError(error.UnexpectedEOF),
            else => self.getDefinition(),
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
