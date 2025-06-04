const std               = @import("std");
const LexParser         = @import("../../lex/Parser.zig");
const EC                = @import("../../regex/EquivalenceClasses.zig");

const NFAModule         = @import("../../regex/NFA.zig");
const NFA               = NFAModule.NFA;

const DFAModule         = @import("../../regex/DFA.zig");
const DFA               = DFAModule.DFA;

const DFAMinimizer      = @import("../../regex/DFA_minimizer.zig");

const ParserModule      = @import("../../regex/Parser.zig");
const RegexParser       = ParserModule.Parser;
const RegexNode         = ParserModule.RegexNode;
const Printer           = @import("../../lex/Printer/Printer.zig");

var     yy_ec: [256]u8  = .{0} ** 256;
const outputDir = "src/test/lex/outputs/";

///Runs ft_lex, compiles its output file and run it on the langFile
///
/// - `lFile`: path to the .l file to parse
/// - `langFile`: path to the .lang file to lex
fn produceFtLexOutput(alloc: std.mem.Allocator, lFile: []const u8, langFile: []const u8) !void {
    //NOTE: Reset this global otherwise we can't run more than one test sequentially
    DFAMinimizer.offset = 0;

    var lexParser = try LexParser.init(alloc, @constCast(lFile));
    defer lexParser.deinit();

    lexParser.parse() catch return;

    var regexParser = try RegexParser.init(alloc);
    defer regexParser.deinit();

    var headList = std.ArrayList(*RegexNode).init(alloc);
    defer headList.deinit();

    for (lexParser.rules.items) |rule| {
        regexParser.loadSlice(rule.regex);
        // std.debug.print("Parsing regex: {s}", .{rule.regex});
        const head = regexParser.parse() catch |e| {
            std.log.err("\"{s}\": {!}", .{rule.regex, e});
            return;
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
        nfaBuilder.reset();
        const nfa = nfaBuilder.astToNfa(head) catch |e| {
            std.log.err("NFA: {!}", .{e});
            continue;
        };
        try nfaList.append(nfa);
    }

    const mergedNFAs, const bolMergedNFAs = try nfaBuilder.merge(nfaList.items, lexParser);
    defer {
        for (mergedNFAs.items) |m| alloc.free(m.acceptList);
        for (bolMergedNFAs.items) |m| alloc.free(m.acceptList);
        mergedNFAs.deinit();
        bolMergedNFAs.deinit();
    }

    var finalDfa, var DFAs, var bol_DFAs = try DFA.buildAndMergeFromNFAs(alloc, mergedNFAs, bolMergedNFAs, ec);
    defer {
        for (DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        for (bol_DFAs.items) |*dfa_sc| dfa_sc.dfa.deinit();
        DFAs.deinit(alloc);
        bol_DFAs.deinit(alloc);
        finalDfa.mergedDeinit();
    }
    
    std.fs.cwd().makeDir("src/test/lex/outputs") catch {};
    var buffer: [512]u8 = .{0} ** 512;
    var stream = std.io.fixedBufferStream(&buffer);
    const sWriter = stream.writer();
    
    try sWriter.print("{s}ft_lex.{s}.c", .{outputDir, std.fs.path.basename(lFile)});

    var file = try std.fs.cwd().createFile(buffer[0..stream.pos], .{});
    defer file.close();

    try Printer.printTo(ec, DFAs, bol_DFAs, finalDfa, lexParser, .{}, file.writer());

    var argBuffer: [2048]u8 = .{0} ** 2048;
    var argStream = std.io.fixedBufferStream(&argBuffer);
    const argWriter = argStream.writer();

    try argWriter.print(
        \\clang {0s} -o {2s}ft_lex_{1s} &&
        \\{2s}ft_lex_{1s} {3s} > {2s}ft_lex_{1s}.output
    , .{buffer[0..stream.pos], std.fs.path.basename(lFile), outputDir, langFile});

    // std.debug.print("{s}\n\n\n", .{argBuffer[0..argStream.pos]});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    _ = try child.spawnAndWait();

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(term.Exited, 0);
}

///Runs flex, compiles its output file and run it on the langFile
///
/// - `lFile`: path to the .l file to parse
/// - `langFile`: path to the .lang file to lex
fn produceFlexOutput(alloc: std.mem.Allocator, lFile: []const u8, langFile: []const u8) !void {
    var buffer: [512]u8 = .{0} ** 512;
    var stream = std.io.fixedBufferStream(&buffer);
    const sWriter = stream.writer();

    try sWriter.print("{s}flex.{s}.c", .{outputDir, std.fs.path.basename(lFile)});

    var argBuffer: [2048]u8 = .{0} ** 2048;
    var argStream = std.io.fixedBufferStream(&argBuffer);
    const argWriter = argStream.writer();

    try argWriter.print(
        \\flex -o {0s} -i {1s} &&
        \\clang {0s} -o {3s}flex_{2s} /home/bvan-pae/Documents/homebrew/opt/flex/lib/libfl.a &&
        \\{3s}flex_{2s} > {3s}flex_{2s}.output < {4s}
    , .{buffer[0..stream.pos], lFile, std.fs.path.basename(lFile), outputDir, langFile});

    // std.debug.print("{s}\n\n\n", .{argBuffer[0..argStream.pos]});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    _ = try child.spawnAndWait();

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(term.Exited, 0);
}

///Compares ft_lex's output to flex's output
///
/// - `lFile`: path to the .l input file
/// - `langFile`: path to the file to tokenize
///
///Doesn't return but asserts equality
fn compareOutput(lFile: []const u8, langFile: []const u8) !void {
    const alloc = std.testing.allocator;

    try produceFtLexOutput(alloc, lFile, langFile);
    try produceFlexOutput(alloc, lFile, langFile);

    var argBuffer: [2048]u8 = .{0} ** 2048;
    var argStream = std.io.fixedBufferStream(&argBuffer);
    const argWriter = argStream.writer();

    try argWriter.print(
        \\diff {0s}ft_lex_{1s}.output {0s}flex_{1s}.output
    , .{outputDir, std.fs.path.basename(lFile)});

    // std.debug.print("{s}\n\n\n", .{argBuffer[0..argStream.pos]});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    _ = try child.spawnAndWait();

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(term.Exited, 0);
}

test "Start conditions and achor start" {
    try compareOutput(
        "src/test/lex/examples/c_like_syntax.l", 
        "src/test/lex/examples/c_like.syntax.lang"
    );
}
