const std                 =  @import("std");
const ArrayListUnmanaged  =  std.ArrayListUnmanaged;
const rootModule          =  @import("../../main.zig");
const DFAModule           =  @import("../../regex/DFA.zig");
const EC                  =  @import("../../regex/EquivalenceClasses.zig");
const LexParser           =  @import("../Parser.zig");

const Printer             =  @This();
const LexOptions          =  rootModule.LexOptions;
const DFA                 =  DFAModule.DFA;

const Templates           =  @import("Templates.zig");

const MAX_ITEM_PER_ROW: usize = 10;

fn printTable(comptime T: type, writer: anytype, table: []T, head: []const u8) !void {
    try writer.print("static const int16_t yy_{s}[{d}] = {{", .{head, table.len});

    for (table, 0..) |item, it| {
        if (it % MAX_ITEM_PER_ROW == 0) {
            _ = try writer.write("\n");
        }
        try writer.print("{d:5}, ", .{item});
    }
    _ = try writer.write("\n};\n\n");
}


const actionsHead =
\\static inline void yy_action(int accept_id) {
\\  switch (accept_id) {
\\
;

const actionsTail =
\\      default:
\\          fprintf(stderr, "Unknown action id: %d\n", accept_id);
\\          break;
\\      }
\\}
\\
;

const ruleHead =
\\      case {d}:
\\
;

const ruleTail =
\\
\\          break;
\\
;

fn printActions(lParser: LexParser, writer: anytype) !void {
    _ = try writer.write(actionsHead);
    for (lParser.rules.items, 0..) |rule, i| {
        _ = try writer.print(ruleHead, .{i + 1});
        _ = try writer.write(rule.code.code);

        //Do not insert break statement as its a fallthrough rule
        if (std.mem.eql(u8, "|", rule.code.code))
            continue;

        _ = try writer.write(ruleTail);
    }
    _ = try writer.write(actionsTail);
}

fn printSCEnum(
    lParser: LexParser,
    dfas: ArrayListUnmanaged(DFA.DFA_SC),
    bol_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    writer: anytype
) !void {
    _ = try writer.write("enum {\n");
    for (lParser.definitions.startConditions.data.items, dfas.items[0..], bol_dfas.items[0..]) |sc, dfa, bol| {
        //NOTE: We encode both Bol and Regular start position in a single int rather than creating an other enum.
        //Flex is smarter than that with table representation as the bol start is always one state after the sc regular start.
        //But with current implementation, it'll be a lot of overhead to use this representation.
        // std.debug.print("Offset bol: {d}, offset regular: {d}\n", .{bol.dfa.offset, dfa.dfa.offset});
        const value = (bol.dfa.offset << @as(u6, 16)) + dfa.dfa.offset; 
        _ = try writer.print("\t{s} = {d},\n", .{sc.name, value});
    }
    _ = try writer.write("};\n\n");
}

fn printTables(dfa: DFA, ec: EC, writer: anytype) !void {
    _ = try writer.write("#include <stdint.h>\n");
    _ = try writer.write("#include <stdio.h>\n");
    _ = try writer.write("#include <string.h>\n\n\n");
    try printTable(i16, writer, dfa.yy_accept.?, "accept");
    try printTable(u8, writer, @constCast((ec.yy_ec)[0..]), "ec");
    try printTable(i16, writer, dfa.cTransTable.?.base, "base");
    try printTable(i16, writer, dfa.cTransTable.?.default, "default");
    try printTable(i16, writer, dfa.cTransTable.?.next, "next");
    try printTable(i16, writer, dfa.cTransTable.?.check, "check");
}

fn printUserCode(lexParser: LexParser, opts: LexOptions, writer: anytype) !void {
    for (lexParser.definitions.cCodeFragments.items) |codeFragment| {
        try writer.print("#line {d} \"{s}\"\n", .{codeFragment.lineNo, opts.inputName});
        _ = try writer.write(codeFragment.code);
        _ = try writer.write("\n\n");
    }
}

fn printBody(lexParser: LexParser, writer: anytype) !void {
    _ = try writer.write(Templates.bodyFirstPart);
    try printActions(lexParser, writer);
    _ = try writer.write(Templates.bodySecondPart);
}


pub fn print(
    ec: EC,
    dfas: ArrayListUnmanaged(DFA.DFA_SC),
    bol_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    dfa: DFA,
    lexParser: LexParser,
    opts: LexOptions
) !void {
    var file, const close = if (opts.t) 
        .{ std.io.getStdOut(), false } 
    else 
        .{ try std.fs.cwd().createFile("ft_lex.yy.c", .{}), true };
    defer if (close) file.close();

    const writer = file.writer();

    try printTables(dfa, ec, writer);
    try printUserCode(lexParser, opts, writer);
    try printSCEnum(lexParser, dfas, bol_dfas, writer);
    try printBody(lexParser, writer);

    if (lexParser.userSubroutines) |subroutine| {
        std.debug.print("Used user subroutine\n", .{});
        _ = try writer.write(subroutine);
    } else {
        std.debug.print("Default main produced\n", .{});
        _ = try writer.write(Templates.defaultMain);
    }
}

pub fn printTo(
    ec: EC,
    dfas: ArrayListUnmanaged(DFA.DFA_SC),
    bol_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    dfa: DFA,
    lexParser: LexParser,
    opts: LexOptions,
    writer: anytype,
) !void {
    try printTables(dfa, ec, writer);
    try printUserCode(lexParser, opts, writer);
    try printSCEnum(lexParser, dfas, bol_dfas, writer);
    try printBody(lexParser, writer);

    if (lexParser.userSubroutines) |subroutine| {
        std.debug.print("Used user subroutine\n", .{});
        _ = try writer.write(subroutine);
    } else {
        std.debug.print("Default main produced\n", .{});
        _ = try writer.write(Templates.defaultMain);
    }
}
