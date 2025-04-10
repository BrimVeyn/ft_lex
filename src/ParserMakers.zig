const std               = @import("std");

const ParserModule      = @import("Parser.zig");
const ParserError       = ParserModule.ParserError;
const RegexNode         = ParserModule.RegexNode;
const Parser            = ParserModule.Parser;
const TokenizerModule   = @import("Tokenizer.zig");
const Token             = TokenizerModule.Token;
const PosixClass        = TokenizerModule.PosixClass;

pub fn makeNode(self: *Parser, node: RegexNode) ParserError!*RegexNode {
    const ret = try self.pool.create();
    ret.* = node;
    return ret;
}

//INFO: ------------------- NUDS ---------------------
pub fn makeChar(self: *Parser) ParserError!*RegexNode {
    return makeNode(self, .{ .Char = self.advance().Char });
}

pub fn makeDot(self: *Parser) ParserError!*RegexNode {
    _ = self.advance();
    return makeNode(self, .Dot);
}

pub fn makeAnchorStart(self: *Parser) ParserError!*RegexNode {
    _ = self.advance();
    return makeNode(self, .{ 
        .AnchorStart = try self.parseExpr(.Anchoring),
    });
}

fn makeBitSet(comptime predicate: fn (u8) bool) std.StaticBitSet(256) {
    var ret = std.StaticBitSet(256).initEmpty();
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const iu8: u8 = @intCast(i);
        if (predicate(iu8)) {
            ret.set(iu8);
        }
    }
    return ret;
}


fn fillRange(range: *std.StaticBitSet(256), class: PosixClass) void {
    range.* = blk: switch (class) {
        .alpha => break :blk range.unionWith(makeBitSet(std.ascii.isAlphabetic)),
        .alnum => break :blk range.unionWith(makeBitSet(std.ascii.isAlphanumeric)),
        .cntrl => break :blk range.unionWith(makeBitSet(std.ascii.isControl)),
        else => std.debug.panic("Unhandled POSIX class: {}", .{class}),
    };
}


fn getPosixClass(self: *Parser) ParserError!PosixClass {
    std.debug.assert(self.currentEql(.{ .Char = '[' }));
    std.debug.assert(self.peakEql(.{ .Char = ':' }));
    _ = self.advance();
    _ = self.advance();
    std.log.debug("[POSIX]: {}", .{self.current});

    var buffer: [256]u8 = .{0} ** 256;
    var it: usize = 0;

    while (true) {
        if (self.currentEql(.{ .Char = ':' }) and self.peakEql(.{ .Char = ']' })) {
            _ = self.advance(); _ = self.advance();
            break;
        }
        buffer[it] = self.current.Char;
        it += 1;
        _ = self.advance();
    }

    return std.meta.stringToEnum(PosixClass, buffer[0..it]) 
        orelse error.BracketExpInvalidPosixClass;
}

pub fn makeBracketExpr(self: *Parser) ParserError!*RegexNode {
    var range = std.StaticBitSet(256).initEmpty();
    var negate = false;

    //INFO: Change tokenizer context to produce BrackExp tokens
    self.tokenizer.changeContext(.BracketExp);

    std.debug.assert(self.currentEql(.LBracket));
    _ = self.advance();

    if (self.currentEql(.{ .Char = '^' })) {
        negate = true;
        _ = self.advance();
    }

    //NOTE: Exception, if the first character is RBracket or Dash, its treated as a literal
    if (self.currentEql(.{.Char = ']'}) or self.currentEql(.{ .Char = '-' })) {
        range.set(self.current.Char);
        _ = self.advance();
    }

    while (true) {
        std.log.debug("BRACKET: Current: {any}", .{self.current});
        if (self.currentEql(.Eof)) 
            return ParserError.MalformedBracketExp; //NOTE: Shouldn't reach EOF in a bracketExp
        if (self.currentEql(.{ .Char = ']' })) 
            break; //NOTE: g2g
        if (self.currentEql(.{ .Char = '[' }) and self.peakEql(.{ .Char = ':' })) {
            const class: PosixClass = try getPosixClass(self);
            fillRange(&range, class);
            continue;
        }
        
        if (self.peakEql(.{ .Char = '-' })) {
            const rangeStart = self.current.Char;
            _ = self.advance();
            _ = self.advance();
            if (self.currentEql(.{ .Char = ']' })) {
                range.set(rangeStart);
                range.set('-');
                continue;
            }
            const rangeEnd = self.current.Char;

            if (rangeEnd < rangeStart)
                return error.BracketExpOutOfOrder;

            for (rangeStart..rangeEnd) |i| {
                range.set(@as(u8, @intCast(i)));
            }
            continue;
        }

        range.set(self.current.Char);
        _ = self.advance();
    }
    std.debug.assert(self.currentEql(.{ .Char = ']' }));
    _ = self.advance();

    //INFO: Restore Regexp Toknizer state
    self.tokenizer.changeContext(.RegexExp);

    return makeNode(self, .{
        .CharClass = .{ .negate = negate, .range = range } },
    );
}

//INFO:------------------------------------------------



//INFO:-------------------LEDS-------------------------

pub fn makeConcat(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    return makeNode(self, .{
        .Concat = .{
            .left = left,
            .right = try self.parseExpr(.Concatenation),
        },
    });
}

pub fn makeAlternation(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    _ = self.advance();
    return makeNode(self, .{
        .Alternation = .{ 
            .left =  left,
            .right = try self.parseExpr(.Alternation),
        },
    });
}


pub fn makeAnchorEnd(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    _ = self.advance();
    return makeNode(self, .{
        .AnchorEnd = left 
    });
}

fn parseInt(self: *Parser) ParserError!usize {
    var buffer: [16]u8 = .{0} ** 16;
    var i: usize = 0;

    while (true) {
        const token = self.current;

        if (token.eql(.{.Char = ','}) or token.eql(.RBrace))
            break;

        if (std.meta.activeTag(token) != Token.Char or (token.Char < '0' or token.Char > '9')) {
            return error.BracesExpUnexpectedChar;
        }

        buffer[i] = token.Char;
        i += 1;
        _ = self.advance();
    }
    return std.fmt.parseInt(usize, buffer[0..i], 10) catch {
        return error.BracesExpUnexpectedChar; 
    };
}

pub fn makeBracesExpr(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    var min: usize = 0;
    var max: ?usize = null;
    
    min = try parseInt(self);

    var current = self.current;
    std.log.debug("current: {}", .{current});

    if (current.eql(.RBrace)) {
        _ = self.advance();
        return makeNode(self, .{ .Repetition = .{ .min = min, .max = min, .left = left }, });
    }

    if (std.meta.activeTag(current) != Token.Char or current.Char != ',') {
        std.debug.print("You're on a good way", .{});
        return error.BracesExpUnexpectedChar;
    }

    //NOTE: Current is now ','
    _ = self.advance();

    if (self.current.eql(.RBrace)) {
        _ = self.advance();
        return makeNode(self, .{ .Repetition = .{ .min = min, .max = INFINITY, .left = left }, });
    }

    max = try parseInt(self);
    std.log.debug("MAX: {?}", .{max});
    
    std.debug.assert(self.current.eql(.RBrace));
    _ = self.advance();

    return makeNode(self, .{ .Repetition = .{ .min = min, .max = max, .left = left } });
}



const INFINITY = 10_000_000;

pub fn makeRepetition(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    const token = self.advance();
    return switch (token) {
        .Star => makeNode(self, .{
            .Repetition = .{ 
                .min = 0,
                .max = INFINITY,
                .left = left 
            },
        }),
        .Plus => makeNode(self, .{
            .Repetition = .{
                .min = 1,
                .max = INFINITY,
                .left = left 
            },
        }),
        .Question => makeNode(self, .{
            .Repetition = .{
                .min = 0,
                .max = 1,
                .left = left 
            },
        }),
        .LBrace => makeBracesExpr(self, left),
        else => std.debug.panic("Unsupported repetition token: {s}", .{@tagName(self.current)}),
    };
}

