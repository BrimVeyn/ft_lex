const std               = @import("std");
const stdin             = std.io.getStdIn();
const print             = std.debug.print;
const log               = std.log;
const Allocator         = std.mem.Allocator;
const VectU             = std.ArrayListUnmanaged;
const Vect              = std.ArrayList;

const TokenizerModule   = @import("regex/Tokenizer.zig");
const Tokenizer         = TokenizerModule.Tokenizer;
const Token             = TokenizerModule.Token;

const ParserModule      = @import("regex/Parser.zig");
const RegexParser       = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;

const NFAModule         = @import("regex/NFA.zig");
const NFA               = NFAModule.NFA;

const DFAModule         = @import("regex/DFA.zig");
const DFA               = DFAModule.DFA;

const Graph             = @import("regex/Graph.zig");
const EC                = @import("regex/EquivalenceClasses.zig");
const LexParser         = @import("lex/Parser.zig");

const Printer           = @import("lex/Printer.zig");

comptime {
    _ = @import("test/regex/Tokenizer.zig");
    _ = @import("test/regex/Parser.zig");
    _ = @import("test/regex/NFAs.zig");
    _ = @import("test/lex/Parser.zig");
}

const   BUF_SIZE: usize = 4096;

pub const LexOptions = struct {
    t: bool = false,
    n: bool = false,
    v: bool = false,
};

fn parseOptions(args: [][:0]u8) !struct {LexOptions, usize} {
    var opts = LexOptions{};
    if (args.len == 1) {
        return .{opts, 1};
    }

    var arg_it: usize = 1;
    for (args[1..]) |arg| {
        if (arg[0] != '-')
            break;

        const opt = arg[1..];
        for (opt) |ch| {
            switch (ch) {
                't' => opts.t = true,
                'n' => opts.n = true,
                'v' => opts.v = true,
                else => {
                    print("ft_lex: Unrecognized option `{s}'\n", .{opt});
                    return error.UnrecognizedOption;
                }
            }
        }
        arg_it += 1;
    }
    return .{opts, arg_it};
}

const DebugAllocatorOptions: std.heap.DebugAllocatorConfig = .{
    .stack_trace_frames = 15,
    .retain_metadata = true,
    // .verbose_log = true,
    .thread_safe = true,
};

pub fn main() !u8 {
    var gpa: std.heap.DebugAllocator(DebugAllocatorOptions) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const options, const arg_it = parseOptions(args) catch {
        print("Usage: ft_lex [-t] [-n|-v] [file...]\n", .{});
        return 1;
    };
    //We've consumed all options and there's no file
    if (args.len == arg_it) {
        @panic("Not yet implemtented");
    } else {
        var lexParser = try LexParser.init(alloc, args[arg_it]);
        defer lexParser.deinit();

        lexParser.parse() catch {
            // std.log.err("{!}", .{e});
            return 1;
        };
        var regexParser = try RegexParser.init(alloc);
        defer regexParser.deinit();

        var headList = std.ArrayList(*RegexNode).init(alloc);
        defer headList.deinit();

        for (lexParser.rules.items) |rule| {
            regexParser.loadSlice(rule.regex);
            // std.debug.print("Parsing regex: {s}", .{rule.regex});
            const head = regexParser.parse() catch |e| {
                std.log.err("\"{s}\": {!}", .{rule.regex, e});
                return 1;
            };
            // head.dump(0);
            try headList.append(head);
        }

        const ec = try EC.buildEquivalenceTable(alloc, regexParser.classSet);

        var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &regexParser, &ec.yy_ec);
        defer nfaBuilder.deinit();

        var nfaList = std.ArrayList(NFA).init(alloc);
        defer nfaList.deinit();

        for (headList.items) |head| {
            const nfa = nfaBuilder.astToNfa(head) catch |e| {
                std.log.err("NFA: {!}", .{e});
                continue;
            };
            try nfaList.append(nfa);
        }

        const unifiedNfa, const acceptList = try nfaBuilder.merge(nfaList.items, lexParser);
        defer acceptList.deinit();

        var dfa = DFA.init(alloc, unifiedNfa, acceptList, ec.maxEc);
        defer dfa.deinit();

        try dfa.subset_construction();
        try dfa.minimize();
        try dfa.compress();

        // std.debug.print("yy_ec: {d}\n", .{yy_ec});

        const outFile = try std.fs.cwd().createFile("test.graph", .{});
        Graph.dotFormat(lexParser, unifiedNfa, dfa, &ec.yy_ec, outFile.writer());

        std.log.info("Compressed eql: {}\n", .{ try dfa.compareTTToCTT() });
        try Printer.print(ec, dfa, lexParser, options);

    }
    return 0;
}

test "dummy" {
    try std.testing.expect(1 == 1);
}
