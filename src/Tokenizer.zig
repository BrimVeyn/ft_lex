const std = @import("std");

pub const Token = union(enum) {
    Char: u8,
    Escape,
    TrailingContext,
    AnchorStart,
    AnchorEnd,
    Star,
    Plus,
    Question,
    LParen,
    RParen,
    Union,
    Dot,
    LBracket,
    RBracket,
    LBrace,
    RBrace,
    StartConditionOpen,
    Quote,
    Eof,

    pub fn eql(lhs: Token, rhs: Token) bool {
        const lhsType = @intFromEnum(lhs);
        const rhsType = @intFromEnum(rhs);

        if (lhsType != rhsType) 
            return false;
        
        if (lhsType == @intFromEnum(Token.Char) and lhs.Char != rhs.Char) 
            return false;

        return true;
    }
};

pub const PosixClass = enum {
    upper,
    lower,
    alpha,
    digit,
    xdigit,
    alnum,
    punct,
    blank,
    space,
    cntrl,
    graph,
    print
};

pub const Tokenizer = struct {
    input: []const u8,
    index: usize,
    nextFn: *const fn (self: *Tokenizer) Token,

    pub const TokenizerCtx = enum {
        BracketExp,
        RegexExpStart,
        RegexExpCommon,
    };

    pub const TokenCount = @typeInfo(Token).@"union".fields.len;

    pub fn init(input: []const u8, ctx: TokenizerCtx) Tokenizer {
        return .{ 
            .input = input,
            .index = 0,
            .nextFn = switch (ctx) {
                .BracketExp => &nextBracketExp,
                .RegexExpCommon => &nextRegexExp,
                .RegexExpStart => &nextRegexExpStart,
            },
        };
    }

    pub fn changeContext(self: *Tokenizer, ctx: TokenizerCtx) void {
        switch (ctx) {
            .BracketExp => self.nextFn = &nextBracketExp,
            .RegexExpCommon => self.nextFn = &nextRegexExp,
            .RegexExpStart => self.nextFn = &nextRegexExpStart,
        }
    }

    pub fn next(self: *Tokenizer) Token {
        return self.nextFn(self);
    }

    pub fn nextRegexExp(self: *Tokenizer) Token {
        while (self.index < self.input.len) {
            const c = self.input[self.index];
            self.index += 1;

            return switch (c) {
                '\\' => Token.Escape,
                '"' => Token.Quote,
                '.' => Token.Dot,
                '*' => Token.Star,
                '+' => Token.Plus,
                '?' => Token.Question,
                '(' => Token.LParen,
                ')' => Token.RParen,
                '[' => Token.LBracket,
                ']' => Token.RBracket,
                '{' => Token.LBrace,
                '}' => Token.RBrace,
                '^' => Token.AnchorStart,
                '$' => Token.AnchorEnd,
                '|' => Token.Union,
                '/' => Token.TrailingContext,
                else => Token{ .Char = c },
            };
        }
        return Token.Eof;
    }

    //Angle bracket is considered literal except if it's the first character of the line
    pub fn nextRegexExpStart(self: *Tokenizer) Token {
        while (self.index < self.input.len) {
            const c = self.input[self.index];
            self.index += 1;

            return switch (c) {
                '<' => Token.StartConditionOpen,
                else => {
                    //Switch context back to regular Regex and return generated token, 
                    //go back one character that'll be eaten by the other next fn
                    self.index -= 1;
                    self.changeContext(.RegexExpCommon);
                    return self.next();
                },
            };
        }
        return Token.Eof;
    }

    //Remove special meaning of all meta chars
    pub fn nextBracketExp(self: *Tokenizer) Token {
        while (self.index < self.input.len) {
            const c = self.input[self.index];
            self.index += 1;
            return Token { .Char = c};
        }
        return Token.Eof;
    }

    pub fn peak(self: *Tokenizer) Token {
        const savedIdx = self.index;
        const ret = self.next();
        self.index = savedIdx;
        return ret;
    }
};
