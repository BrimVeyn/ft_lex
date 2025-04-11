const std               = @import("std");
const TokenizerModule   = @import("Tokenizer.zig");
const ParserModule      = @import("Parser.zig");
const NFAModule         = @import("NFA.zig");
const stdin             = std.io.getStdIn();
const print             = std.debug.print;
const log               = std.log;
const Allocator         = std.mem.Allocator;
const VectU             = std.ArrayListUnmanaged;
const Vect              = std.ArrayList;

const Tokenizer         = TokenizerModule.Tokenizer;
const Token             = TokenizerModule.Token;

const Parser            = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;
const NFA               = NFAModule.NFA;


const BUF_SIZE: usize = 4096;

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var stdinReader = stdin.reader();
    var buf: [BUF_SIZE:0]u8 = .{0} ** BUF_SIZE;

    print("Enter any regex to see its representation: \n", .{});
    while (true) {
        @memset(buf[0..], 0);
        _ = stdinReader.readUntilDelimiterOrEof(&buf, '\n') catch |e| {
            log.err("BUF_SIZE: {d} exceeded: {!}", .{BUF_SIZE, e});
        };

        if (std.mem.indexOfSentinel(u8, 0, buf[0..]) == 0) {
            break;
        }

        const line = std.mem.trimRight(u8, buf[0..], "\n\x00");
        var parser = try Parser.init(alloc, line);
        defer parser.deinit();

        const head = parser.parse() catch |e| {
            std.log.err("Parser: {!}", .{e});
            continue;
        };
        head.dump(0);
        var nfaBuilder = try NFAModule.NFABuilder.init(alloc, head, &parser);
        defer nfaBuilder.deinit();

        const nfa = nfaBuilder.astToNfa(nfaBuilder.ast_head) catch |e| {
            std.log.err("NFA: {!}", .{e});
            continue;
        };
        try nfa.printStates(alloc, .Human);
        try nfa.printStates(alloc, .Dot);
    }
}


fn tokenizeAll(alloc: std.mem.Allocator, input: []const u8) ![]Token {
    var tokenizer = Tokenizer.init(input);
    var token_list = std.ArrayList(Token).init(alloc);
    defer token_list.deinit();

    while (true) {
        const token = tokenizer.next();
        if (token == .Eof) break;
        try token_list.append(token);
    }

    return token_list.toOwnedSlice();
} 

fn assertTokensEql(tokens: []Token, expected: []Token) void {
    for (tokens, 0..) |token, i| {
        const valid: bool  = (i < expected.len and token.eql(expected[i]));
        if (!valid) {
            std.debug.panic("Token inequal: {} <> {}", .{token, expected[i]});
        }
    }
    return ;
}

fn tokenizerTestTemplate(alloc: std.mem.Allocator, input: []const u8, expected: []Token) void {
    const tokens = tokenizeAll(alloc, input) catch {
        @panic("Memory error");
    };
    defer alloc.free(tokens);
    assertTokensEql(tokens, expected[0..]);
}

test "Simple character tokenization" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .{ .Char = 'b' },
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "ab$", expected[0..]);
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

    tokenizerTestTemplate(alloc, "ab|c$", expected[0..]);
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

    tokenizerTestTemplate(alloc, "a|b|c$", expected[0..]);
}

test "Star operator usage" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .Star,
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "a*$", expected[0..]);
}

test "Plus operator usage" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .Plus,
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "a+$", expected[0..]);
}

test "Question operator usage" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .Question,
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "a?$", expected[0..]);
}

test "Concatenation with no spaces" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .{ .Char = 'b' },
        .{ .Char = 'c' },
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "abc$", expected[0..]);
}

test "Escaped characters" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Escape = '\\' },
        .{ .Char = 'a' },
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "\\a$", expected[0..]);
}

test "Parentheses group" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .LParen,
        .{ .Char = 'a' },
        .RParen,
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "(a)$", expected[0..]);
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

    tokenizerTestTemplate(alloc, "((a))$", expected[0..]);
}

test "Trailing context with lookahead" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .{ .Char = 'a' },
        .TrailingContext,
        .{ .Char = 'b' },
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "a/b$", expected[0..]);
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

    tokenizerTestTemplate(alloc, "a/b/c$", expected[0..]);
}

test "Anchor at start and end" {
    const alloc = std.testing.allocator;
    var expected = [_]Token{
        .AnchorStart,
        .{ .Char = 'a' },
        .{ .Char = 'b' },
        .AnchorEnd,
    };

    tokenizerTestTemplate(alloc, "^ab$", expected[0..]);
}
