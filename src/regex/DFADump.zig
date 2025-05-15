const std           = @import("std");
const DFA           = @import("DFA.zig").DFA;
const ColorCycler   = @import("ColorCycler.zig");

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
