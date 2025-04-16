const std           = @import("std");
const NFAModule     = @import("NFA.zig");
const GraphFormat   = NFAModule.NFA.GraphFormat;
const NFA           = NFAModule.NFA;
const StateId      = NFAModule.StateId;
const State         = NFAModule.State;

pub fn stringify(self: NFA, alloc: std.mem.Allocator) ![]u8 {
    var visited = std.AutoHashMap(StateId, bool).init(alloc);
    var stack = std.ArrayList(*State).init(alloc);
    var buffer = std.ArrayList(u8).init(alloc);
    var writer = buffer.writer();
    defer {
        visited.deinit();
        stack.deinit();
        buffer.deinit();
    }

    var highestState: usize = 0;

    try stack.append(self.start);

    while (stack.pop()) |state| {
        if (visited.contains(state.id)) 
        continue;
        try visited.put(state.id, true); 

        for (state.transitions.items) |transition| {
            const epsilon = "ε";
            const symbol = if (transition.symbol) |s| blk: {
                if (s == '\\') break: blk &[2]u8 { s, s };
                break: blk &[1]u8 { s };
            } else epsilon;
            if (transition.symbol != null) {
                try writer.print("n{d} -> n{d} [label=\"{s}\"]\n", .{state.id, transition.to.id, symbol});
            } else {
                try writer.print("n{d} -> n{d} [label=\"{s}\" style=dashed]\n", .{state.id, transition.to.id, symbol});
            }
            try stack.append(transition.to);
            highestState = if (transition.to.id > highestState) transition.to.id else highestState;
        }
    }
    try writer.print("n{d} [shape=\"doublecircle\"]\n", .{highestState});
    return try buffer.toOwnedSlice();
}
