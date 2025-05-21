const std           = @import("std");
const rootModule    = @import("root");
const DFAModule     = @import("../regex/DFA.zig");
const EC            = @import("../regex/EquivalenceClasses.zig");
const LexParser     = @import("../lex/Parser.zig");

const Printer       = @This();
const LexOptions    = rootModule.LexOptions;
const DFA           = DFAModule.DFA;

const MAX_ITEM_PER_ROW: usize = 10;

fn printTable(comptime T: type, writer: std.fs.File.Writer, table: []T, head: []const u8) !void {
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
\\void yy_action(int accept_id) {
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

fn printActions(lParser: LexParser, writer: std.fs.File.Writer) !void {
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

// fn printSCTable(lParser: LexParser, writer: std.fs.File.Writer) !void {
//     try writer.print("static const int16_t yy_sc[{d}] = {{", .{lParser.rules.items.len + 1});
//     for (lParser.rules.items, 0..) |r, it| {
//         if (it % MAX_ITEM_PER_ROW == 0) {
//             _ = try writer.write("\n");
//         }
//         if (it == 0) _ = try writer.write("0b0, ");
//         try writer.print("0b{b}, ", .{r.sc.mask});
//     }
//     _ = try writer.write("\n};\n\n");
// }

fn printSCEnum(lParser: LexParser, writer: std.fs.File.Writer) !void {
    _ = try writer.write("enum {\n");
    _ = try writer.write("\tINITIAL,\n");
    for (lParser.definitions.startConditions.data.items) |sc| {
        _ = try writer.print("\t{s},\n", .{sc.name});
    }
    _ = try writer.write("};\n\n");
}


pub fn print(ec: EC, dfa: DFA, lexParser: LexParser, opts: LexOptions) !void {
    var file, const close = if (opts.t) .{ std.io.getStdOut(), false } else .{ try std.fs.cwd().createFile("ft_lex.yy.c", .{}), true };
    defer if (close) file.close();

    const writer = file.writer();
    _ = try writer.write("#include <stdint.h>\n");
    _ = try writer.write("#include <stdio.h>\n");
    _ = try writer.write("#include <string.h>\n\n\n");
    try printTable(i16, writer, dfa.yy_accept.?, "accept");
    try printTable(u8, writer, @constCast((ec.yy_ec)[0..]), "ec");
    try printTable(i16, writer, dfa.cTransTable.?.base, "base");
    try printTable(i16, writer, dfa.cTransTable.?.default, "default");
    try printTable(i16, writer, dfa.cTransTable.?.next, "next");
    try printTable(i16, writer, dfa.cTransTable.?.check, "check");
    // try printSCTable(lexParser, writer);

    try printSCEnum(lexParser, writer);

    try printActions(lexParser, writer);

    if (lexParser.userSubroutines) |_| {
        std.debug.print("Yes !\n", .{});
    } else {
        std.debug.print("Default main produced\n", .{});
    }
}
