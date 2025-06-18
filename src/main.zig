const std                = @import("std");
const stdin              = std.io.getStdIn();
const print              = std.debug.print;
const log                = std.log;
const Allocator          = std.mem.Allocator;
const ArrayList          = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const TokenizerModule    = @import("regex/Tokenizer.zig");
const Tokenizer          = TokenizerModule.Tokenizer;
const Token              = TokenizerModule.Token;

const ParserModule       = @import("regex/Parser.zig");
const RegexParser        = ParserModule.Parser;
const RegexNode          = ParserModule.RegexNode;

const NFAModule          = @import("regex/NFA.zig");
const NFA                = NFAModule.NFA;

const DFAModule          = @import("regex/DFA.zig");
const DFADump            = @import("regex/DFA_Dump.zig");
const DFA                = DFAModule.DFA;

const Graph              = @import("regex/Graph.zig");
const EC                 = @import("regex/EquivalenceClasses.zig");
const LexParser          = @import("lex/Parser.zig");

const Printer            = @import("lex/Printer/Printer.zig");
const G                  = @import("globals.zig");

comptime {
    _ = @import("test/regex/Tokenizer.zig");
    _ = @import("test/regex/Parser.zig");
    _ = @import("test/regex/NFAs.zig");
    _ = @import("test/lex/Compression.zig");
    _ = @import("test/lex/Comparison.zig");
}

const   BUF_SIZE: usize = 4096;

fn printHelp() void {
    const usage =
    \\Usage: ft_lex [OPTIONS] [FILE]
    \\Generates programs that perform pattern-matching on text.
    \\
    \\Options:
    \\  -f => generate a fast version of the scanner. (default is compressed)
    \\  -z => scanner is generated in Zig. (default is C)
    \\  -t => outputs scanner on stdout. (default is ft_lex.yy.(c|zig))
    \\  -n => don't print statistics. (default behavior)
    \\  -v => print statistics. (off by default)
    \\  -g => outputs graphs to visualize the generate NFAs/DFAs.
    \\
    \\
    ;
    std.debug.print(usage, .{});

}

fn parseOptions(args: [][:0]u8) !usize {
    if (args.len == 1) return 1;

    var arg_it: usize = 1;

    if (std.mem.eql(u8, args[1], "--help")) {
        printHelp();
        return error.NeedHelp;
    }

    for (args[1..]) |arg| {
        if (arg[0] != '-')
            break;

        const opt = arg[1..];
        for (opt) |ch| {
            switch (ch) {
                'g' => G.options.graph = true,
                't' => G.options.t = true,
                'n' => G.options.n = true,
                'v' => G.options.v = true,
                'z' => G.options.zig = true,
                'f' => G.options.fast = true,
                else => {
                    print("ft_lex: Unrecognized option `{s}'\n", .{opt});
                    return error.UnrecognizedOption;
                }
            }
        }
        arg_it += 1;
    }
    return arg_it;
}

const DebugAllocatorOptions: std.heap.DebugAllocatorConfig = .{
    .stack_trace_frames = 15,
    .retain_metadata = true,
    // .verbose_log = true,
    // .thread_safe = true,
};

fn emitGraphs(
    alloc: Allocator,
    lexParser: LexParser,
    DFAs: ArrayListUnmanaged(DFA.DFA_SC),
    mergedNFAs: ArrayList(NFAModule.NFABuilder.DFAFragment),
    finalDfa: DFA,
    ec: EC
) !void {
    try std.fs.cwd().makeDir("graphs");

    for (DFAs.items, mergedNFAs.items, 0..) |dfa, nfa, i| {
        const filename = try std.fmt.allocPrint(alloc, "graphs/test_{d}.graph", .{i});
        defer alloc.free(filename);

        const outFile = try std.fs.cwd().createFile(filename, .{});
        defer outFile.close();
        Graph.dotFormat(lexParser, nfa.nfa, dfa.dfa, &ec.yy_ec, outFile.writer());
    }

    const outFile = try std.fs.cwd().createFile("graphs/test_g.graph", .{});
    defer outFile.close();
    Graph.dotFormat(lexParser, mergedNFAs.items[0].nfa, finalDfa, &ec.yy_ec, outFile.writer());
}

fn checkDFAsize(finalDfa: DFA) !void {
    if (G.options.fast) {
        const uncompressedSize = finalDfa.transTable.?.data.items[0].items.len * finalDfa.transTable.?.data.items.len;
        if (uncompressedSize >= G.options.maxSizeDFA) {
            std.log.err("Maximum dfa table entries exceeded: max: {d}, actual: {d}", .{G.options.maxSizeDFA, uncompressedSize});
            return error.DFASizeExceeded;
        }
    } else {
        const compressedSize = (finalDfa.cTransTable.?.base.len * 2) + (finalDfa.cTransTable.?.next.len * 2);
        if (compressedSize >= G.options.maxSizeDFA) {
            std.log.err("Maximum dfa table entries exceeded: max: {d}, actual: {d}", .{G.options.maxSizeDFA, compressedSize});
            return error.DFASizeExceeded;
        }
    }
}

fn run(alloc: Allocator, filename: ?[]u8) !u8 {
    var lexParser = try LexParser.init(alloc, filename);
    defer lexParser.deinit();

    lexParser.parse() catch { return 1; };

    var regexParser = try RegexParser.init(alloc);
    defer regexParser.deinit();

    var headList = ArrayList(*RegexNode).init(alloc);
    defer headList.deinit();

    for (lexParser.rules.items) |rule| {
        regexParser.loadSlice(rule.regex);
        const head = regexParser.parse() catch |e| {
            std.log.err("\"{s}\": {!}", .{rule.regex, e});
            return 1;
        };
        try headList.append(head);
    }

    const ec = try EC.buildEquivalenceTable(alloc, regexParser.classSet);

    var nfaBuilder = try NFAModule.NFABuilder.init(alloc, &regexParser, &ec.yy_ec);
    defer nfaBuilder.deinit();

    var nfaList = std.ArrayList(NFA).init(alloc);
    defer nfaList.deinit();

    for (headList.items) |head| {
        const nfa = nfaBuilder.astToNfa(head) catch |e| {
            switch (e) {
                error.NFATooComplicated => std.log.err("Maximum NFA states exceeded (>= {d})", .{ G.options.maxStates }),
                else => {},
            }
            return 1;
        };
        try nfaList.append(nfa);
    }

    const mergedNFAs, const bolMergedNFAs, const tcNFAs = try nfaBuilder.merge(nfaList.items, lexParser);
    defer {
        for (mergedNFAs.items) |m| alloc.free(m.acceptList);
        for (bolMergedNFAs.items) |m| alloc.free(m.acceptList);
        for (tcNFAs.items) |m| alloc.free(m.acceptList);
        mergedNFAs.deinit(); bolMergedNFAs.deinit(); tcNFAs.deinit();
    }

    var finalDfa, var DFAs, var bol_DFAs, var tc_DFAs = 
    try DFA.buildAndMergeFromNFAs(alloc, &lexParser, mergedNFAs, bolMergedNFAs, tcNFAs, ec);

    defer {
        for (DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        for (bol_DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        for (tc_DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        DFAs.deinit(alloc); bol_DFAs.deinit(alloc); tc_DFAs.deinit(alloc);
        finalDfa.mergedDeinit();
    }

    if (G.options.graph)
        try emitGraphs(alloc, lexParser, DFAs, mergedNFAs, finalDfa, ec);

    checkDFAsize(finalDfa) catch { return 1; };

    try Printer.print(ec, DFAs, bol_DFAs, tc_DFAs, finalDfa, lexParser);

    return 0;
}


pub fn main() !u8 {
    var gpa: std.heap.DebugAllocator(DebugAllocatorOptions) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const arg_it = parseOptions(args) catch |e| switch (e) {
        error.UnrecognizedOption => { print("Usage: ft_lex [-t] [-n|-v] [file...]\n", .{}); return 1; },
        error.NeedHelp => return 0,
    };

    if (args.len == arg_it) {
        return try run(alloc, null);
    } else {
        G.options.inputName = args[arg_it];
        return try run(alloc, args[arg_it]);
    }
    unreachable;
}
