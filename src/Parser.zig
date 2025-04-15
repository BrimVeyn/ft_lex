const std               = @import("std");
const log               = std.log;

const Lookup            = @import("Lookup.zig");
const fillLookupTables  = Lookup.fillLookupTables;
const RegexNodeDump     = @import("RegexNodeDump.zig");
const TokenizerModule   = @import("Tokenizer.zig");
const Tokenizer         = TokenizerModule.Tokenizer;
const Token             = TokenizerModule.Token;
const Makers            = @import("ParserMakers.zig");
pub const makeNode      = Makers.makeNode;

pub const Parser = @This();

const ParserErrorSet = error {
    PrefixUnexpected,
    BracesExpUnexpectedChar,
    BracketExpOutOfOrder,
    BracketExpInvalidPosixClass,
    MalformedBracketExp,
    TooManyTrailingContexts,
    UnbalancedParenthesis,
    UnbalancedQuotes,
    UnexpectedRightBrace,
    UnexpectedRightBracket,
    UnexpectedPostfixOperator,
    AnchorMisuse,
    UnexpectedEof,
    BadStartConditionList,
};

pub const INFINITY: usize = 1_000_000;

pub const BindingPower = enum(u8) {
    None = 0,
    Alternation,
    Anchoring,
    Concatenation,
    Duplication,
    Grouping,
    Quoting,
    Bracket,
    Escaped,
};

pub const RegexNode = union(enum) {
    Char: u8,
    Group: *RegexNode,
    AnchorStart: *RegexNode,
    AnchorEnd: *RegexNode,
    CharClass: struct {
        negate: bool,
        range: std.StaticBitSet(256),
    },
    Concat: struct {
        left: *RegexNode,
        right: *RegexNode,
    },
    TrailingContext: struct {
        left: *RegexNode,
        right: *RegexNode,
    },
    Alternation: struct {
        left: *RegexNode,
        right: *RegexNode,
    },
    Repetition: struct {
        min: usize,
        max: ?usize,
        left: *RegexNode,
    },
    StartCondition: struct {
        name: [64:0]u8,
        left: *RegexNode,
    },

    pub const dump = RegexNodeDump.dump;
};

const nud_handler_fn = *const fn (self: *Parser) ParserError!*RegexNode;
const led_handler_fn = *const fn (self: *Parser, left: *RegexNode) ParserError!*RegexNode;

tokenizer: Tokenizer,
current: Token,
pool: std.heap.MemoryPool(RegexNode),
nud_lookup: ?[Tokenizer.TokenCount]?nud_handler_fn = null,
led_lookup: ?[Tokenizer.TokenCount]?led_handler_fn = null,
bp_lookup: ?[Tokenizer.TokenCount]?BindingPower = null,
//Used to handle nested grouping
depth: usize = 0,
hasSeenTrailingContext: bool = false,

pub fn init(alloc: std.mem.Allocator, input: []const u8) !Parser {
    var tokenizer = Tokenizer.init(input, .RegexExpStart);
    const first_token = tokenizer.next();
    std.log.info("Token: {}", .{first_token});
    const pool  = std.heap.MemoryPool(RegexNode).init(alloc);

    return .{
        .tokenizer = tokenizer,
        .current = first_token,
        .pool = pool,
    };
}

pub fn deinit(self: *Parser) void {
    self.pool.deinit();
}

// INFO: Returns the previous token
pub fn advance(self: *Parser) Token {
    const token = self.current;
    self.current = self.tokenizer.next();
    std.log.info("Token: {}", .{self.current});
    return token;
}

pub fn advanceN(self: *Parser, n: usize) Token {
    std.debug.assert(n != 0);
    var token: Token = undefined;
    for (0..n) |_| token = self.advance();
    return token;
}

pub fn peak(self: *Parser) Token {
    return self.tokenizer.peak();
}

pub fn currentEql(self: *Parser, token: Token) bool { return Token.eql(self.current, token); }
pub fn peakEql(self: *Parser, token: Token) bool { return Token.eql(self.tokenizer.peak(), token); }

pub const ParserError = ParserErrorSet || error { OutOfMemory };

pub fn getBp(self: Parser) BindingPower {
    std.debug.assert(self.bp_lookup != null);
    const token = self.current;

    if (self.bp_lookup.?[@intFromEnum(token)] == null) {
        std.debug.panic("Unimplemented nud function for token: {s}", .{@tagName(token)});
    }

    return self.bp_lookup.?[@intFromEnum(token)].?;
}

pub fn nud(self: *Parser) ParserError!*RegexNode {
    std.debug.assert(self.nud_lookup != null);
    const token = self.current;

    if (self.nud_lookup.?[@intFromEnum(token)] == null) {
        std.debug.panic("Unimplemented nud function for token: {s}", .{@tagName(token)});
    }

    return self.nud_lookup.?[@intFromEnum(token)].?(self);
}

pub fn led(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    std.debug.assert(self.led_lookup != null);
    const token = self.current;

    if (self.led_lookup.?[@intFromEnum(token)] == null) {
        std.debug.panic("Unimplemented led function for token: {s}", .{@tagName(token)});
    }

    return self.led_lookup.?[@intFromEnum(token)].?(self, left);
}

pub fn parseExpr(self: *Parser, min_bp: BindingPower) ParserError!*RegexNode {
    var left = try self.nud();

    while (self.current != .Eof) {
        const cur_bp = self.getBp();

        if (self.depth > 0 and (self.currentEql(.RParen) or self.currentEql(.Quote)))
            break;

        if (@intFromEnum(cur_bp) < @intFromEnum(min_bp))
            break;

        left = try self.led(left);
    }
    return left;
}

pub fn parse(self: *Parser) !*RegexNode {
    //INFO: We can't fill the lookup tables at comptime since this struct isn't itself comptime so we fill it before parsing starts.
    //No need to refill it if we reuse the Parser
    if (self.bp_lookup == null or self.nud_lookup == null or self.led_lookup == null) {
        self.fillLookupTables();
    }

    return self.parseExpr(.None);
}
