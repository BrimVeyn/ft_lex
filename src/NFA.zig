const std           = @import("std");
const ParserModule  = @import("Parser.zig");

pub const StatedId = usize;

pub const Transition = struct {
    symbol: ?u8,
    to: *State,
};

pub const State = struct {
    id: StatedId,
    transitions: std.ArrayList(Transition),
};

pub const NFA = struct {
    start: *State,
    accept: *State,

    const GraphFormat = enum {
        Human,
        Dot,
    };

    pub fn printStates(self: NFA, alloc: std.mem.Allocator, format: GraphFormat) !void {
        var visited = std.AutoHashMap(StatedId, bool).init(alloc);
        var stack = std.ArrayList(*State).init(alloc);
        defer {
            visited.deinit();
            stack.deinit();
        }

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
                        const symbol = if (transition.symbol) |s| &[1]u8{ s } else epsilon;
                        std.debug.print("{d} -> {d} [label=\"{s}\"]\n", .{state.id, transition.to.id, symbol});
                        try stack.append(transition.to);
                    }
                },
            }
        }
    }
};

pub const NFABuilder = struct {
    pool: std.heap.MemoryPool(State),
    alloc: std.mem.Allocator,
    ast_head: *ParserModule.RegexNode,
    next_id: StatedId = 0,



    pub fn init(alloc: std.mem.Allocator, AST: *ParserModule.RegexNode) !NFABuilder {
        return .{
            .pool = std.heap.MemoryPool(State).init(alloc),
            .ast_head = AST,
            .alloc = alloc,
        };
    }

    pub fn makeState(self: *NFABuilder, id: StatedId) !*State {
        const node = try self.pool.create();
        node.* = .{
            .id = id,
            .transitions = std.ArrayList(Transition).init(self.alloc),
        };
        self.next_id += 1;
        return node;
    }

    pub fn astToNfa(self: *NFABuilder, node: *ParserModule.RegexNode) !NFA {
        return switch (node.*) {
            .Char => {
                const start = try self.makeState(self.next_id);
                const accept = try self.makeState(self.next_id);

                try start.transitions.append(.{ .symbol = node.Char, .to = accept });
                return NFA { .start = start, .accept = accept};
            },
            .Repetition => {
                const start = try self.makeState(self.next_id);
                const accept = try self.makeState(self.next_id);

                const inner_nfa = try self.astToNfa(node.Repetition.left);

                try start.transitions.append(.{ .symbol = null, .to = inner_nfa.start});
                try start.transitions.append(.{ .symbol = null, .to = accept});

                try inner_nfa.accept.transitions.append(.{ .symbol = null, .to = inner_nfa.start });
                try inner_nfa.accept.transitions.append(.{ .symbol = null, .to = accept });

                return NFA{ .start = start, .accept = accept };
            },
            .Concat => {
                const left_nfa = try self.astToNfa(node.Concat.left);
                const right_nfa = try self.astToNfa(node.Concat.right);

                try left_nfa.accept.transitions.append(.{ .symbol = null, .to = right_nfa.start });

                return NFA{ .start = left_nfa.start, .accept = right_nfa.accept };
            },
            else => std.debug.panic("Unhandled NFA transformation for regexNode of type: {s}", .{@tagName(node.*)}),
        };
    }


};
