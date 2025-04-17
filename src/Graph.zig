const std = @import("std");
const NFA = @import("NFA.zig").NFA;
const DFA = @import("DFA.zig").DFA;

const format:[]const u8 = 
\\digraph Combined {{
\\    rankdir=LR;
\\    node [shape=circle];
\\ edge [fontname="monospace"];
\\ node [fontname="monospace", shape=circle];
\\
\\ subgraph cluster_dfa {{
\\  label="DFA for {s}"
\\{s}
\\ }}
\\
\\ subgraph cluster_nfa {{
\\  label="NFA for {s}"
\\
\\  start [shape=point, width=0.2];
\\  edge [style=solid];
\\  start -> n1;
\\
\\{s}
\\ }}
\\
\\    subgraph cluster_ec {{
\\        label="Equivalence Classes"
\\        node [shape=box];
\\{s}
\\    }}
\\}}
;
//regex, nfa, regex, dfa

fn stringifyClassSet(
    alloc: std.mem.Allocator,
    yy_ec: *[256]u8,
) ![]u8 {
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();

    const writer = buffer.writer();

    // Group characters by their equivalence class id
    var class_map = std.AutoArrayHashMap(u8, std.ArrayList(u8)).init(alloc);
    defer {
        var it = class_map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        class_map.deinit();
    }

    for (0..256) |i| {
        const c: u8 = @intCast(i);
        const class_id = yy_ec[c];
        if (class_id == 1 or class_id == 0) continue;

        const list = try class_map.getOrPut(class_id);
        if (!list.found_existing) {
            list.value_ptr.* = std.ArrayList(u8).init(alloc);
        }
        try list.value_ptr.append(c);
    }

    var it = class_map.iterator();
    while (it.next()) |entry| {
        const class_id = entry.key_ptr.*;
        const chars = entry.value_ptr.items;

        try writer.print("  ec{d} [label=\"EC {d}\\n", .{class_id, class_id});

        var printed = false;
        for (chars) |c| {
            if (printed) try writer.writeAll(" ");
            printed = true;

            if (std.ascii.isPrint(c)) {
                try writer.print("{c}", .{c});
            } else {
                try writer.print("\\x{X:0>2}", .{c});
            }
        }

        try writer.writeAll("\"];\n");
    }

    return try buffer.toOwnedSlice();
}


pub fn dotFormat(
    regex: []const u8,
    nfa: NFA,
    dfa: DFA,
    yy_ec: *[256]u8,
) void {
    const nfa_str = nfa.stringify(std.heap.page_allocator) catch return;
    const dfa_str = dfa.stringify(std.heap.page_allocator) catch return;
    const class_set_str = stringifyClassSet(std.heap.page_allocator, yy_ec) catch return;
    defer {
        std.heap.page_allocator.free(class_set_str);
        std.heap.page_allocator.free(nfa_str);
        std.heap.page_allocator.free(dfa_str);
    }

    std.debug.print(format, .{regex, dfa_str, regex, nfa_str, class_set_str});
}
