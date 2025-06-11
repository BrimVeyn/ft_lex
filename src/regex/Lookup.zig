const std               = @import("std");
const ParserModule      = @import("Parser.zig");
const Parser            = ParserModule.Parser;
const ParserError       = ParserModule.ParserError;
const RegexNode         = ParserModule.RegexNode;
const TokenizerModule   = @import("Tokenizer.zig");
const Tokenizer         = TokenizerModule.Tokenizer;
const Token             = TokenizerModule.Token;
const Makers            = @import("ParserMakers.zig");

fn makeNudError(comptime err: ParserError) (fn (*Parser) ParserError!*RegexNode) {
    return struct {
        fn throwError(_: *Parser) ParserError!*RegexNode {
            return err;
        }
    }.throwError;
}

fn makeLedError(comptime err: ParserError) (fn (*Parser, *RegexNode) ParserError!*RegexNode) {
    return struct {
        fn throwError(_: *Parser, _: *RegexNode) ParserError!*RegexNode {
            return err;
        }
    }.throwError;
}

pub fn fillLookupTables(self: *Parser) void {
    std.debug.assert(self.led_lookup == null);
    std.debug.assert(self.nud_lookup == null);

    self.nud_lookup = .{ null } ** Tokenizer.TokenCount;
    self.led_lookup = .{ null } ** Tokenizer.TokenCount;
    self.bp_lookup = .{ null } ** Tokenizer.TokenCount;
    
    if (self.nud_lookup) |*nuds| {
        nuds[@intFromEnum(Token.LBracket)] = &Makers.makeBracketExpr;
        nuds[@intFromEnum(Token.Char)] = &Makers.makeChar;
        nuds[@intFromEnum(Token.Dot)] = &Makers.makeBracketExpr;
        nuds[@intFromEnum(Token.AnchorStart)] = &Makers.makeAnchorStart;
        nuds[@intFromEnum(Token.LParen)] = &Makers.makeGroup;
        nuds[@intFromEnum(Token.Escape)] = &Makers.makeEscape;
        nuds[@intFromEnum(Token.Quote)] = &Makers.makeQuote;

        //Error generating tokens
        nuds[@intFromEnum(Token.RParen)] = &makeNudError(ParserError.UnbalancedParenthesis);
        nuds[@intFromEnum(Token.Union)] = &makeNudError(ParserError.PrefixUnexpected);
        nuds[@intFromEnum(Token.AnchorEnd)] = &makeNudError(ParserError.PrefixUnexpected);
        nuds[@intFromEnum(Token.RBrace)] = &makeNudError(ParserError.UnexpectedRightBrace);
        nuds[@intFromEnum(Token.RBracket)] = &makeNudError(ParserError.UnexpectedRightBracket);
        nuds[@intFromEnum(Token.LBrace)] = &makeNudError(ParserError.UnexpectedPostfixOperator);
        nuds[@intFromEnum(Token.Star)] = &makeNudError(ParserError.UnexpectedPostfixOperator);
        nuds[@intFromEnum(Token.Plus)] = &makeNudError(ParserError.UnexpectedPostfixOperator);
        nuds[@intFromEnum(Token.Question)] = &makeNudError(ParserError.UnexpectedPostfixOperator);
        nuds[@intFromEnum(Token.TrailingContext)] = &makeNudError(ParserError.UnexpectedPostfixOperator);
        nuds[@intFromEnum(Token.Eof)] = &makeNudError(ParserError.UnexpectedEof);
    }

    // for (self.nud_lookup.?, 0..) |nud, i| {
    //     std.debug.print("Nuds: {d}: {any}\n", .{i, nud});
    // }

    if (self.led_lookup) |*leds| {
        leds[@intFromEnum(Token.Star)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.Plus)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.LBrace)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.Question)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.LBracket)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.LParen)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.Dot)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.Char)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.Escape)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.AnchorEnd)] = &Makers.makeAnchorEnd;
        leds[@intFromEnum(Token.Union)] = &Makers.makeAlternation;
        leds[@intFromEnum(Token.TrailingContext)] = &Makers.makeTrailingContext;
        leds[@intFromEnum(Token.Quote)] = &Makers.makeConcat;

        //Error generating tokens
        leds[@intFromEnum(Token.AnchorStart)] = &makeLedError(ParserError.PrefixUnexpected);
        leds[@intFromEnum(Token.RParen)] = &makeLedError(ParserError.UnbalancedParenthesis);
        leds[@intFromEnum(Token.RBrace)] = &makeLedError(ParserError.UnexpectedRightBrace);
        leds[@intFromEnum(Token.RBracket)] = &makeLedError(ParserError.UnexpectedRightBracket);
        leds[@intFromEnum(Token.Eof)] = &makeLedError(ParserError.UnexpectedEof);
    }

    // for (self.led_lookup.?, 0..) |nud, i| {
    //     std.debug.print("Nuds: {d}: {any}\n", .{i, nud});
    // }

    if (self.bp_lookup) |*bps| {
        bps[@intFromEnum(Token.LBracket)] = .Bracket;
        bps[@intFromEnum(Token.LParen)] = .Grouping;
        bps[@intFromEnum(Token.Star)] = .Duplication;
        bps[@intFromEnum(Token.Plus)] = .Duplication;
        bps[@intFromEnum(Token.Question)] = .Duplication;
        bps[@intFromEnum(Token.LBrace)] = .Duplication;
        bps[@intFromEnum(Token.Dot)] = .Concatenation;
        bps[@intFromEnum(Token.Char)] = .Concatenation;
        bps[@intFromEnum(Token.TrailingContext)] = .Anchoring;
        bps[@intFromEnum(Token.AnchorStart)] = .Anchoring;
        bps[@intFromEnum(Token.AnchorEnd)] = .Anchoring;
        bps[@intFromEnum(Token.Union)] = .Alternation;
        bps[@intFromEnum(Token.Escape)] = .Escaped;
        bps[@intFromEnum(Token.Quote)] = .Quoting;

        //Error generating tokens
        bps[@intFromEnum(Token.RBrace)] = .None;
        bps[@intFromEnum(Token.RParen)] = .None;
        bps[@intFromEnum(Token.RBracket)] = .None;
        bps[@intFromEnum(Token.Eof)] = .None;
    }

    // for (self.bp_lookup.?) |bp| {
    //     std.log.debug("bp: {any}", .{bp});
    // }
}
