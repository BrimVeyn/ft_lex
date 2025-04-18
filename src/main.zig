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
    n: bool,
    t: bool,
    b: bool,
};

const FileParser = struct {
    const FileSections = struct {
        definitions: []u8, 
        rules: []u8,
        userSubroutines: []u8,
    };

    pub fn parseContent(rawContent: []u8) !FileSections {
        _ = rawContent;
        return error.bite;
    }
};

fn fileMode(alloc: std.mem.Allocator, fileName: []u8) !void {
    var file = std.fs.cwd().openFile(fileName, .{}) catch |e| {
        return print("Failed to open: {s}, reason: {!}\n", .{fileName, e});
    };
    defer file.close();
    const rawContent = file.readToEndAlloc(alloc, 1e8) catch |e| {
        return print("Faile to read: {s}, reason: {!}\n", .{fileName, e});
    };
    const sections = try FileParser.parseContent(rawContent);   
    _ = sections;
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{.stack_trace_frames = 15}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 1) {
        try interactiveMode(alloc);
    } else {
        // const options = parseOptions();
        try fileMode(alloc, args[1]);
    }

}

test "dummy" {
    try std.testing.expect(1 == 1);
}
