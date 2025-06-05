const std               = @import("std");
const LexParser         = @import("../../lex/Parser.zig");
const EC                = @import("../../regex/EquivalenceClasses.zig");

const NFAModule         = @import("../../regex/NFA.zig");
const NFA               = NFAModule.NFA;

const DFAModule         = @import("../../regex/DFA.zig");
const DFA               = DFAModule.DFA;

const DFAMinimizer      = @import("../../regex/DFA_minimizer.zig");

const ParserModule      = @import("../../regex/Parser.zig");
const RegexParser       = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;

var     yy_ec: [256]u8  = .{0} ** 256;

fn assertCompressionIsValid(path: []const u8) !void {
    const alloc = std.testing.allocator;

    //NOTE: Reset this global otherwise we can't run more than one test sequentially
    DFAMinimizer.offset = 0;

    var lexParser = try LexParser.init(alloc, @constCast(path));
    defer lexParser.deinit();

    lexParser.parse() catch return;

    var regexParser = try RegexParser.init(alloc);
    defer regexParser.deinit();

    var headList = std.ArrayList(*RegexNode).init(alloc);
    defer headList.deinit();

    for (lexParser.rules.items) |rule| {
        regexParser.loadSlice(rule.regex);
        // std.debug.print("Parsing regex: {s}", .{rule.regex});
        const head = regexParser.parse() catch |e| {
            std.log.err("\"{s}\": {!}", .{rule.regex, e});
            return;
        };
        // head.dump(0);
        try headList.append(head);
    }

    const ec = try EC.buildEquivalenceTable(alloc, regexParser.classSet);

    var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &regexParser, &ec.yy_ec);
    defer nfaBuilder.deinit();

    var nfaList = std.ArrayList(NFA).init(alloc);
    defer nfaList.deinit();

    for (headList.items) |head| {
        nfaBuilder.reset();
        const nfa = nfaBuilder.astToNfa(head) catch |e| {
            std.log.err("NFA: {!}", .{e});
            continue;
        };
        try nfaList.append(nfa);
    }

    const mergedNFAs, const bolMergedNFAs, const tcNFAs = try nfaBuilder.merge(nfaList.items, lexParser);
    defer {
        for (mergedNFAs.items) |m| alloc.free(m.acceptList);
        for (bolMergedNFAs.items) |m| alloc.free(m.acceptList);
        for (tcNFAs.items) |m| alloc.free(m.acceptList);
        mergedNFAs.deinit(); bolMergedNFAs.deinit(); tcNFAs.deinit();
    }

    var finalDfa, var DFAs, var bol_DFAs, var tc_DFAs = 
    try DFA.buildAndMergeFromNFAs(alloc, mergedNFAs, bolMergedNFAs, tcNFAs, ec);

    defer {
        for (DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        for (bol_DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        for (tc_DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        DFAs.deinit(alloc); bol_DFAs.deinit(alloc); tc_DFAs.deinit(alloc);
        finalDfa.mergedDeinit();
    }

    try std.testing.expectEqual(true, try finalDfa.compareTTToCTT());
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

test "Keywords and Identifier 2" {
    try assertCompressionIsValid("src/test/lex/inputs/keywords_and_ids_2.l");
}

test "Numbers and floats" {
    try assertCompressionIsValid("src/test/lex/inputs/numbers_and_floats.l");
}

test "String operatos" {
    try assertCompressionIsValid("src/test/lex/inputs/string_operators.l");
}

test "Crazy regex" {
    try assertCompressionIsValid("src/test/lex/inputs/crazy_regex.l");
}

test "Crazy regex 2" {
    try assertCompressionIsValid("src/test/lex/inputs/crazy_regex_2.l");
}

test "Number and operator hell" {
    try assertCompressionIsValid("src/test/lex/inputs/num_op_hell.l");
}

test "Literal heavy" {
    try assertCompressionIsValid("src/test/lex/inputs/literal_heavy.l");
}

test "Json fragments" {
    try assertCompressionIsValid("src/test/lex/inputs/json_fragments.l");
}

test "Rust" {
    try assertCompressionIsValid("src/test/lex/inputs/rust.l");
}

test "C" {
    try assertCompressionIsValid("src/test/lex/inputs/c.l");
}

test "Python" {
    try assertCompressionIsValid("src/test/lex/inputs/python.l");
}

// test "Mega lexer" {
//     try assertCompressionIsValid("src/test/lex/inputs/mega_lexer.l");
// }
