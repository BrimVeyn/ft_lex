const std       = @import("std");
const NFA       = @import("NFA.zig").NFA;
const DFA       = @import("DFA.zig").DFA;
const LexParser = @import("../lex/Parser.zig");
const ColorCycler = @import("ColorCycler.zig");

const format:[]const u8 = 
\\digraph Combined {{
\\    rankdir=LR;
\\    node [shape=circle];
\\ edge [fontname="monospace"];
\\ node [fontname="monospace", shape=circle];
\\
\\ subgraph cluster_dfa_minified {{
\\  label="Minified DFA"
\\{s}
\\ }}
\\
\\ subgraph cluster_dfa {{
\\  label="DFA"
\\{s}
\\      subgraph cluster_regex {{
\\            label="Rules"
\\            node [shape=box];
\\            {s}
\\        }}
\\ }}
\\
\\ subgraph cluster_nfa {{
\\  label="NFA"
\\
\\  start [shape=point, width=0.2];
\\  edge [style=solid];
\\  start -> n0;
\\
\\{s}
\\ }}
\\
\\  subgraph cluster_ec {{
\\        label="Equivalence Classes"
\\        node [shape=box];
\\{s}
\\    }}

\\}}
\\
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

        try writer.print("  ec1 [label=\"EC 1: ^(Σ EC2...ECn)\"];\n", .{});
        try writer.print("  ec{d} [label=\"EC {d}: ", .{class_id, class_id});

        var printed = false;
        for (chars) |c| {
            if (printed) try writer.writeAll(" ");
            printed = true;

            if (c == '"') {
                try writer.writeAll("\\\"");
            }else if (std.ascii.isPrint(c)) {
                try writer.print("{c}", .{c});
            } else {
                try writer.print("\\x{X:0>2}", .{c});
            }
        }

        try writer.writeAll("\"];\n");
    }

    return try buffer.toOwnedSlice();
}


fn escapeDotString(input: []u8, writer: anytype) !void {
    for (input) |c| {
        if (!std.ascii.isPrint(c)) {
            try writer.print("\\x{X:0>2}", .{c});
            continue;
        }
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\'' => try writer.writeAll("\\\'"),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
}

fn stringifyRegexs(alloc: std.mem.Allocator, parser: LexParser) ![]u8 {
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();

    const writer = buffer.writer();
    var cycler = ColorCycler{};

    for (parser.rules.items, 0..) |rule, it| {
        try writer.print("regex{d} [label=\"{0d}:", .{it});
        try escapeDotString(rule.regex, writer);
        try writer.print("\", style=\"filled\", fillcolor=\"{s}\"]\n", .{cycler.getColor(it)});
    }

    return try buffer.toOwnedSlice();
}


pub fn dotFormat(
    lexParser: LexParser,
    nfa: NFA,
    dfa: DFA,
    yy_ec: *[256]u8,
    output: anytype,
) void {
    const nfa_str = nfa.stringify(std.heap.page_allocator) catch return;
    const dfa_str = dfa.stringify(std.heap.page_allocator) catch return;
    const minified_dfa_str = dfa.minimizedStringify(std.heap.page_allocator) catch return;
    const class_set_str = stringifyClassSet(std.heap.page_allocator, yy_ec) catch return;
    const regex_str = stringifyRegexs(std.heap.page_allocator, lexParser) catch return;
    defer {
        std.heap.page_allocator.free(class_set_str);
        std.heap.page_allocator.free(nfa_str);
        std.heap.page_allocator.free(regex_str);
        std.heap.page_allocator.free(dfa_str);
    }
    output.print(format, .{
        minified_dfa_str,
        dfa_str,
        regex_str,
        nfa_str,
        class_set_str
    }) catch return;
}
