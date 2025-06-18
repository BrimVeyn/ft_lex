const std                = @import("std");
const mem                = std.mem;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const rootModule         = @import("../../main.zig");
const DFAModule          = @import("../../regex/DFA.zig");
const EC                 = @import("../../regex/EquivalenceClasses.zig");
const LexParser          = @import("../Parser.zig");

const Printer            = @This();
const DFA                = DFAModule.DFA;

const G                  = @import("../../globals.zig");
const C                  = @import("c/init.zig");
const Zig                = @import("zig/init.zig");

fn printUserCode(lexParser: LexParser, writer: anytype) !void {
    for (lexParser.definitions.cCodeFragments.items) |codeFragment| {
        if (G.options.zig == false) {
            try writer.print("#line {d} \"{s}\"\n", .{codeFragment.lineNo, G.options.inputName});
        }
        _ = try writer.write(codeFragment.code);
        _ = try writer.write("\n\n");
    }
}

fn printBodyZig(lexParser: LexParser, writer: anytype) !void {
    _ = lexParser; _ = writer;
    std.log.info("ZIG VERSION", .{});
}


pub fn print(
    ec: EC,
    dfas: ArrayListUnmanaged(DFA.DFA_SC),
    bol_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    tc_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    dfa: DFA,
    lexParser: LexParser,
) !void {
    var file, const close = 
        if (G.options.t) 
            .{ std.io.getStdOut(), false } 
        else 
            .{ 
                if (G.options.zig)
                    try std.fs.cwd().createFile("ft_lex.yy.zig", .{})
                else
                    try std.fs.cwd().createFile("ft_lex.yy.c", .{}),
                true
            };
    defer if (close) file.close();

    const writer = file.writer();

    if (G.options.zig) {
        try Zig.tables.printTables(dfa, tc_dfas, lexParser, ec, writer);
        try printUserCode(lexParser, writer);
        try Zig.sc.printSCEnum(lexParser, dfas, bol_dfas, writer);
        try Zig.body.printBody(lexParser, writer);
    } else {
        try C.tables.printTables(dfa, tc_dfas, lexParser, ec, writer);
        try printUserCode(lexParser, writer);
        try C.sc.printSCEnum(lexParser, dfas, bol_dfas, writer);
        try C.body.printBody(lexParser, writer);
    }

    if (lexParser.userSubroutines) |subroutine| {
        _ = try writer.write(subroutine);
    }

    if (G.options.v) {
        try printStatistics(lexParser, dfa);
    }
}

fn printStatistics(lexParser: LexParser, dfa: DFA) !void {
    std.debug.print("ft_lex usage statistics:\n", .{});
    std.debug.print("\t{d}/{d} parse tree nodes\n", .{G.ParseTreeNodes, G.options.maxParseTreeNodes});
    std.debug.print("\t{d}/{d} character classes\n", .{G.PackedCharClass, G.options.maxPackedCharClass});
    std.debug.print("\t{d}/{d} NFA states\n", .{G.States, G.options.maxStates});
    if (!G.options.fast) {
        const compressedSize = (dfa.cTransTable.?.base.len * 2) + (dfa.cTransTable.?.next.len * 2) + dfa.yy_accept.?.len;
        std.debug.print("\t{d} equivalence classes\n", .{dfa.yy_ec_highest});
        std.debug.print("\t{d}/{d} total table entries\n", .{compressedSize, G.options.maxSizeDFA});
    } else {
        const fastSize = dfa.transTable.?.data.items.len * dfa.transTable.?.data.items[0].items.len;
        std.debug.print("\t{d}/{d} total table entries needed\n", .{fastSize, G.options.maxSizeDFA});
    }
    std.debug.print("\t{d} DFA states\n", .{G.DFAStates});
    std.debug.print("\t{d} minDFA states\n", .{dfa.minimized.?.data.items.len});
    std.debug.print("\t{d} rules\n", .{lexParser.rules.items.len});
    std.debug.print("\t{d} start condition(s)\n", .{lexParser.definitions.startConditions.data.items.len});
}

///This function is similar to the previous declaration, however its only used
///in tests.
pub fn printTo(
    ec: EC,
    dfas: ArrayListUnmanaged(DFA.DFA_SC),
    bol_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    tc_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    dfa: DFA,
    lexParser: LexParser,
    writer: anytype,
) !void {
    if (G.options.zig) {
        try Zig.tables.printTables(dfa, tc_dfas, lexParser, ec, writer);
        try printUserCode(lexParser, writer);
        try Zig.sc.printSCEnum(lexParser, dfas, bol_dfas, writer);
        try Zig.body.printBody(lexParser, writer);
    } else {
        try C.tables.printTables(dfa, tc_dfas, lexParser, ec, writer);
        try printUserCode(lexParser, writer);
        try C.sc.printSCEnum(lexParser, dfas, bol_dfas, writer);
        try C.body.printBody(lexParser, writer);
    }

    if (lexParser.userSubroutines) |subroutine| {
        _ = try writer.write(subroutine);
    }
}
