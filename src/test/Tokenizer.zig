const std               = @import("std");

const TokenizerModule   = @import("../regex/Tokenizer.zig");
const Tokenizer         = TokenizerModule.Tokenizer;
const Token             = TokenizerModule.Token;

fn tokenizeAll(alloc: std.mem.Allocator, input: []const u8) ![]Token {
    var tokenizer = Tokenizer.init(input, .RegexExpCommon);
    var token_list = std.ArrayList(Token).init(alloc);
    defer token_list.deinit();

    while (true) {
        const token = tokenizer.next();
        if (token == .Eof) 
            break;
        try token_list.append(token);
    }

    return token_list.toOwnedSlice();
} 

fn tokenizerTestTemplate(alloc: std.mem.Allocator, input: []const u8, expected: []Token) !void {
    const tokens = tokenizeAll(alloc, input) catch {
        @panic("Memory error");
    };
    defer alloc.free(tokens);
    try std.testing.expectEqualSlices(Token, tokens, expected);
}

test "Simple character tokenization" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .{ .Char = 'b' },
        .AnchorEnd,
    };
    try tokenizerTestTemplate(alloc, "ab$", expected[0..]);
}

test "Tokenizing special symbols" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .{ .Char = 'b' },
        .Union,
        .{ .Char = 'c' },
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "ab|c$", expected[0..]);
}

test "Multiple union alternations" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .Union,
        .{ .Char = 'b' },
        .Union,
        .{ .Char = 'c' },
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "a|b|c$", expected[0..]);
}

test "Star operator usage" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .Star,
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "a*$", expected[0..]);
}

test "Plus operator usage" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .Plus,
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "a+$", expected[0..]);
}

test "Question operator usage" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .Question,
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "a?$", expected[0..]);
}

test "Concatenation with no spaces" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .{ .Char = 'b' },
        .{ .Char = 'c' },
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "abc$", expected[0..]);
}

test "Escaped characters" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .Escape,
        .{ .Char = 'a' },
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "\\a$", expected[0..]);
}

test "Parentheses group" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .LParen,
        .{ .Char = 'a' },
        .RParen,
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "(a)$", expected[0..]);
}

test "Nested parentheses group" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .LParen,
        .LParen,
        .{ .Char = 'a' },
        .RParen,
        .RParen,
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "((a))$", expected[0..]);
}

test "Trailing context with lookahead" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .TrailingContext,
        .{ .Char = 'b' },
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "a/b$", expected[0..]);
}

test "Multiple trailing contexts" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .TrailingContext,
        .{ .Char = 'b' },
        .TrailingContext,
        .{ .Char = 'c' },
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "a/b/c$", expected[0..]);
}

test "Anchor at start and end" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .AnchorStart,
        .{ .Char = 'a' },
        .{ .Char = 'b' },
        .AnchorEnd,
    };

    try tokenizerTestTemplate(alloc, "^ab$", expected[0..]);
}
