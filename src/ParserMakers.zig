const ParserModule = @import("Parser.zig");
const RegexNode = ParserModule.RegexNode;
const Parser = ParserModule.Parser;

pub fn makeConcat(_: Parser, left: *RegexNode, right: *RegexNode) RegexNode {
    return RegexNode{.Concat = .{ .left = left, .right = right }};
}
