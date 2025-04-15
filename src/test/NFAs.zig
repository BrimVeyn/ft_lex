const std = @import("std");
const ParserModule = @import("../Parser.zig");
const Parser = ParserModule.Parser;
const ParserError = ParserModule.ParserError;
const RegexNode = ParserModule.RegexNode;
const Makers = @import("../ParserMakers.zig");
const INFINITY = ParserModule.INFINITY;
const NFAModule = @import("../NFA.zig");
const NFA = NFAModule.NFA;
const NFABuilder = NFAModule.NFABuilder;

fn parseAll(alloc: std.mem.Allocator, input: []const u8) !struct {Parser, *RegexNode} {
    var parser = try Parser.init(alloc, input);

    const head = parser.parse() catch |e| {
        std.log.err("Parser: {!}", .{e});
        return e;
    };
    return .{parser, head};
}

test "Simple NFA merge" {
    const alloc = std.testing.allocator;
    var parserA, const headA = try parseAll(alloc, "abc");
    defer parserA.deinit();

    var parserB, const headB = try parseAll(alloc, "def");
    defer parserB.deinit();

    var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &parserA);
    defer nfaBuilder.deinit();

    const nfaA = try nfaBuilder.astToNfa(headA);
    const nfaB = try nfaBuilder.astToNfa(headB);

    var nfaArray = std.ArrayList(NFA).init(alloc);
    defer nfaArray.deinit();

    try nfaArray.append(nfaA);
    try nfaArray.append(nfaB);

    const result = try nfaBuilder.merge(nfaArray.items);
    try result.printStates(alloc, .Dot);
}
