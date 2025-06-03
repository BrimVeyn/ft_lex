const std           = @import("std");
const DFA           = @import("DFA.zig").DFA;
const ColorCycler   = @import("ColorCycler.zig");

const Green         = "\x1b[32m"; // Green for Char and CharClass
const BrightGreen   = "\x1b[92m"; // Bright green for literal chars
const Yellow        = "\x1b[33m"; // Yellow for Concat and TrailingContext
const Cyan          = "\x1b[36m"; // Cyan for Repetition
const Blue          = "\x1b[34m"; // Blue for Alternation
const Magenta       = "\x1b[35m"; // Magenta for Groups
const Red           = "\x1b[31m"; // Red for Anchors
const White         = "\x1b[97m"; // White for label text
const Reset         = "\x1b[0m";  // Reset color

pub fn stringify(self: DFA, alloc: std.mem.Allocator) ![]u8 {
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();

    var writer = buffer.writer();
    var dfa_it = self.data.iterator();

    var cycler = ColorCycler{};

    while (dfa_it.next()) |entry|{
        const i_src = self.data.getIndex(entry.key_ptr.*);
        if (entry.value_ptr.accept_id) |accept_id| {
            const fmt = "d{d} [shape=\"doublecircle\", style=\"filled\", fillcolor=\"{s}\", label=\"d{0d} r{d}\"]\n";
            try writer.print(fmt, .{i_src.?, cycler.getColor(accept_id), accept_id});
        }
        for (entry.value_ptr.*.transitions.items) |t| {
            const i_dest = self.data.getIndex(t.to);
            switch (t.symbol) {
                .char => |s| try writer.print("d{?} -> d{?} [label=\"{c}\"]\n", .{i_src, i_dest, s}),
                .epsilon => try writer.print("d{?} -> d{?} [label=\"#\"]\n", .{i_src, i_dest}),
                .ec => |ec| try writer.print("d{?} -> d{?} [label=\"EC:{d}\"]\n", .{i_src, i_dest, ec}),
            }
        }
    }
    return try buffer.toOwnedSlice();
}

pub fn minimizedStringify(self: DFA, alloc: std.mem.Allocator) ![]u8 {
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();

    var writer = buffer.writer();
    var cycler = ColorCycler{};

    const minimized = self.minimized orelse return "";

    for (minimized.data.items, 0..) |state, sId| {
        if (state.accept_id) |accept_id| {
            const fmt = "dm{d} [shape=\"doublecircle\", style=\"filled\", fillcolor=\"{s}\", label=\"d{0d} r{d}\"]\n";
            try writer.print(fmt, .{sId, cycler.getColor(accept_id), accept_id});
        }
        for (state.signature.?.data.items) |t| {
            switch (t.symbol) {
                .char => |s| try writer.print("dm{?} -> dm{?} [label=\"{c}\"]\n", .{sId, t.group_id, s}),
                .ec => |ec| try writer.print("dm{?} -> dm{?} [label=\"EC:{d}\"]\n", .{sId, t.group_id, ec}),
                else => unreachable,
            }
        }
    }
    return try buffer.toOwnedSlice();
}

const Veci16 = std.ArrayList(i16);

pub fn compressedTableDump(base: Veci16, next: Veci16, check: Veci16, default: Veci16) void {
    const helper = struct {
        fn head(str: []const u8) void { std.debug.print("{s:10}:", .{str}); }
        fn body(table: Veci16) void { for (table.items) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
        fn enumerate(max: usize) void { for (0..max) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
    };

    const maxLen = std.sort.max(
        usize, 
        &[_]usize{base.items.len, next.items.len, check.items.len},
        {}, std.sort.asc(usize)
    ).?;

    helper.head("index");
    helper.enumerate(maxLen);
    helper.head("base");
    helper.body(base);
    helper.head("next");
    helper.body(next);
    helper.head("check");
    helper.body(check);
    helper.head("default");
    helper.body(default);
}

pub fn transTableDump(table: std.ArrayList(std.ArrayList(i16))) void {
    const helper = struct {
        fn head(str: []const u8) void { std.debug.print("{s:10}:", .{str}); }
        fn body(t: Veci16) void { for (t.items) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
        fn enumerate(min:usize, max:usize) void { for (min..max) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
    };

    helper.head("state/ec");
    helper.enumerate(0, table.items[0].items.len);
    for (table.items, 0..) |row, i| {
        var buffer:[100]u8 = .{0} ** 100;
        _ = std.fmt.bufPrint(&buffer, "{d:10}", .{i}) catch return ;
        helper.head(buffer[0..]);

        for (row.items) |t| {
            if (t != -1) {
                std.debug.print("{d:4}", .{t});
            } else {
                std.debug.print("{s}{d:4}{s}", .{Red, -1, Reset});
            }
        }
        std.debug.print("\n", .{});
    }
}
