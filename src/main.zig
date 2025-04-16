const std               = @import("std");
const stdin             = std.io.getStdIn();
const print             = std.debug.print;
const log               = std.log;
const Allocator         = std.mem.Allocator;
const VectU             = std.ArrayListUnmanaged;
const Vect              = std.ArrayList;

const TokenizerModule   = @import("Tokenizer.zig");
const Tokenizer         = TokenizerModule.Tokenizer;
const Token             = TokenizerModule.Token;

const ParserModule      = @import("Parser.zig");
const Parser            = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;

const NFAModule         = @import("NFA.zig");
const NFA               = NFAModule.NFA;

const DFAModule         = @import("DFA.zig");
const DFA               = DFAModule.DFA;

const Graph             = @import("Graph.zig");


comptime {
    _ = @import("test/Tokenizer.zig");
    _ = @import("test/Parser.zig");
    _ = @import("test/NFAs.zig");
}

const BUF_SIZE: usize = 4096;

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{.stack_trace_frames = 15}) = .init;
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

        const regex = std.mem.trimRight(u8, buf[0..], "\n\x00");
        var parser = try Parser.init(alloc, regex);
        defer parser.deinit();

        const head = parser.parse() catch |e| {
            std.log.err("Parser: {!}", .{e});
            continue;
        };
        head.dump(0);
        var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &parser);
        defer nfaBuilder.deinit();

        const nfa = nfaBuilder.astToNfa(head) catch |e| {
            std.log.err("NFA: {!}", .{e});
            continue;
        };

        var dfa = DFA.init(alloc, nfa);
        defer dfa.deinit();

        try dfa.subset_construction();

        Graph.dotFormat(regex, nfa, dfa);
    }
}

test "dummy" {
    try std.testing.expect(1 == 1);
}
