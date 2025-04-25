const std                   = @import("std");
const LexTokenizerModule    = @import("Tokenizer.zig");
const LexTokenizer          = LexTokenizerModule.LexTokenizer;
const LexToken              = LexTokenizerModule.LexTokenizer.LexToken;
const LexTokenizerError     = LexTokenizerModule.LexTokenizer.LexTokenizerError;
const Definitions           = LexTokenizerModule.Definitions;

const LexParser = @This();

definitions: Definitions,
tokenizer: LexTokenizer,
alloc: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator, fileName: []u8) !LexParser {
    var file = std.fs.cwd().openFile(fileName, .{}) catch |e| {
        std.log.err("ft_lex: Failed to open: {s}, reason: {!}", .{fileName, e});
        return e;
    };
    defer file.close();
    const rawContent = file.readToEndAlloc(alloc, 1e8) catch |e| {
        std.log.err("ft_lex: Failed to read: {s}, reason: {!}", .{fileName, e});
        return e;
    };

    return .{
        .tokenizer = LexTokenizer.init(alloc, rawContent, .Definitions, fileName),
        .alloc = alloc,
        .definitions = try Definitions.init(alloc),
    };
}

pub fn deinit(self: *LexParser) void {
    self.alloc.free(self.tokenizer.input);
    self.definitions.deinit(self.alloc);
}

pub fn advance(self: *LexParser) !LexToken {
    return self.tokenizer.next();
}

pub fn parse(self: *LexParser) !void {
    outer: while (true) {
        const token = try self.advance();
        std.debug.print("Token: {}\n", .{token});
        switch (token) {
            .cCode => |code| try self.definitions.cCodeFragments.append(self.alloc, code),
            .definition => |def| try self.definitions.definitions.append(self.alloc, def),
            .startCondition => |start| { 
                defer start.name.deinit();
                switch (start.type) {
                    .Inclusive => try self.definitions.startConditions.inclusive.appendSlice(self.alloc, start.name.items[0..]),
                    .Exclusive => try self.definitions.startConditions.exclusive.appendSlice(self.alloc, start.name.items[0..]),
                }
            },
            .EndOfSection => break: outer,
            .param => |p| switch (p) {
                .nPositions => |v| self.definitions.params.nPositions = v,
                .nStates => |v| self.definitions.params.nStates = v,
                .nTransitions => |v| self.definitions.params.nTransitions = v,
                .nParseTreeNodes => |v| self.definitions.params.nParseTreeNodes = v,
                .nPackedCharacterClass => |v| self.definitions.params.nPackedCharacterClass = v,
                .nOutputArray => |v| self.definitions.params.nOutputArray = v,
            },
            else => std.debug.print("Unimplemented parser\n", .{}),
        }
    }
    std.debug.print("End of definition section\n", .{});
}
