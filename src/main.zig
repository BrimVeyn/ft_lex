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


comptime {
    _ = @import("test/Tokenizer.zig");
}

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

test "dummy" {
    try std.testing.expect(1 == 1);
}
