const std               = @import("std");

const ParserModule      = @import("../../regex/Parser.zig");
const Parser            = ParserModule.Parser;
const ParserError       = ParserModule.ParserError;
const RegexNode         = ParserModule.RegexNode;
const INFINITY          = ParserModule.INFINITY;

const Makers            = @import("../../regex/ParserMakers.zig");

fn parseAll(alloc: std.mem.Allocator, input: []const u8) !struct {Parser, *RegexNode} {
    var parser = try Parser.initWithSlice(alloc, input);

    const head = parser.parse() catch |e| {
        std.log.err("Parser: {!}", .{e});
        return e;
    };
    return .{parser, head};
}

fn makeEC(parser: *Parser, n: bool, str: []const u8) !*RegexNode {
    var ret = std.StaticBitSet(256).initEmpty();
    for (str) |c| {
        ret.set(c);
    }
    return Makers.makeNode(parser, .{.CharClass = .{ .negate = n, .range = ret }});
}

fn makeChar(parser: *Parser, c: u8) !*RegexNode {
    return try Makers.makeNode(parser, .{ .Char = c });
}

fn fillNameBuf(name: []const u8) [64:0]u8 {
    var buf: [64:0]u8 = .{0} ** 64;
    for (name, 0..) |c, i| {
        buf[i] = c;
    }
    return buf;
}

test "Simple concat test" {
    var parser, const head = try parseAll(std.testing.allocator, "ab");
    defer parser.deinit();

    const expect = try Makers.makeNode(&parser, .{
        .Concat = .{
            .left = try makeEC(&parser, false, "a"),
            .right = try makeEC(&parser, false, "b"),
        }
    });

    try std.testing.expectEqualDeep(head, expect);
}


test "Concat simple" {
    var parser, const head = try parseAll(std.testing.allocator, "ab");
    defer parser.deinit();

    const expect = try Makers.makeNode(&parser, .{
        .Concat = .{
            .left = try makeEC(&parser, false, "a"),
            .right = try makeEC(&parser, false, "b"),
        },
    });

    try std.testing.expectEqualDeep(head, expect);
}

test "Simple repetition *" {
    var parser, const head = try parseAll(std.testing.allocator, "a*");
    defer parser.deinit();

    const expect = try Makers.makeNode(&parser, .{
        .Repetition = .{
            .min = 0,
            .max = INFINITY,
            .left = try makeEC(&parser, false, "a"),
        },
    });

    try std.testing.expectEqualDeep(head, expect);
}

test "Simple repetitions +, ? and {m, n}" {
    // a+ equivalent to min=1 max=null
    {
        var parser, const head = try parseAll(std.testing.allocator, "a+");
        defer parser.deinit();
        const expect = try Makers.makeNode(&parser, .{
            .Repetition = .{ .min = 1, .max = INFINITY, .left = try makeEC(&parser, false, "a") },
        });
        try std.testing.expectEqualDeep(head, expect);
    }

    // a? equivalent to min=0 max=1
    {
        var parser, const head = try parseAll(std.testing.allocator, "a?");
        defer parser.deinit();
        const expect = try Makers.makeNode(&parser, .{
            .Repetition = .{ .min = 0, .max = 1, .left = try makeEC(&parser, false, "a") },
        });
        try std.testing.expectEqualDeep(head, expect);
    }

    // a{1, 10} equivalent to min=1 max=10
    {
        var parser, const head = try parseAll(std.testing.allocator, "a{1,10}");
        defer parser.deinit();
        const expect = try Makers.makeNode(&parser, .{
            .Repetition = .{ .min = 1, .max = 10, .left = try makeEC(&parser, false, "a") },
        });
        try std.testing.expectEqualDeep(head, expect);
    }

    // a{2} equivalent to min=2 max=2
    {
        var parser, const head = try parseAll(std.testing.allocator, "a{2}");
        defer parser.deinit();
        const expect = try Makers.makeNode(&parser, .{
            .Repetition = .{ .min = 2, .max = 2, .left = try makeEC(&parser, false, "a") },
        });
        try std.testing.expectEqualDeep(head, expect);
    }

    // a{2,} equivalent to min=2 max=INFINITY
    {
        var parser, const head = try parseAll(std.testing.allocator, "a{2,}");
        defer parser.deinit();
        const expect = try Makers.makeNode(&parser, .{
            .Repetition = .{ .min = 2, .max = INFINITY, .left = try makeEC(&parser, false, "a") },
        });
        try std.testing.expectEqualDeep(head, expect);
    }
}

test "Alternation" {
    var parser, const head = try parseAll(std.testing.allocator, "a|b");
    defer parser.deinit();

    const expect = try Makers.makeNode(&parser, .{
        .Alternation = .{
            .left = try makeEC(&parser, false, "a"),
            .right = try makeEC(&parser, false, "b"),
        },
    });

    try std.testing.expectEqualDeep(head, expect);
}

test "Grouping and concatenation" {
    var parser, const head = try parseAll(std.testing.allocator, "(ab)c");
    defer parser.deinit();

    const group = try Makers.makeNode(&parser, .{
        .Group = try Makers.makeNode(&parser, .{
            .Concat = .{
                .left = try makeEC(&parser, false, "a"),
                .right = try makeEC(&parser, false, "b"),
            },
        }),
    });

    const expect = try Makers.makeNode(&parser, .{
        .Concat = .{
            .left = group,
            .right = try makeEC(&parser, false, "c"),
        },
    });

    try std.testing.expectEqualDeep(head, expect);
}

// test "Anchors" {
//     var parser, const head = try parseAll(std.testing.allocator, "^abc$");
//     defer parser.deinit();
//
//     const abc = try Makers.makeNode(&parser, .{
//         .Concat = .{
//             .left = try makeEC(&parser, false, "a"),
//             .right = try Makers.makeNode(&parser, .{
//                 .Concat = .{
//                     .left = try makeEC(&parser, false, "b"),
//                     .right = try makeEC(&parser, false, "c"),
//                 },
//             }),
//         },
//     });
//
//     const anchored = try Makers.makeNode(&parser, .{
//         .AnchorStart = try Makers.makeNode(&parser, .{
//             .AnchorEnd = abc,
//         }),
//     });
//
//     try std.testing.expectEqualDeep(head, anchored);
// }

test "CharClass simple" {
    var parser, const head = try parseAll(std.testing.allocator, "[abc]");
    defer parser.deinit();

    var range = std.StaticBitSet(256).initEmpty();
    range.setValue('a', true);
    range.setValue('b', true);
    range.setValue('c', true);

    const expect = try Makers.makeNode(&parser, .{
        .CharClass = .{
            .negate = false,
            .range = range,
        },
    });

    try std.testing.expectEqualDeep(head, expect);
}

test "Trailing context" {
    var parser, const head = try parseAll(std.testing.allocator, "ab/cd");
    defer parser.deinit();

    const expect = try Makers.makeNode(&parser, .{
        .TrailingContext = .{
            .left = try Makers.makeNode(&parser, .{
                .Concat = .{
                    .left = try makeEC(&parser, false, "a"),
                    .right = try makeEC(&parser, false, "b"),
                },
            }),
            .right = try Makers.makeNode(&parser, .{
                .Concat = .{
                    .left = try makeEC(&parser, false, "c"),
                    .right = try makeEC(&parser, false, "d"),
                },
            }),
        },
    });

    try std.testing.expectEqualDeep(head, expect);
}

test "Escape sequences: simple characters" {
    var parser, const head = try parseAll(std.testing.allocator, "\\n\\r\\t\\\\");
    defer parser.deinit();

    const expected = try Makers.makeNode(&parser, .{
        .Concat = .{
            .left = try makeEC(&parser, false, "\n"),
            .right = try Makers.makeNode(&parser, .{
                .Concat = .{ 
                    .left = try makeEC(&parser, false, "\r"),
                    .right = try Makers.makeNode(&parser, .{
                        .Concat = .{ 
                            .left = try makeEC(&parser, false, "\t"),
                            .right = try  makeEC(&parser, false, "\\"),
                        }
                    })
                }
            })
        },
    });

    try std.testing.expectEqualDeep(head, expected);
}

test "Escape sequences: hex values" {
    var parser, const head = try parseAll(std.testing.allocator, "\\x41\\x42");
    defer parser.deinit();

    const expected = try Makers.makeNode(&parser, .{
        .Concat = .{
            .left = try makeEC(&parser, false, "\x41"),
            .right = try makeEC(&parser, false, "\x42"),
        },
    });

    try std.testing.expectEqualDeep(head, expected);
}

test "Escape sequences: octal values" {
    var parser, const head = try parseAll(std.testing.allocator, "\\101\\102");
    defer parser.deinit();

    const expected = try Makers.makeNode(&parser, .{
        .Concat = .{
            .left = try makeEC(&parser, false, "\x41"),
            .right = try makeEC(&parser, false, "\x42"),
        },
    });

    try std.testing.expectEqualDeep(head, expected);
}

test "Escape sequences: all known including hex, octal, and literals" {
    const Pair = struct {
        []const u8,
        u8,
    };

    const escapes = [_]Pair{
        .{ "\\n", '\n' },
        .{ "\\r", '\r' },
        .{ "\\t", '\t' },
        .{ "\\f", '\x0C' },
        .{ "\\a", '\x07' },
        .{ "\\v", '\x0B' },
        .{ "\\b", '\x08' },
        .{ "\\\\", '\\' },
        .{ "\\4", 0x04 },

        // Hexadecimal escape
        .{ "\\x41", 'A' },
        .{ "\\x7A", 'z' },

        // Octal escape
        .{ "\\101", 'A' },
        .{ "\\172", 'z' },

        // Literal characters escaped
        .{ "\\[", '[' },
        .{ "\\]", ']' },
        .{ "\\(", '(' },
        .{ "\\)", ')' },
        .{ "\\*", '*' },
        .{ "\\+", '+' },
        .{ "\\?", '?' },
        .{ "\\.", '.' },
        .{ "\\|", '|' },
        .{ "\\^", '^' },
        .{ "\\$", '$' },
    };

    for (escapes) |pair| {
        const str = pair[0];
        const expected_char = pair[1];

        var parser, const head = try parseAll(std.testing.allocator, str);
        defer parser.deinit();

        const expected = try makeEC(&parser, false, &[_]u8{expected_char});
        try std.testing.expectEqualDeep(head, expected);
    }
}

test "Parser errors" {
    const Pair = struct {
        []const u8,
        ParserError,
    };

    const escapes = [_]Pair{
        .{ "a^", ParserError.PrefixUnexpected },
        .{ "abc/def/efg", ParserError.TooManyTrailingContexts },
        .{ "a}ab", ParserError.UnexpectedRightBrace },
        .{ "a)bc", ParserError.UnbalancedParenthesis },
        .{ "(abc", ParserError.UnbalancedParenthesis },
        .{ "*ab", ParserError.UnexpectedPostfixOperator },
        .{ "+ab", ParserError.UnexpectedPostfixOperator },
        .{ "?ab", ParserError.UnexpectedPostfixOperator },
        .{ "ab[a-z", ParserError.MalformedBracketExp },
        .{ "[[:unknown:]]", ParserError.BracketExpInvalidPosixClass },
        .{ "[z-a]*", ParserError.BracketExpOutOfOrder },
        .{ "\\[abc]", ParserError.UnexpectedRightBracket },
        .{ "|ab", ParserError.PrefixUnexpected },
        .{ "/abc", ParserError.UnexpectedPostfixOperator },
        .{ "", ParserError.UnexpectedEof },
    };

    for (escapes) |pair| {
        const str = pair[0];
        const expected_error = pair[1];
        var parser = try Parser.initWithSlice(std.testing.allocator, str);
        defer parser.deinit();

        const real_error = parser.parse();

        try std.testing.expectError(expected_error, real_error);
    }
}

test "Quoting" {
    var parser, const head = try parseAll(std.testing.allocator, "\"abc\"*");
    defer parser.deinit();

    const expected = try Makers.makeNode(&parser, .{
        .Repetition = .{ 
            .min = 0, .max = INFINITY,
            .left = try Makers.makeNode(&parser, .{
                .Group = try Makers.makeNode(&parser, .{
                    .Concat = .{
                        .left = try makeEC(&parser, false, "a"),
                        .right = try Makers.makeNode(&parser, .{
                            .Concat = .{
                                .left = try makeEC(&parser, false, "b"),
                                .right = try makeEC(&parser, false, "c"),
                            }
                        })
                    }
                })
            })
        }
    });

    try std.testing.expectEqualDeep(head, expected);
}
