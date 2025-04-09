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

    pub fn toUsize(self: Token) usize {
        return @intFromEnum(self);
    }
};


pub const Tokenizer = struct {
    pub const TokenCount = @typeInfo(Token).@"union".fields.len;

    input: []const u8,
    index: usize,

    pub fn init(input: []const u8) Tokenizer {
        return .{ .input = input, .index = 0 };
    }

    pub fn next(self: *Tokenizer) Token {
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

    pub fn peak(self: *Tokenizer) Token {
        const savedIdx = self.index;
        const ret = self.next();
        self.index = savedIdx;
        return ret;
    }
};
