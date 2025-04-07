const std = @import("std");
const stdin = std.io.getStdIn();
const print = std.debug.print;
const log = std.log;
const Allocator = std.mem.Allocator;
const VectU = std.ArrayListUnmanaged;
const Vect = std.ArrayList;

const TokenizerModule = @import("Tokenizer.zig");
const ParserModule = @import("Parser.zig");

const Tokenizer = TokenizerModule.Tokenizer;
const Token = TokenizerModule.Token;
const Parser = ParserModule.Parser;
const RegexNode = ParserModule.RegexNode;

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
        const head = try parser.parse();
        print("{}\n", .{head});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
