const std           = @import("std");
const ParserModule  = @import("Parser.zig");
const ParserError   = ParserModule.ParserError;
const RegexNode     = ParserModule.RegexNode;
const Parser        = ParserModule.Parser;

pub fn makeNode(self: *Parser) !*RegexNode {
    return try self.alloc.create(RegexNode);
}

pub fn makeConcat(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    const node = try self.makeNode();
    node.* = .{
        .Concat = .{
            .left = left,
            .right = try self.parseExpr(.Concatenation),
        },
    };
    return node;
}



pub fn makeAlternation(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    _ = self.advance();
    const node = try self.makeNode();
    node.* = .{
        .Alternation = .{
            .left = left,
            .right = try self.parseExpr(.Alternation),
        },
    };
    return node;
}

pub fn makeChar(self: *Parser) ParserError!*RegexNode {
    const node = try self.makeNode();
    const char = self.advance().Char;
    node.* = .{
        .Char = char,
    };
    return node;
}

pub fn makeAnchorStart(self: *Parser) ParserError!*RegexNode {
    _ = self.advance();
    const node = try self.makeNode();
    node.* = .{
        .AnchorStart = try self.parseExpr(.Anchoring),
    };
    return node;
}

pub fn makeAnchorEnd(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    _ = self.advance();
    const node = try self.makeNode();
    node.* = .{
        .AnchorEnd = left,
    };
    return node;
}

pub fn makeBracketExp(self: *Parser) ParserError!*RegexNode {
    var range = std.StaticBitSet(255).initEmpty();
    const negate = false;

    //NOTE: Skip LBracket
    _ = self.advance();

    while (true) {
        if (self.match(.Eof)) return ParserError.MalformedBracketExp; //NOTE: Shouldn't reach EOF in a bracketExp
        if (self.match(.RBracket)) break; //NOTE: g2g
        
        if (self.matchPeak(.{ .Char = '-' }) and self.matchNoSpecial()) {
            const rangeStart = self.current.Char;
            _ = self.advance();
            _ = self.advance();
            if (!self.matchNoSpecial()) return error.BracketExpUnexpectedChar; //NOTE: Eof or escape

            const rangeEnd = self.current.Char;
            if (rangeEnd < rangeStart) return error.BracketExpOutOfOrder;
            for (rangeStart..rangeEnd) |i| {
                range.set(@as(u8, @intCast(i)));
            }
        }

        if (self.matchNoSpecial()) {
            range.set(self.current.Char);
            _ = self.advance();
        }
    }
    _ = self.advance(); //NOTE: Consume RBracket
    const ptr = try self.alloc.create(RegexNode);
    ptr.* = RegexNode { .CharClass = .{ .negate = negate, .range = range } };
    return ptr;
}

const INFINITY = 10_000_000;

pub fn makeStar(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    const node = try self.makeNode();
    node.* = .{
        .Repetition = .{
            .min = 0,
            .max = INFINITY,
            .left = left,
        },
    };
    return node;
}

pub fn makePlus(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    const node = try self.makeNode();
    node.* = .{
        .Repetition = .{
            .min = 1,
            .max = INFINITY,
            .left = left,
        },
    };
    return node;
}

pub fn makeQuestion(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    const node = try self.makeNode();
    node.* = .{
        .Repetition = .{
            .min = 0,
            .max = 1,
            .left = left,
        },
    };
    return node;
}


pub fn makeRepetition(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    const token = self.advance();
    return switch (token) {
        .Star => makeStar(self, left),
        .Plus => makePlus(self, left),
        .Question => makeQuestion(self, left),
        else => std.debug.panic("Unsupported repetition tokne: {s}", .{@tagName(self.current)}),
    };
}
