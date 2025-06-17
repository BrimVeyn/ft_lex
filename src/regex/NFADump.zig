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
            switch (transition.symbol) {
                .char => |s| try writer.print("n{d} -> n{d} [label=\"{c}\"]\n", .{state.id, transition.to.id, if (std.ascii.isAlphanumeric(s)) s else '.'}),
                .epsilon => try writer.print("n{d} -> n{d} [label=\"{s}\" style=dashed]\n", .{state.id, transition.to.id, epsilon}),
                .ec => |ec| try writer.print("n{d} -> n{d} [label=\"EC:{d}\"]\n", .{state.id, transition.to.id, ec}),
            }
            try stack.append(transition.to);
            highestState = if (transition.to.id > highestState) transition.to.id else highestState;
        }
    }
    try writer.print("n{d} [shape=\"doublecircle\"]\n", .{highestState});
    return try buffer.toOwnedSlice();
}
