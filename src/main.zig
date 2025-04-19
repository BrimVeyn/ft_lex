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
const Parser            = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;

const NFAModule         = @import("regex/NFA.zig");
const NFA               = NFAModule.NFA;

const DFAModule         = @import("regex/DFA.zig");
const DFA               = DFAModule.DFA;

const Graph             = @import("regex/Graph.zig");
const EC                = @import("regex/EquivalenceClasses.zig");

comptime {
    _ = @import("test/Tokenizer.zig");
    _ = @import("test/Parser.zig");
    _ = @import("test/NFAs.zig");
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
        var parser = try Parser.init(alloc, regex);
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

        // Init dfa builder
        var dfa = DFA.init(alloc, nfa, yy_ec_highest);
        defer dfa.deinit();

        //Build dfa from nfa
        try dfa.subset_construction();

        // std.debug.print("{s}", .{try dfa.stringify(alloc)});

        Graph.dotFormat(regex, nfa, dfa, &yy_ec);
    }
}


const   BUF_SIZE: usize = 4096;
var     yy_ec: [256]u8  = .{0} ** 256;

const LexOptions = struct {
    t: bool = false,
    n: bool = false,
    v: bool = false,
};

const FileParser = struct {
    const FileSections = struct {
        raw: [][]const u8,
        definitions: ?[][]const u8 = null, 
        rules: [][]const u8 = undefined,
        userSubroutines: ?[][]const u8 = null,
    };

    pub fn getDefinitionSection(lines: [][]const u8) !struct {?[][]const u8, usize} {
        if (std.mem.eql(u8, lines[0][0..1], "%%")) 
            return .{null, 1};

        for (lines, 0..) |line, i| {
            if (std.mem.eql(u8, line[0..1], "%%"))
                return .{lines[0..i], i};
        }
        return error.UnexpectedEof;
    }

    pub fn parseContent(alloc: std.mem.Allocator, rawContent: []u8) !FileSections {
        const lines = blk: {
            var arr = std.ArrayList([]const u8).init(alloc);
            defer arr.deinit();
            var lines = std.mem.tokenizeScalar(u8, rawContent, '\n');
            while (lines.next()) |line| try arr.append(line);
            break: blk try arr.toOwnedSlice();
        };
        errdefer alloc.free(lines);

        const defs, const it = try getDefinitionSection(lines);
        print("Def: {s}\n", .{defs.?});
        print("rest: {s}", .{rawContent[it..]});

        // const rules, it = getRulesSection(rawContent[it..]);
        // const subRoutine = getSubRoutine(rawContent[it..]);

        return .{
            .raw = lines,
            .definitions = defs,
        };
    }
};

fn fileMode(alloc: std.mem.Allocator, fileName: []u8) !void {
    var file = std.fs.cwd().openFile(fileName, .{}) catch |e| {
        return print("ft_lex: Failed to open: {s}, reason: {!}\n", .{fileName, e});
    };
    defer file.close();
    const rawContent = file.readToEndAlloc(alloc, 1e8) catch |e| {
        return print("ft_lex: Failed to read: {s}, reason: {!}\n", .{fileName, e});
    };
    defer alloc.free(rawContent);

    const sections = FileParser.parseContent(alloc, rawContent) catch |e| {
        return print("ft_lex: {!}\n", .{e});
    };
    _ = sections;
}

fn parseOptions(args: [][:0]u8) !struct {LexOptions, usize} {
    var opts = LexOptions{};
    if (args.len == 1) return .{opts, 0};

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

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{.stack_trace_frames = 15}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const options, const arg_it = parseOptions(args) catch {
        return print("Usage: ft_lex [-t] [-n|-v] [file...]\n", .{});
    };
    _ = options;

    //We've consumed all options and there's no file
    if (args.len == arg_it) {
        try interactiveMode(alloc);
    } else {
        try fileMode(alloc, args[arg_it]);
    }

}

test "dummy" {
    try std.testing.expect(1 == 1);
}
