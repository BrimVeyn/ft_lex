const std             = @import("std");
const LexParser       = @import("../../lex/Parser.zig");
const EC              = @import("../../regex/EquivalenceClasses.zig");

const NFAModule       = @import("../../regex/NFA.zig");
const NFA             = NFAModule.NFA;

const DFAModule       = @import("../../regex/DFA.zig");
const DFA             = DFAModule.DFA;

const DFAMinimizer    = @import("../../regex/DFA_minimizer.zig");

const ParserModule    = @import("../../regex/Parser.zig");
const RegexParser     = ParserModule.Parser;
const RegexNode       = ParserModule.RegexNode;
const Printer         = @import("../../lex/Printer/Printer.zig");
const G               = @import("../../globals.zig");

var   yy_ec: [256]u8  = .{0} ** 256;
const outputDir       = "src/test/lex/outputs/";
const libPath         = "src/libl/libl.a";

// const libflPath       = "-ll";
const libflPath       = "/home/bvan-pae/Documents/homebrew/opt/flex/lib/libfl.a";

const testDirC        = "src/test/lex/examples_c/";
const testDirZig      = "src/test/lex/examples_zig/";

///Runs ft_lex, compiles its output file and run it on the langFile
///
/// - `lFile`: path to the .l file to parse
/// - `langFile`: path to the .lang file to lex
fn produceFtLexOutput(alloc: std.mem.Allocator, lFile: []const u8, langFile: []const u8) !void {
    DFAMinimizer.offset = 0;
    G.resetGlobals();

    var lexParser = try LexParser.init(alloc, @constCast(lFile));
    defer lexParser.deinit();

    lexParser.parse() catch return;

    var regexParser = try RegexParser.init(alloc);
    defer regexParser.deinit();

    var headList = std.ArrayList(*RegexNode).init(alloc);
    defer headList.deinit();

    for (lexParser.rules.items) |rule| {
        regexParser.loadSlice(rule.regex);
        const head = regexParser.parse() catch |e| {
            std.log.err("\"{s}\": {!}", .{rule.regex, e});
            return;
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
            std.log.err("NFA: {!}", .{e});
            continue;
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
    
    var buffer: [512]u8 = .{0} ** 512;
    var stream = std.io.fixedBufferStream(&buffer);
    const sWriter = stream.writer();
    
    try sWriter.print("{s}ft_lex.{s}.c", .{outputDir, std.fs.path.basename(lFile)});

    var file = try std.fs.cwd().createFile(buffer[0..stream.pos], .{});
    defer file.close();

    try Printer.printTo(ec, DFAs, bol_DFAs, tc_DFAs, finalDfa, lexParser, file.writer());

    var argBuffer: [2048]u8 = .{0} ** 2048;
    var argStream = std.io.fixedBufferStream(&argBuffer);
    const argWriter = argStream.writer();

    try argWriter.print(
        \\clang {0s} -o {2s}{1s}ftlex {4s} &&
        \\{2s}{1s}ftlex < {3s} > {2s}{1s}ftlex.output
    , .{buffer[0..stream.pos], std.fs.path.basename(lFile), outputDir, langFile, libPath});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(0, term.Exited);
}

///Runs ft_lex, compiles its output file and run it on the langFile
///
/// - `lFile`: path to the .l file to parse
/// - `langFile`: path to the .lang file to lex
fn produceFtLexOutputZig(alloc: std.mem.Allocator, lFile: []const u8, langFile: []const u8) !void {
    G.resetGlobals();
    DFAMinimizer.offset = 0;
    G.options.zig = true;

    var lexParser = try LexParser.init(alloc, @constCast(lFile));
    defer lexParser.deinit();

    lexParser.parse() catch return;

    var regexParser = try RegexParser.init(alloc);
    defer regexParser.deinit();

    var headList = std.ArrayList(*RegexNode).init(alloc);
    defer headList.deinit();

    for (lexParser.rules.items) |rule| {
        regexParser.loadSlice(rule.regex);
        const head = regexParser.parse() catch |e| {
            std.log.err("\"{s}\": {!}", .{rule.regex, e});
            return;
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
            std.log.err("NFA: {!}", .{e});
            continue;
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
    
    var buffer: [512]u8 = .{0} ** 512;
    var stream = std.io.fixedBufferStream(&buffer);
    const sWriter = stream.writer();
    
    try sWriter.print("{s}ft_lex.{s}.zig", .{outputDir, std.fs.path.basename(lFile)});

    var file = try std.fs.cwd().createFile(buffer[0..stream.pos], .{});
    defer file.close();

    try Printer.printTo(ec, DFAs, bol_DFAs, tc_DFAs, finalDfa, lexParser, file.writer());

    var argBuffer: [2048]u8 = .{0} ** 2048;
    var argStream = std.io.fixedBufferStream(&argBuffer);
    const argWriter = argStream.writer();

    try argWriter.print(
        \\zig build-exe {0s} -femit-bin={2s}{1s}ftlexZig &&
        \\{2s}{1s}ftlexZig < {3s} > {2s}{1s}ftlexZig.output
    , .{buffer[0..stream.pos], std.fs.path.basename(lFile), outputDir, langFile});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(0, term.Exited);
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
        \\flex <{1s} -o {0s} &&
        \\clang {0s} -o {3s}{2s}flex {5s} &&
        \\{3s}{2s}flex > {3s}{2s}flex.output < {4s}
    , .{buffer[0..stream.pos], lFile, std.fs.path.basename(lFile), outputDir, langFile, libflPath});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    _ = try child.spawnAndWait();

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(0, term.Exited);
    std.log.info("Success", .{});
}

///Compares ft_lex's output to flex's output
///
/// - `lFile`: path to the .l input file
/// - `langFile`: path to the file to tokenize
///
///Doesn't return but asserts equality
fn compareOutput(lFile: []const u8, langFile: []const u8) !void {
    const alloc = std.testing.allocator;
    std.fs.cwd().makeDir(outputDir) catch {};

    try produceFtLexOutput(alloc, lFile, langFile);
    try produceFlexOutput(alloc, lFile, langFile);

    var argBuffer: [1024]u8 = .{0} ** 1024;
    var argStream = std.io.fixedBufferStream(&argBuffer);
    const argWriter = argStream.writer();

    try argWriter.print(
        \\diff {0s}{1s}ftlex.output {0s}{1s}flex.output
    , .{outputDir, std.fs.path.basename(lFile)});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    _ = try child.spawnAndWait();

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(0, term.Exited);
}

///Compares ft_lex's output to flex's output
///
/// - `lFile`: path to the .l input file
/// - `langFile`: path to the file to tokenize
///
///Doesn't return but asserts equality
fn compareOutputZig(lFileZig: []const u8, lFileC: []const u8, langFile: []const u8) !void {
    const alloc = std.testing.allocator;
    std.fs.cwd().makeDir(outputDir) catch {};

    std.log.info("AVANT", .{});
    try produceFtLexOutputZig(alloc, lFileZig, langFile);
    std.log.info("APRES", .{});
    try produceFlexOutput(alloc, lFileC, langFile);

    var argBuffer: [1024]u8 = .{0} ** 1024;
    var argStream = std.io.fixedBufferStream(&argBuffer);
    const argWriter = argStream.writer();

    try argWriter.print(
        \\diff {0s}{1s}ftlexZig.output {0s}{1s}flex.output
    , .{outputDir, std.fs.path.basename(lFileC)});

    var child = std.process.Child.init(&[_][]const u8{
        "bash", "-c", argBuffer[0..argStream.pos],
    }, alloc);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    const term = try child.spawnAndWait();
    try std.testing.expectEqual(0, term.Exited);
}

test "C like syntax" {
    try compareOutput(
        testDirC ++ "c_like_syntax.l", 
        testDirC ++ "c_like_syntax.lang"
    );
}

test "Easy start conditions" {
    try compareOutput(
        testDirC ++ "start_conditions.l", 
        testDirC ++ "start_conditions.lang"
    );
}

test "Hard start conditions" {
    try compareOutput(
        testDirC ++ "start_conditions_2.l", 
        testDirC ++ "start_conditions_2.lang"
    );
}

test "Easy start conditions and bol" {
    try compareOutput(
        testDirC ++ "start_conditions_and_bol.l", 
        testDirC ++ "start_conditions_and_bol.lang"
    );
}

test "Hard start conditions and bol" {
    try compareOutput(
        testDirC ++ "start_conditions_and_bol_2.l", 
        testDirC ++ "start_conditions_and_bol_2.lang"
    );
}

test "Overlapping bol and default" {
    try compareOutput(
        testDirC ++ "bol_longest_match.l",
        testDirC ++ "bol_longest_match.lang",
    );
}

test "C99 ANSI syntax" {
    try compareOutput(
        testDirC ++ "c99_ansi.l",
        testDirC ++ "c99_ansi.lang",
    );
}

test "Easy trailing context" {
    try compareOutput(
        testDirC ++ "easy_tc.l",
        testDirC ++ "easy_tc.lang",
    );
}

test "Hard trailing context" {
    try compareOutput(
        testDirC ++ "hard_tc.l",
        testDirC ++ "hard_tc.lang",
    );
}

test "Extreme trailing context" {
    try compareOutput(
        testDirC ++ "extreme_tc.l",
        testDirC ++ "extreme_tc.lang",
    );
}

test "Wc" {
    try compareOutput(
        testDirC ++ "wc.l",
        testDirC ++ "wc.lang",
    );
}

test "Easy input() and unput()" {
    try compareOutput(
        testDirC ++ "easy_input_unput.l",
        testDirC ++ "easy_input_unput.lang",
    );
}

test "Hard input() and unput()" {
    try compareOutput(
        testDirC ++ "hard_input_unput.l",
        testDirC ++ "hard_input_unput.lang",
    );
}

test "Hard input() and unput() 2" {
    try compareOutput(
        testDirC ++ "hard_input_unput_2.l",
        testDirC ++ "hard_input_unput_2.lang",
    );
}

test "Extreme input() and unput()" {
    try compareOutput(
        testDirC ++ "extreme_input_unput.l",
        testDirC ++ "extreme_input_unput.lang",
    );
}

test "Easy yymore()" {
    try compareOutput(
        testDirC ++ "easy_yymore.l",
        testDirC ++ "easy_yymore.lang",
    );
}

test "Easy yymore() 2" {
    try compareOutput(
        testDirC ++ "easy_yymore_2.l",
        testDirC ++ "easy_yymore_2.lang",
    );
}

test "Medium yymore()" {
    try compareOutput(
        testDirC ++ "medium_yymore.l",
        testDirC ++ "medium_yymore.lang",
    );
}

test "Easy yyless()" {
    try compareOutput(
        testDirC ++ "easy_yyless.l",
        testDirC ++ "easy_yyless.lang"
    );
}

test "Easy REJECT" {
    try compareOutput(
        testDirC ++ "easy_REJECT.l",
        testDirC ++ "easy_REJECT.lang"
    );
}

test "Hardcore" {
    try compareOutput(
        testDirC ++ "hardcore.l",
        testDirC ++ "hardcore.lang"
    );
}

test "[ZIG] Easy yy_more()" {
    try compareOutputZig(
        testDirZig ++ "easy_yymore.l",
        testDirC ++ "easy_yymore.l",
        testDirC ++ "easy_yymore.lang",
    );
}

test "[ZIG] Easy yyless()" {
    try compareOutputZig(
        testDirZig ++ "easy_yyless.l",
        testDirC ++ "easy_yyless.l",
        testDirC ++ "easy_yyless.lang",
    );
}

test "[ZIG] Easy input() and unput()" {
    try compareOutputZig(
        testDirZig ++ "easy_input_unput.l",
        testDirC ++ "easy_input_unput.l",
        testDirC ++ "easy_input_unput.lang",
    );
}

test "[ZIG] Hard start condition" {
    try compareOutputZig(
        testDirZig ++ "start_conditions_2.l",
        testDirC ++ "start_conditions_2.l",
        testDirC ++ "start_conditions_2.lang",
    );
}

test "[ZIG] Easy REJECT()" {
    try compareOutputZig(
        testDirZig ++ "easy_REJECT.l",
        testDirC ++ "easy_REJECT.l",
        testDirC ++ "easy_REJECT.lang",
    );
}

test "[ZIG] Wc" {
    try compareOutputZig(
        testDirZig ++ "wc.l",
        testDirC ++ "wc.l",
        testDirC ++ "wc.lang",
    );
}

test "[ZIG] Hardcore" {
    try compareOutputZig(
        testDirZig ++ "hardcore.l",
        testDirC ++ "hardcore.l",
        testDirC ++ "hardcore.lang",
    );
}
