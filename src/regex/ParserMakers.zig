const std               = @import("std");

const ParserModule      = @import("Parser.zig");
const ParserError       = ParserModule.ParserError;
const RegexNode         = ParserModule.RegexNode;
const Parser            = ParserModule.Parser;

const TokenizerModule   = @import("Tokenizer.zig");
const Token             = TokenizerModule.Token;
const PosixClass        = TokenizerModule.PosixClass;
const INFINITY          = Parser.INFINITY;

const Ascii             = @import("Ascii.zig");

pub fn makeNode(self: *Parser, node: RegexNode) !*RegexNode {
    const ret = try self.pool.create();
    if (std.meta.activeTag(node) == .CharClass)
        try self.classSet.put(node.CharClass.range, {});

    ret.* = node;
    return ret;
}

//INFO: ------------------- NUDS ---------------------

pub fn makeChar(self: *Parser) ParserError!*RegexNode {
    var range = std.StaticBitSet(256).initEmpty();
    range.set(self.advance().Char);

    return makeNode(self, .{
        .CharClass = .{
            .negate = false,
            .range = range 
        }
    });
}

pub fn makeQuote(self: *Parser) ParserError!*RegexNode {
    self.tokenizer.changeContext(.QuoteExp);
    _ = self.advance();

    self.depth += 1;
    const inner = try self.parseExpr(.None);

    self.tokenizer.changeContext(.RegexExpCommon);
    if (!self.currentEql(.Quote)) {
        return error.UnbalancedQuotes;
    }
    _ = self.advance();

    self.depth -= 1;

    return makeNode(self, .{
        .Group = inner,
    });
}

pub fn makeStartCondition(self: *Parser) ParserError!*RegexNode {
    std.debug.assert(self.currentEql(.StartConditionOpen));
    self.tokenizer.changeContext(.BracketExp);
    _ = self.advance();
    var buffer: [64:0]u8 = .{0} ** 64;
    var i: usize = 0;
    while (true) {
        if (self.currentEql(.Eof))
            return error.UnexpectedEof;
        if (self.currentEql(.{ .Char = '>' })) {
            break;
        }
        buffer[i] = self.current.Char;
        i += 1;
        _ = self.advance();
    }
    self.tokenizer.changeContext(.RegexExpCommon);
    if (i == 0 or !self.currentEql(.{ .Char = '>' })) {
        return error.BadStartConditionList;
    }
    _ = self.advance();

    return makeNode(self, .{
        .StartCondition = .{
            .name = buffer,
            .left = try self.parseExpr(.None) 
        } 
    });
}

pub fn getEscaped(self: *Parser) !Token {
    var is_hexa = false;
    var is_octal = false;
    var eaten: usize  = 0;
    var buffer: [5]u8 = .{0} ** 5;
    var go_back = false;
    var i: usize = 0;

    while (true) {
        _ = self.advance();
        if (self.currentEql(.Eof))
            break;

        if (self.currentEql(.{ .Char = '\x00' }) or eaten == 3) {
            go_back = true;
            break;
        }


        if (eaten == 0 and self.currentEql(.{ .Char = 'x' })) {
            is_hexa = true; eaten += 1;
            continue;
        } else if (eaten == 0 and Ascii.isOctal(self.current.Char)) {
            buffer[i] = self.current.Char;
            i += 1; is_octal = true; eaten += 1;
            continue;
        }

        if ((is_hexa and !std.ascii.isHex(self.current.Char))
            or (is_octal and !Ascii.isOctal(self.current.Char))) {
            go_back = true;
            break;
        }

        if (is_hexa and std.ascii.isHex(self.current.Char)) {
            buffer[i] = self.current.Char;
            i += 1; eaten += 1;
            continue;
        }

        if (is_octal and Ascii.isOctal(self.current.Char)) {
            buffer[i] = self.current.Char;
            i += 1; eaten += 1;
            continue;
        }

        return switch (self.current.Char) {
            'a' => Token{.Char = 0x07 },
            'b' => Token{.Char = 0x08 },
            'f' => Token{.Char = 0x0C },
            'n' => Token{.Char = 0x0A },
            'r' => Token{.Char = 0x0D },
            't' => Token{.Char = 0x09 },
            'v' => Token{.Char = 0x0B },
            else => self.current,
        };
    }
    //Go back one character so the tokenizer can reinterpret it 
    //as part of the regex and not the escape sequence
    if (go_back) self.tokenizer.index -= 1;
    return if (is_hexa) Token{ .Char = try std.fmt.parseInt(u8, buffer[0..i], 16) }
        else Token{ .Char = try std.fmt.parseInt(u8, buffer[0..i], 8) };
}

pub fn makeEscape(self: *Parser) ParserError!*RegexNode {
    std.debug.assert(self.currentEql(.Escape));

    self.tokenizer.changeContext(.BracketExp);
    const char = getEscaped(self) catch {
        return error.UnexpectedEof;
    };

    if (Token.eql(char, .Eof)) {
        return error.OutOfMemory;
    }

    self.tokenizer.changeContext(.RegexExpCommon);
    _ = self.advance();

    const node = makeNode(self, .{ .Char = char.Char });

    return node;
}

pub fn makeGroup(self: *Parser) ParserError!*RegexNode {
    std.debug.assert(self.currentEql(.LParen));
    _ = self.advance();
    self.depth += 1;
    const groupBody = try self.parseExpr(.None);
    const node = makeNode(self, .{
        .Group = groupBody,
    });
    if (!self.currentEql(.RParen)) {
        return error.UnbalancedParenthesis;
    }
    _ = self.advance();
    self.depth -= 1;
    return node;
}


pub fn makeAnchorStart(self: *Parser) ParserError!*RegexNode {
    std.debug.assert(self.currentEql(.AnchorStart));
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
        .upper  => break: blk range.unionWith(makeBitSet(std.ascii.isUpper)),
        .lower  => break: blk range.unionWith(makeBitSet(std.ascii.isLower)),
        .alpha  => break :blk range.unionWith(makeBitSet(std.ascii.isAlphabetic)),
        .digit  => break :blk range.unionWith(makeBitSet(std.ascii.isDigit)),
        .xdigit => break :blk range.unionWith(makeBitSet(std.ascii.isHex)),
        .alnum  => break :blk range.unionWith(makeBitSet(std.ascii.isAlphanumeric)),
        .punct  => break :blk range.unionWith(makeBitSet(Ascii.isPunct)),
        .blank  => break :blk range.unionWith(makeBitSet(Ascii.isBlank)),
        .space  => break :blk range.unionWith(makeBitSet(std.ascii.isWhitespace)),
        .cntrl  => break :blk range.unionWith(makeBitSet(std.ascii.isControl)),
        .graph  => break :blk range.unionWith(makeBitSet(Ascii.isGraph)),
        .print  => break :blk range.unionWith(makeBitSet(std.ascii.isPrint)),
    };
}


fn getPosixClass(self: *Parser) ParserError!PosixClass {
    std.debug.assert(self.currentEql(.{ .Char = '[' }));
    std.debug.assert(self.peekEql(.{ .Char = ':' }));
    _ = self.advanceN(2);

    var buffer: [256]u8 = .{0} ** 256;
    var it: usize = 0;

    while (true) {
        if (self.currentEql(.Eof))
            return error.UnexpectedEof;
        if (self.currentEql(.{ .Char = ':' }) and self.peekEql(.{ .Char = ']' })) {
            _ = self.advanceN(2);
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

    if (self.currentEql(.Dot)) {
        _ = self.advance();
        return makeNode(self, .{
            .CharClass = .{ .negate = true, .range = makeBitSet(Ascii.dot) }
        });
    }

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
        // std.log.debug("BRACKET: Current: {any}", .{self.current});
        if (self.currentEql(.Eof)) 
            return ParserError.MalformedBracketExp; //NOTE: Shouldn't reach EOF in a bracketExp
        if (self.currentEql(.{ .Char = ']' })) 
            break; //NOTE: g2g
        if (self.currentEql(.{ .Char = '[' }) and self.peekEql(.{ .Char = ':' })) {
            const class: PosixClass = try getPosixClass(self);
            fillRange(&range, class);
            continue;
        }

        if (self.currentEql(.{.Char = '\\'})) {
            const char = getEscaped(self) 
                catch return error.MalformedBracketExp;
            _ = self.advance();
            range.set(char.Char);
            continue;
        }
        
        if (self.peekEql(.{ .Char = '-' })) {
            const rangeStart = self.current.Char;
            _ = self.advanceN(2);
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
    if (!self.currentEql(.{ .Char = ']' }))
        return error.MalformedBracketExp;

    //INFO: Restore Regexp Toknizer state
    self.tokenizer.changeContext(.RegexExpCommon);
    _ = self.advance();

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
    if (!self.peekEql(.Eof))
        return ParserError.AnchorMisuse;
    _ = self.advance();
    return makeNode(self, .{
        .AnchorEnd = left 
    });
}

pub fn makeTrailingContext(self: *Parser, left: *RegexNode) ParserError!*RegexNode {
    if (self.hasSeenTrailingContext)
        return error.TooManyTrailingContexts;

    self.hasSeenTrailingContext = true;
    _ = self.advance();

    return makeNode(self, .{ 
        .TrailingContext = .{
            .left = left,
            .right = try self.parseExpr(.None) 
        }
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

    if (current.eql(.RBrace)) {
        _ = self.advance();
        return makeNode(self, .{ .Repetition = .{ .min = min, .max = min, .left = left }, });
    }

    if (std.meta.activeTag(current) != Token.Char or current.Char != ',') {
        return error.BracesExpUnexpectedChar;
    }

    //NOTE: Current is now ','
    _ = self.advance();

    if (self.current.eql(.RBrace)) {
        _ = self.advance();
        return makeNode(self, .{ .Repetition = .{ .min = min, .max = INFINITY, .left = left }, });
    }

    max = try parseInt(self);
    
    std.debug.assert(self.current.eql(.RBrace));
    _ = self.advance();

    return makeNode(self, .{ .Repetition = .{ .min = min, .max = max, .left = left } });
}


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
