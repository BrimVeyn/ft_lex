const std = @import("std");

pub const Token = union(enum) {
    Char: u8,
    Star,
    Plus,
    Question,
    LParen,
    RParen,
    Union,
    AnchorStart,
    AnchorEnd,
    Dot,
    Escape,
    LBracket,
    RBracket,
    LBrace,
    RBrace,
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
        RegexExp,
    };

    pub const TokenCount = @typeInfo(Token).@"union".fields.len;

    pub fn init(input: []const u8) Tokenizer {
        return .{ 
            .input = input,
            .index = 0,
            .nextFn = &nextRegexExp,
        };
    }

    pub fn changeContext(self: *Tokenizer, ctx: TokenizerCtx) void {
        switch (ctx) {
            .BracketExp => self.nextFn = &nextBracketExp,
            .RegexExp => self.nextFn = &nextRegexExp,
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
                else => Token{ .Char = c },
            };
        }
        return Token.Eof;
    }

    pub fn nextBracketExp(self: *Tokenizer) Token {
        while (self.index < self.input.len) {
            const c = self.input[self.index];
            self.index += 1;

            return switch(c) {
                '\\' => Token.Escape,
                else => Token { .Char = c},
            };
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
