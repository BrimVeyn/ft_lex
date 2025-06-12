const std                 =  @import("std");
const mem                 =  std.mem;
const ArrayListUnmanaged  =  std.ArrayListUnmanaged;

const rootModule          =  @import("../../main.zig");
const DFAModule           =  @import("../../regex/DFA.zig");
const EC                  =  @import("../../regex/EquivalenceClasses.zig");
const LexParser           =  @import("../Parser.zig");

const Printer             =  @This();
const LexOptions          =  rootModule.LexOptions;
const DFA                 =  DFAModule.DFA;

const Templates           =  @import("Templates.zig");
const TemplatesYYMore     =  @import("TemplatesYYMore.zig");
const G                   =  @import("../../globals.zig");

const MAX_ITEM_PER_ROW: usize = 10;

const actionsHead =
\\    switch (accept_id) {
\\
;

const actionsTail =
\\        default:
\\            fprintf(stderr, "Unknown action id: %d\n", accept_id);
\\            break;
\\        }
\\
;

const ruleHead =
\\        case {d}:
\\
;

const ruleTail =
\\
\\        break;
\\
;

const tcLeft =
\\
\\        yy_buffer[yy_buf_pos] = yy_hold_char;
\\        yy_buf_pos = start_pos + {d};
\\        yyleng = {0d};
\\        YY_DO_BEFORE_ACTION
\\
;

const tcRight =
\\
\\        yy_buffer[yy_buf_pos] = yy_hold_char;
\\        yy_buf_pos -= {d};
\\        yyleng -= {0d};
\\        YY_DO_BEFORE_ACTION
\\
;

fn printActions(lParser: LexParser, writer: anytype) !void {
    _ = try writer.write(actionsHead);
    for (lParser.rules.items, 0..) |rule, i| {
        _ = try writer.print(ruleHead, .{i + 1});
        _ = try writer.write("{");

        //NOTE: Instead of generating the backtracking loop, we produce
        //these small code pieces to backtrack instantaneously
        if (rule.trailingContext.value) |leng| {
            switch (rule.trailingContext.side) {
                .Left => try writer.print(tcLeft, .{leng}),
                .Right => try writer.print(tcRight, .{leng}),
            }
        }

        _ = try writer.write(rule.code.code);

        //Do not insert break statement if the action is fallthrough
        if (!mem.eql(u8, "|", rule.code.code))
            _ = try writer.write(ruleTail);

        _ = try writer.write("\n}");
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

fn printYyAcclist(dfa: DFA, tc_dfa: ArrayListUnmanaged(DFA.DFA_SC), lexParser: LexParser, writer: std.fs.File.Writer) !void {
    var acclist = try dfa.alloc.alloc(i16, lexParser.rules.items.len + 1);
    defer dfa.alloc.free(acclist);
    @memset(acclist, 0);

    for (tc_dfa.items) |tc| {
        acclist[tc.trailingContextRuleId.? + 1] = @intCast(tc.dfa.offset);
    }

    try writer.print("static const int16_t yy_acclist[{d}] = {{", .{lexParser.rules.items.len + 1});
    for (acclist, 0..) |item, it| {
        if (it % MAX_ITEM_PER_ROW == 0) {
            _ = try writer.write("\n");
        }
        try writer.print("{d:5}, ", .{item});
    }
    _ = try writer.write("\n};\n\n");
}

fn printTable(comptime T: type, writer: anytype, table: []T, head: []const u8, typeLen: []const u8, sign: []const u8) !void {
    try writer.print("static const {s}int{s}_t yy_{s}[{d}] = {{", .{sign, typeLen, head, table.len});

    for (table, 0..) |item, it| {
        if (it % MAX_ITEM_PER_ROW == 0) {
            _ = try writer.write("\n");
        }
        try writer.print("{d:5}, ", .{item});
    }
    _ = try writer.write("\n};\n\n");
}

fn printTables(dfa: DFA, tc_dfas: ArrayListUnmanaged(DFA.DFA_SC), lexParser: LexParser, ec: EC, writer: anytype) !void {
    _ = try writer.write("#include <stdint.h>\n");
    _ = try writer.write("#include <stdio.h>\n");
    _ = try writer.write("#include <string.h>\n\n\n");

    if (G.options.needTcBacktracking)
        try printYyAcclist(dfa, tc_dfas, lexParser, writer);

    try printTable(i32, writer, dfa.yy_accept.?, "accept", "32", "");
    try printTable(u8, writer, @constCast((ec.yy_ec)[0..]), "ec", "8", "u");
    try printTable(i16, writer, dfa.cTransTable.?.base, "base", "16", "");
    try printTable(i16, writer, dfa.cTransTable.?.default, "default", "16", "");
    try printTable(i16, writer, dfa.cTransTable.?.next, "next", "16", "");
    try printTable(i16, writer, dfa.cTransTable.?.check, "check", "16", "");
}

fn printUserCode(lexParser: LexParser, writer: anytype) !void {
    for (lexParser.definitions.cCodeFragments.items) |codeFragment| {
        try writer.print("#line {d} \"{s}\"\n", .{codeFragment.lineNo, G.options.inputName});
        _ = try writer.write(codeFragment.code);
        _ = try writer.write("\n\n");
    }
}

fn printBody(lexParser: LexParser, writer: anytype) !void {
    _ = try writer.write(Templates.sectionOne);

    if (!G.options.needYYMore)
        _ = try writer.write(TemplatesYYMore.noYYmoreFallback);

    _ = try writer.write(Templates.sectionTwo);

    if (G.options.needYYMore)
        _ = try writer.write(TemplatesYYMore.yyMoreSectionOne);

    _ = try writer.write(Templates.sectionThree);

    if (G.options.needTcBacktracking)
        _ = try writer.write(TemplatesYYMore.tcBacktracking);

    if (G.options.needYYMore) {
        _ = try writer.write(TemplatesYYMore.yyMoreSectionTwo);
    } else {
        _ = try writer.write(Templates.sectionFour);
    }

    try printActions(lexParser, writer);

    _ = try writer.write(Templates.sectionFive);
}


pub fn print(
    ec: EC,
    dfas: ArrayListUnmanaged(DFA.DFA_SC),
    bol_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    tc_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    dfa: DFA,
    lexParser: LexParser,
) !void {
    var file, const close = if (G.options.t) 
        .{ std.io.getStdOut(), false } 
    else 
        .{ try std.fs.cwd().createFile("ft_lex.yy.c", .{}), true };
    defer if (close) file.close();

    const writer = file.writer();

    try printTables(dfa, tc_dfas, lexParser, ec, writer);
    try printUserCode(lexParser, writer);
    try printSCEnum(lexParser, dfas, bol_dfas, writer);
    try printBody(lexParser, writer);

    if (lexParser.userSubroutines) |subroutine| {
        _ = try writer.write(subroutine);
    }
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
    try printTables(dfa, tc_dfas, lexParser, ec, writer);
    try printUserCode(lexParser, writer);
    try printSCEnum(lexParser, dfas, bol_dfas, writer);
    try printBody(lexParser, writer);

    if (lexParser.userSubroutines) |subroutine| {
        std.debug.print("Used user subroutine\n", .{});
        _ = try writer.write(subroutine);
    }
}
