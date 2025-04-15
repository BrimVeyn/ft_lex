const std           = @import("std");
const NFAModule     = @import("NFA.zig");
const GraphFormat   = NFAModule.NFA.GraphFormat;
const NFA           = NFAModule.NFA;
const StateId      = NFAModule.StateId;
const State         = NFAModule.State;

pub fn printStates(self: NFA, alloc: std.mem.Allocator, format: GraphFormat) !void {
    var visited = std.AutoHashMap(StateId, bool).init(alloc);
    var stack = std.ArrayList(*State).init(alloc);
    defer {
        visited.deinit();
        stack.deinit();
    }

    var highestState: usize = 0;

    try stack.append(self.start);
    switch (format) {
        .Human => std.debug.print("-----Transition in human readable format ------\n", .{}),
        .Dot => std.debug.print("---------Transitions in Dot format---------------\n", .{}),
    }

    while (stack.pop()) |state| {
        if (visited.contains(state.id)) 
        continue;
        try visited.put(state.id, true); 
        switch (format) {
            .Human => {
                std.debug.print("State {}:\n", .{state.id});

                if (state.transitions.items.len == 0) {
                    std.debug.print("  Accept\n", .{});
                }

                for (state.transitions.items) |t| {
                    const symbol = if (t.symbol) |s| s else '.';
                    std.debug.print("  -[{c}]-> {}\n", .{symbol, t.to.id});
                    try stack.append(t.to);
                }
            },
            .Dot => {
                for (state.transitions.items) |transition| {
                    const epsilon = "ε";
                    const symbol = if (transition.symbol) |s| blk: {
                        if (s == '\\') break: blk &[2]u8 { s, s };
                        break: blk &[1]u8 { s };
                    } else epsilon;
                    if (transition.symbol != null) {
                        std.debug.print("{d} -> {d} [label=\"{s}\"]\n", .{state.id, transition.to.id, symbol});
                    } else {
                        std.debug.print("{d} -> {d} [label=\"{s}\" style=dashed]\n", .{state.id, transition.to.id, symbol});
                    }
                    try stack.append(transition.to);
                    highestState = if (transition.to.id > highestState) transition.to.id else highestState;
                }
            },
        }
    }
    switch (format) {
        .Human => {},
        .Dot => std.debug.print("{d} [shape=\"doublecircle\"]\n", .{highestState}),
    }
}
