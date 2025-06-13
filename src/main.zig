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
const DFADump           = @import("regex/DFADump.zig");
const DFA               = DFAModule.DFA;

const Graph             = @import("regex/Graph.zig");
const EC                = @import("regex/EquivalenceClasses.zig");
const LexParser         = @import("lex/Parser.zig");

const Printer           = @import("lex/Printer/Printer.zig");
const G                 = @import("globals.zig");

comptime {
    _ = @import("test/regex/Tokenizer.zig");
    _ = @import("test/regex/Parser.zig");
    _ = @import("test/regex/NFAs.zig");
    _ = @import("test/lex/Compression.zig");
    _ = @import("test/lex/Comparison.zig");
}

const   BUF_SIZE: usize = 4096;


fn parseOptions(args: [][:0]u8) !usize {
    if (args.len == 1) return 1;

    var arg_it: usize = 1;
    for (args[1..]) |arg| {
        if (arg[0] != '-')
            break;

        const opt = arg[1..];
        for (opt) |ch| {
            switch (ch) {
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


pub fn main() !u8 {

    var gpa: std.heap.DebugAllocator(DebugAllocatorOptions) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const arg_it = parseOptions(args) catch {
        print("Usage: ft_lex [-t] [-n|-v] [file...]\n", .{});
        return 1;
    };
    //We've consumed all options and there's no file
    if (args.len == arg_it) {
        @panic("Not implemented, please provide a file as an argument");
    } else {
        G.options.inputName = args[arg_it];
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
            // std.debug.print("\n\n\n\n\n\n\n\n\nREGEX:\n\n", .{});
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
                switch (e) {
                    error.NFATooComplicated => std.log.err("Maximum NFA states exceeded (>= {d})", .{ G.options.maxSizeDFA }),
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

        for (DFAs.items, mergedNFAs.items, 0..) |dfa, nfa, i| {
            const filename = try std.fmt.allocPrint(alloc, "test_{d}.graph", .{i});
            defer alloc.free(filename);

            const outFile = try std.fs.cwd().createFile(filename, .{});
            defer outFile.close();
            Graph.dotFormat(lexParser, nfa.nfa, dfa.dfa, &ec.yy_ec, outFile.writer());
        }

        const outFile = try std.fs.cwd().createFile("test_g.graph", .{});
        defer outFile.close();
        Graph.dotFormat(lexParser, mergedNFAs.items[0].nfa, finalDfa, &ec.yy_ec, outFile.writer());

        // std.debug.print("UNCOMPRESSED\n", .{});
        // DFADump.transTableDump(finalDfa.transTable.?);
        std.log.info("Compressed eql: {}", .{ try finalDfa.compareTTToCTT() });

        if (G.options.compressed) {
            const compressedSize = (finalDfa.cTransTable.?.base.len * 2) + (finalDfa.cTransTable.?.next.len * 2);
            if (compressedSize >= G.options.maxSizeDFA) {
                std.log.err("Maximum output size exceeded: max: {d}, actual: {d}", .{G.options.maxSizeDFA, compressedSize});
                return 1;
            }
            std.log.info("Compressed size: {d}", .{compressedSize});
        } else {
            const uncompressedSize = finalDfa.transTable.?.items.len * ec.maxEc;
            if (uncompressedSize >= G.options.maxSizeDFA) {
                std.log.err("Maximum output size exceeded: max: {d}, actual: {d}", .{G.options.maxSizeDFA, uncompressedSize});
                return 1;
            }
            std.log.info("Uncompressed size: {d}", .{uncompressedSize});
        }

        try Printer.print(
            ec, DFAs,
            bol_DFAs, tc_DFAs, finalDfa,
            lexParser
        );
    }
    return 0;
}

// test "dummy" {
//     try std.testing.expect(1 == 1);
// }
