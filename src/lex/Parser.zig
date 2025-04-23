const std                   = @import("std");
const LexTokenizerModule    = @import("Tokenizer.zig");
const LexTokenizer          = LexTokenizerModule.LexTokenizer;
const LexToken              = LexTokenizerModule.LexTokenizer.LexToken;
const LexTokenizerError     = LexTokenizerModule.LexTokenizer.LexTokenizerError;

const LexParser = @This();

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
        .tokenizer = LexTokenizer.init(rawContent, .Definitions, fileName),
        .alloc = alloc,
    };
}

pub fn deinit(self: *LexParser) void {
    self.alloc.free(self.tokenizer.input);
}

pub fn advance(self: *LexParser) !LexToken {
    return self.tokenizer.next();
}

pub fn parse(self: *LexParser) !void {
    while (true) {
        const token = try self.advance();
        std.debug.print("Token: {}\n", .{token});
    }
}
