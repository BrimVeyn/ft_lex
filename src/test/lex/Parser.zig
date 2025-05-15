const std               = @import("std");
const LexParser         = @import("../../lex/Parser.zig");
const EC                = @import("../../regex/EquivalenceClasses.zig");

const NFAModule         = @import("../../regex/NFA.zig");
const NFA               = NFAModule.NFA;

const DFAModule         = @import("../../regex/DFA.zig");
const DFA               = DFAModule.DFA;

const ParserModule      = @import("../../regex/Parser.zig");
const RegexParser       = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;

var     yy_ec: [256]u8  = .{0} ** 256;

fn assertCompressionIsValid(path: []const u8) !void {
    const alloc = std.testing.allocator;
    var lexParser = try LexParser.init(alloc, @constCast(path));
    defer lexParser.deinit();
    lexParser.parse() catch return;
    
    var regexParser = try RegexParser.init(alloc);
    defer regexParser.deinit();

    var headList = std.ArrayList(*RegexNode).init(alloc);
    defer headList.deinit();

    for (lexParser.rules.items) |rule| {
        regexParser.loadSlice(rule.regex);
        const head = regexParser.parse() catch |e| {
            std.log.err("\"{s}\": {!}", .{rule.regex, e});
            return;
        };
        try headList.append(head);
    }

    const yy_ec_highest = try EC.buildEquivalenceTable(alloc, regexParser.classSet, &yy_ec);
    var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &regexParser, &yy_ec);
    defer nfaBuilder.deinit();

    var nfaList = std.ArrayList(NFA).init(alloc);
    defer nfaList.deinit();

    for (headList.items) |head| {
        const nfa = nfaBuilder.astToNfa(head) catch |e| {
            std.log.err("NFA: {!}", .{e});
            continue;
        };
        try nfaList.append(nfa);
    }

    const unifiedNfa, const acceptList = try nfaBuilder.merge(nfaList.items);
    defer acceptList.deinit();

    var dfa = DFA.init(alloc, unifiedNfa, acceptList, yy_ec_highest);
    defer dfa.deinit();

    try dfa.subset_construction();
    try dfa.minimize();
    try dfa.compress();

    try std.testing.expectEqual(true, try dfa.compareTTToCTT());
}

test "Keywords and Identifiers" {
    try assertCompressionIsValid("src/test/lex/inputs/keyword_and_identifiers.l");
}

test "Numbers and Operators" {
    try assertCompressionIsValid("src/test/lex/inputs/numbers_and_operators.l");
}

test "String and Comment Handling" {
    try assertCompressionIsValid("src/test/lex/inputs/string_and_comment.l");
}

test "Whitespace and Tokens" {
    try assertCompressionIsValid("src/test/lex/inputs/whitespace_and_tokens.l");
}

test "Arithmetic Expressions" {
    try assertCompressionIsValid("src/test/lex/inputs/arithmetic_expressions.l");
}

test "Comment and Operators" {
    try assertCompressionIsValid("src/test/lex/inputs/comment_and_operators.l");
}

test "Email Style" {
    try assertCompressionIsValid("src/test/lex/inputs/email_style.l");
}

test "Mixed Keywords and Numbers" {
    try assertCompressionIsValid("src/test/lex/inputs/mixed_keywords_and_numbers.l");
}
