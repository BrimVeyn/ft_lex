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
const RegexParser            = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;

const NFAModule         = @import("regex/NFA.zig");
const NFA               = NFAModule.NFA;

const DFAModule         = @import("regex/DFA.zig");
const DFA               = DFAModule.DFA;

const Graph             = @import("regex/Graph.zig");
const EC                = @import("regex/EquivalenceClasses.zig");
const LexParser         = @import("lex/Parser.zig");

comptime {
    _ = @import("test/regex/Tokenizer.zig");
    _ = @import("test/regex/Parser.zig");
    _ = @import("test/regex/NFAs.zig");
    _ = @import("test/lex/Parser.zig");
}

pub fn interactiveMode(alloc: std.mem.Allocator) !void {

    var stdinReader = stdin.reader();
    var buf: [BUF_SIZE:0]u8 = .{0} ** BUF_SIZE;

    print("Enter any regex to see its representation: \n", .{});
    while (true) {
        @memset(buf[0..], 0);
        _ = stdinReader.readUntilDelimiterOrEof(&buf, '\n') catch |e| {
            log.err("BUF_SIZE: {d} exceeded: {!}", .{BUF_SIZE, e});
        };

        if (std.mem.indexOfSentinel(u8, 0, buf[0..]) == 0) {
            break;
        }

        const regex = std.mem.trimRight(u8, buf[0..], "\n\x00");

        //Init parser
        var parser = try RegexParser.initWithSlice(alloc, regex);
        defer parser.deinit();

        //Parser expr
        const head = parser.parse() catch |e| {
            std.log.err("Parser: {!}", .{e});
            continue;
        };

        //Debug print
        // head.dump(0);
        // for (parser.classSet.keys(), 0..) |k, i| {
        //     std.debug.print("set[{d}]: {}\n", .{i, k});
        // }

        const yy_ec_highest = try EC.buildEquivalenceTable(alloc, parser.classSet, &yy_ec);

        //Init nfa builder
        var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &parser, &yy_ec);
        defer nfaBuilder.deinit();

        //Build nfa
        const nfa = nfaBuilder.astToNfa(head) catch |e| {
            std.log.err("NFA: {!}", .{e});
            continue;
        };
        // std.debug.print("{s}", .{try nfa.stringify(alloc)});

        var accept_list = std.ArrayList(DFA.AcceptState).init(alloc);
        defer accept_list.deinit();
        try accept_list.append(.{ .state = nfa.accept, .priority = 0 });

        // Init dfa builder
        var dfa = DFA.init(alloc, nfa, accept_list, yy_ec_highest);
        defer dfa.deinit();

        //Build dfa from nfa
        try dfa.subset_construction();

        // std.debug.print("{s}", .{try dfa.stringify(alloc)});

        // Graph.dotFormat(regex, nfa, dfa, &yy_ec);
    }
}


const   BUF_SIZE: usize = 4096;
var     yy_ec: [256]u8  = .{0} ** 256;

const LexOptions = struct {
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
    // defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const options, const arg_it = parseOptions(args) catch {
        print("Usage: ft_lex [-t] [-n|-v] [file...]\n", .{});
        return 1;
    };
    _ = options;

    //We've consumed all options and there's no file
    if (args.len == arg_it) {
        try interactiveMode(alloc);
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
            const head = regexParser.parse() catch |e| {
                std.log.err("\"{s}\": {!}", .{rule.regex, e});
                return 1;
            };
            try headList.append(head);
        }

        const yy_ec_highest = try EC.buildEquivalenceTable(alloc, regexParser.classSet, &yy_ec);

        var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &regexParser, &yy_ec);
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

        const unifiedNfa, const acceptList = try nfaBuilder.merge(nfaList.items);
        defer acceptList.deinit();

        var dfa = DFA.init(alloc, unifiedNfa, acceptList, yy_ec_highest);
        defer dfa.deinit();

        try dfa.subset_construction();
        try dfa.minimize();
        try dfa.compress();

        std.debug.print("yy_ec: {d}", .{yy_ec});

        const outFile = try std.fs.cwd().createFile("test.graph", .{});
        Graph.dotFormat(lexParser, unifiedNfa, dfa, &yy_ec, outFile.writer());
    }
    return 0;
}

test "dummy" {
    try std.testing.expect(1 == 1);
}
