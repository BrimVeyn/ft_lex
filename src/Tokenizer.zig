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
    Comma,
    Eof,

    pub fn eql(lhs: Token, rhs: Token) bool {
        return switch (lhs) {
            .Eof => switch(rhs) {
                .Eof => true,
                else => false,
            },
            .LBrace => switch (rhs) {
                .LBrace => true,
                else => false,
            },
            .LBracket => switch (rhs) {
                .LBracket => true,
                else =>  false,
            },
            .RBracket => switch (rhs) {
                .RBracket => true,
                else => false,
            },
            .Star => switch (rhs) {
                .Star => true,
                else =>  false,
            },
            .Char => switch (rhs) {
                .Char => lhs.Char == rhs.Char,
                else => false,
            },
            else => false,
        };
    }
};

pub const Tokenizer = struct {
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
                ',' => Token.Comma,
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
