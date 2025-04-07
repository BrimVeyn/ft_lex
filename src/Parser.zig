const std = @import("std");
const TokenizerModule = @import("Tokenizer.zig");

const Tokenizer = TokenizerModule.Tokenizer;
const Token     = TokenizerModule.Token;
const Makers = @import("ParserMakers.zig");
const log = std.log;

pub const Parser = @This();


pub const RegexNode = union(enum) {
    Char: u8,
    Star: *RegexNode,
    Plus: *RegexNode,
    Optional: *RegexNode,
    Group: *RegexNode,
    AnchorStart,
    AnchorEnd,
    CharClass: struct {
        negate: bool,
        range: std.StaticBitSet(255),
    },
    Concat: struct {
        left: *RegexNode,
        right: *RegexNode,
    },
    Alternation: struct {
        left: *RegexNode,
        right: *RegexNode,
    },
    Repeat: struct {
        min: usize,
        max: ?usize,
        node: *RegexNode,
    },

    pub fn format(self: *const RegexNode, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        switch (self.*) {
            .CharClass => {
                var buffer: [255]u8 = .{0} ** 255;
                var bufIt: usize = 0;
                for (0..255) |i| {
                    if (self.CharClass.range.isSet(i)) {
                        buffer[bufIt] = @as(u8, @intCast(i));
                        bufIt += 1;
                    }
                }
                try writer.print("CharClass({}): {s}", .{self.CharClass.negate, buffer});
            },
            else => try writer.print("{}", .{self}),
        }
    }
};


tokenizer: Tokenizer,
current: Token,
alloc: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator, input: []const u8) !Parser {
    var tokenizer = Tokenizer.init(input);
    const first_token = tokenizer.next();
    std.log.info("Token: {}", .{first_token});
    return .{
        .tokenizer = tokenizer,
        .current = first_token,
        .alloc = alloc,
    };
}

pub const makeConcat = Makers.makeConcat;

pub fn advance(self: *Parser) void {
    self.current = self.tokenizer.next();
    std.log.info("Token: {}", .{self.current});
}

pub fn match(self: *Parser, token: Token) bool { return Token.eql(self.current, token); }
pub fn matchPeak(self: *Parser, token: Token) bool { return Token.eql(self.tokenizer.peak(), token); }
pub fn matchNoSpecial(self: *Parser) bool {
    return !self.match(.Eof) and !self.match(.Escape);
}

pub fn parseBracketExp(self: *Parser) !*RegexNode {
    var range = std.StaticBitSet(255).initEmpty();
    const negate = false;

    //NOTE: Skip LBracket
    self.advance();

    while (true) {
        std.debug.print("CURRENT: {}\n", .{self.current});
        if (self.match(.Eof)) return error.MalformedBracketExp; //NOTE: Shouldn't reach EOF in a bracketExp
        if (self.match(.RBracket)) break; //NOTE: g2g
        
        if (self.matchPeak(.{ .Char = '-' }) and self.matchNoSpecial()) {
            const rangeStart = self.current.Char;
            self.advance();
            self.advance();
            if (!self.matchNoSpecial()) return error.BracketExpUnexpectedChar; //NOTE: Eof or escape

            const rangeEnd = self.current.Char;
            if (rangeEnd < rangeStart) return error.BracketExpOutOfOrder;
            for (rangeStart..rangeEnd) |i| {
                range.set(@as(u8, @intCast(i)));
            }
        }

        if (self.matchNoSpecial()) {
            range.set(self.current.Char);
            self.advance();
        }
    }
    self.advance(); //NOTE: Consume RBracket
    const ptr = try self.alloc.create(RegexNode);
    ptr.* = RegexNode { .CharClass = .{ .negate = negate, .range = range } };
    return ptr;
}

const Precedence = enum(u8) {
    Bracket = 4,
    Star = 3,
    Concat = 2,
    Alternation = 1,
    None = 0,
};

pub fn peekPrecedence(self: Parser) Precedence {
    return switch (self.current) {
        .LBracket => .Bracket,
        .Star => .Star,
        .Union => .Alternation,
        .Char => .Concat,
        else => .None,
    };
}

pub fn parsePrefix(self: *Parser) !*RegexNode {
    return switch (self.current) {
        .Char => {
            const ptr = try self.alloc.create(RegexNode);
            ptr.* = RegexNode{ .Char = self.current.Char };
            return ptr;
        },
        .LBracket => try self.parseBracketExp(),
        else => error.PrefixUnexpected,
    };
}

pub fn parseInfix(self: *Parser, left: *RegexNode) !*RegexNode {
    const token = self.current;

    return switch (token) {
        .Char => error.InfixUnexpected,
        // .Union => {
        //     self.advance();
        //     const right = try self.parseExpression(Precedence.Alternation);
        //     return RegexNode{ .Alternation = .{ .left = left, .right = right } };
        // },
        .Star => {
            self.advance();
            const ptr = try self.alloc.create(RegexNode);
            ptr.* = RegexNode{ .Star = left };
            return ptr;
        },
        else => error.InfixUnexpected,
    };
}

pub fn parseExp(self: *Parser, min_prec: Precedence) !*RegexNode {
    var left = try self.parsePrefix();

    while (true) {
        const prec = self.peekPrecedence();
        if (@intFromEnum(prec) < @intFromEnum(min_prec))
            break;

        self.advance();
        left = try self.parseInfix(left);
    }

    return left;
}

pub fn parse(self: *Parser) !*RegexNode {
    return try self.parseExp(.None);
}
