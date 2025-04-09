const std               = @import("std");
const ParserModule      = @import("Parser.zig");
const Parser            = ParserModule.Parser;
const TokenizerModule   = @import("Tokenizer.zig");
const Tokenizer         = TokenizerModule.Tokenizer;
const Token             = TokenizerModule.Token;
const Makers            = @import("ParserMakers.zig");

pub fn fillLookupTables(self: *Parser) void {
    std.debug.assert(self.led_lookup == null);
    std.debug.assert(self.nud_lookup == null);

    self.nud_lookup = .{ null } ** Tokenizer.TokenCount;
    self.led_lookup = .{ null } ** Tokenizer.TokenCount;
    self.bp_lookup = .{ null } ** Tokenizer.TokenCount;
    
    if (self.nud_lookup) |*nuds| {
        nuds[@intFromEnum(Token.LBracket)] = &Makers.makeBracketExpr;
        nuds[@intFromEnum(Token.Char)] = &Makers.makeChar;
        nuds[@intFromEnum(Token.Dot)] = &Makers.makeDot;
        nuds[@intFromEnum(Token.AnchorStart)] = &Makers.makeAnchorStart;
    }

    if (self.led_lookup) |*leds| {
        leds[@intFromEnum(Token.Star)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.Plus)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.LBrace)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.Question)] = &Makers.makeRepetition;
        leds[@intFromEnum(Token.LBracket)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.Dot)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.Char)] = &Makers.makeConcat;
        leds[@intFromEnum(Token.AnchorEnd)] = &Makers.makeAnchorEnd;
        leds[@intFromEnum(Token.Union)] = &Makers.makeAlternation;
    }

    if (self.bp_lookup) |*bps| {
        bps[@intFromEnum(Token.LBracket)] = .Bracket;
        bps[@intFromEnum(Token.Star)] = .Duplication;
        bps[@intFromEnum(Token.Plus)] = .Duplication;
        bps[@intFromEnum(Token.Question)] = .Duplication;
        bps[@intFromEnum(Token.LBrace)] = .Duplication;
        bps[@intFromEnum(Token.Dot)] = .Concatenation;
        bps[@intFromEnum(Token.Char)] = .Concatenation;
        bps[@intFromEnum(Token.AnchorStart)] = .Anchoring;
        bps[@intFromEnum(Token.AnchorEnd)] = .Anchoring;
        bps[@intFromEnum(Token.Union)] = .Alternation;
    }
}
