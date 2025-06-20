const std                 =  @import("std");
const mem                 =  std.mem;
const ArrayListUnmanaged  =  std.ArrayListUnmanaged;

const EC                  =  @import("../../../regex/EquivalenceClasses.zig");
const LexParser           =  @import("../../Parser.zig");
const DFAModule           =  @import("../../../regex/DFA.zig");
const DFA                 =  DFAModule.DFA;
const G                   =  @import("../../../globals.zig");

const MAX_ITEM_PER_ROW: usize = 10;

fn digitCount(n: anytype) usize {
    var num = if (n < 0) -n else n; // make it positive
    var count: usize = 1;

    while (num >= 10) {
        num = @divTrunc(num, 10);
        count += 1;
    }

    return count;
}

fn printAndPadArray(array: ?[]usize, length: usize, writer: anytype) !void {
    _ = try writer.write(".{");
    for (0..length) |i| {

        if (array == null or i >= array.?.len) {
            _ = try writer.print("{d:3}, ", .{ 0 });
        } else {
            _ = try writer.print("{d:3}, ", .{array.?[i]});
        }
    }
    _ = try writer.write("}, ");
}

fn printSigned(num: anytype, writer: anytype) !void {
    const count = digitCount(num);
    if (count >= 5) {
        _ = try writer.print("{d}, ", .{num});
    } else {
        for (0..(5 - count)) |_| _ = try writer.write(" "); 
        _ = try writer.print("{d}, ", .{num});
    }
}

fn printYyAcclist(dfa: DFA, tc_dfa: ArrayListUnmanaged(DFA.DFA_SC), lexParser: LexParser, writer: std.fs.File.Writer) !void {
    var acclist = try dfa.alloc.alloc(i16, lexParser.rules.items.len + 1);
    defer dfa.alloc.free(acclist);
    @memset(acclist, 0);

    for (tc_dfa.items) |tc| {
        acclist[tc.trailingContextRuleId.? + 1] = @intCast(tc.dfa.offset);
    }

    try writer.print("const yy_acclist: [{d}]i16 = .{{", .{lexParser.rules.items.len + 1});
    for (acclist, 0..) |item, it| {
        if (it % MAX_ITEM_PER_ROW == 0) {
            _ = try writer.write("\n");
        }
        try printSigned(item, writer);
    }
    _ = try writer.write("\n};\n\n");
}

fn printTable(comptime T: type, writer: anytype, table: []T, head: []const u8, typeLen: []const u8, sign: []const u8) !void {
    try writer.print("const yy_{s}: [{d}]{s}{s} = .{{", .{head, table.len, sign, typeLen});

    for (table, 0..) |item, it| {
        if (it % MAX_ITEM_PER_ROW == 0) {
            _ = try writer.write("\n");
        }
        if (mem.eql(u8, sign, "i")) try printSigned(item, writer)
        else try writer.print("{: >5}, ", .{item});
    }
    _ = try writer.write("\n};\n\n");
}

fn printYyAcceptExtended(dfa: DFA, writer: anytype) !void {
    const longest = blk: {
        var longest: usize = 1;
        for (dfa.minimized.?.data.items) |s| {
            if (s.accept_list) |a| longest = if (a.len > longest) a.len else longest;
        }
        break: blk longest;
    };

    try writer.print("const yy_accept: [{d}][{d}]i32 = .{{", .{dfa.minimized.?.data.items.len, longest});

    for (dfa.minimized.?.data.items, 0..) |s, it| {
        if (it % (MAX_ITEM_PER_ROW / 2) == 0) _ = try writer.write("\n");
        if (s.accept_list) |al| try printAndPadArray(al[0..], longest, writer)
        else try printAndPadArray(null, longest, writer);
    }
    _ = try writer.write("\n};\n\n");
}

fn printYyReject(dfa: DFA, writer: anytype) !void {
    try writer.print("var yy_reject: [{d}]u8 = .{{", .{dfa.minimized.?.data.items.len});

    for (0..dfa.minimized.?.data.items.len) |it| {
        if (it % MAX_ITEM_PER_ROW == 0) _ = try writer.write("\n");
        try writer.print("{d:5}, ", .{0});
    }
    _ = try writer.write("\n};\n\n");
}


fn printYyNext(dfa: DFA, writer: anytype) !void {
    try writer.print("const yy_next: [{d}][{d}]i16 = .{{\n", .{dfa.minimized.?.data.items.len, std.math.maxInt(u8)});
    const tt = dfa.transTable orelse return error.NoTransTable;

    for (tt.data.items) |s| {

        try writer.print(".{{ ", .{});
        for (s.items, 0..) |trans, it| {
            if (it % MAX_ITEM_PER_ROW == 0) _ = try writer.write("\n");
            try printSigned(trans, writer);
        }
        try writer.print("}},\n", .{});
    }
    _ = try writer.write("\n};\n\n");
}


pub fn printTables(dfa: DFA, tc_dfas: ArrayListUnmanaged(DFA.DFA_SC), lexParser: LexParser, ec: EC, writer: anytype) !void {
    _ = try writer.write(
        \\const std    = @import("std");
        \\const stdin  = std.io.getStdIn();
        \\const stdout = std.io.getStdOut();
        \\
        \\
    );

    if (G.options.needTcBacktracking)
        try printYyAcclist(dfa, tc_dfas, lexParser, writer);

    if (G.options.needREJECT) {
        try printYyReject(dfa, writer);
        try printYyAcceptExtended(dfa, writer);
    } else try printTable(i32, writer, dfa.yy_accept.?, "accept", "32", "i");

    if (G.options.fast) {
        try printYyNext(dfa, writer);
    } else {
        try printTable(u8, writer, @constCast((ec.yy_ec)[0..]), "ec", "8", "u");
        try printTable(i16, writer, dfa.cTransTable.?.base, "base", "16", "i");
        try printTable(i16, writer, dfa.cTransTable.?.default, "default", "16", "i");
        try printTable(i16, writer, dfa.cTransTable.?.next, "next", "16", "i");
        try printTable(i16, writer, dfa.cTransTable.?.check, "check", "16", "i");
    }

}
