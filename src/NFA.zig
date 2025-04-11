const std           = @import("std");
const ParserModule  = @import("Parser.zig");
const ParserMakers   = @import("ParserMakers.zig");

pub const StatedId = usize;

pub const NFA_LIMIT = 32000;

pub const Transition = struct {
    symbol: ?u8,
    to: *State,
};

pub const State = struct {
    id: StatedId,
    transitions: std.ArrayList(Transition),
};


const NFAErrorSet = error {
    NFAUnhandled,
    NFATooComplicated,
};

pub const NFAError = NFAErrorSet || error { OutOfMemory };

pub const NFA = struct {
    start: *State,
    accept: *State,
    lookAhead: ?*NFA = null,

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
};

pub const NFABuilder = struct {
    state_list: std.ArrayListUnmanaged(*State),
    alloc: std.mem.Allocator,
    ast_head: *ParserModule.RegexNode,
    next_id: StatedId = 0,
    parser: *ParserModule.Parser,
    depth: usize = 0,

    pub fn init(alloc: std.mem.Allocator, AST: *ParserModule.RegexNode, parser: *ParserModule.Parser) !NFABuilder {
        return .{
            .state_list = try std.ArrayListUnmanaged(*State).initCapacity(alloc, 10),
            .ast_head = AST,
            .alloc = alloc,
            .parser = parser,
        };
    }

    pub fn deinit(self: *NFABuilder) void {
        for (self.state_list.items) |state| {
            state.transitions.deinit();
            self.alloc.destroy(state);
        }
        self.state_list.deinit(self.alloc);
    }

    pub fn makeState(self: *NFABuilder, id: StatedId) !*State {
        const node = try self.alloc.create(State);
        node.* = .{
            .id = id,
            .transitions = std.ArrayList(Transition).init(self.alloc),
        };
        try self.state_list.append(self.alloc, node);
        return node;
    }

    pub fn astToNfa(self: *NFABuilder, node: *ParserModule.RegexNode) NFAError!NFA {
        //NOTE: Avoid infinite recursion
        if (self.next_id > NFA_LIMIT) {
            return error.NFATooComplicated;
        }

        return switch (node.*) {
            .Group => {
                return try self.astToNfa(node.Group);
            },
            .Char => {
                const start = try self.makeState(self.next_id);
                self.next_id += 1;
                const accept = try self.makeState(self.next_id);
                self.next_id += 1;

                try start.transitions.append(.{ .symbol = node.Char, .to = accept });
                return NFA { .start = start, .accept = accept};
            },
            .TrailingContext => {
                const matchNFA = try self.astToNfa(node.TrailingContext.left);
                var lookaheadNFA = try self.astToNfa(node.TrailingContext.right);

                return NFA { .start = matchNFA.start, .accept = matchNFA.accept, .lookAhead = &lookaheadNFA };
            },
            .Concat => {
                var left_nfa = try self.astToNfa(node.Concat.left);
                const right_nfa = try self.astToNfa(node.Concat.right);

                left_nfa.accept.id = right_nfa.start.id;
                left_nfa.accept.transitions = try right_nfa.start.transitions.clone();

                // try left_nfa.accept.transitions.append(.{ .symbol = null, .to = right_nfa.start });

                return NFA{ .start = left_nfa.start, .accept = right_nfa.accept };
            },
            .Alternation => {
                const start = try self.makeState(self.next_id);
                self.next_id += 1;

                const left_nfa = try astToNfa(self, node.Alternation.left);
                const right_nfa = try astToNfa(self, node.Alternation.right);

                const accept = try self.makeState(self.next_id);
                self.next_id += 1;

                try start.transitions.append(.{.symbol = null, .to = left_nfa.start });
                try start.transitions.append(.{.symbol = null, .to = right_nfa.start });

                try left_nfa.accept.transitions.append(.{.symbol = null, .to = accept });
                try right_nfa.accept.transitions.append(.{.symbol = null, .to = accept });
                return NFA { .start = start, .accept = accept};
            },
            .CharClass => {
                const start = try self.makeState(self.next_id);
                self.next_id += 1;
                var accept = try self.makeState(self.next_id);

                for (0..256) |i| {
                    const iU8: u8 = @intCast(i);
                    if (node.CharClass.range.isSet(i)) {
                        const inner = try self.astToNfa(try ParserMakers.makeNode(self.parser, .{.Char = iU8}));
                        try start.transitions.append(.{.symbol = null, .to = inner.start });
                        try inner.accept.transitions.append(.{ .symbol = null, .to = accept });
                    }
                }

                accept.id = self.next_id;
                self.next_id += 1;

                return NFA { .start = start, .accept = accept };
            },
            .Repetition => {
                //NOTE: Kleene star
                if (node.Repetition.min == 0 and node.Repetition.max == ParserModule.INFINITY) {
                    const start = try self.makeState(self.next_id);
                    self.next_id += 1;

                    var accept = try self.makeState(self.next_id);
                    const inner_nfa = try self.astToNfa(node.Repetition.left);

                    accept.id = self.next_id;
                    self.next_id += 1;

                    try start.transitions.append(.{ .symbol = null, .to = inner_nfa.start});
                    try start.transitions.append(.{ .symbol = null, .to = accept});

                    try inner_nfa.accept.transitions.append(.{ .symbol = null, .to = inner_nfa.start });
                    try inner_nfa.accept.transitions.append(.{ .symbol = null, .to = accept });

                    return NFA{ .start = start, .accept = accept };
                //NOTE: A link between all nodes from i > min to the accept
                } else if (node.Repetition.max != ParserModule.INFINITY) {
                    const start = try self.makeState(self.next_id);
                    self.next_id += 1;

                    var accept = try self.makeState(self.next_id);

                    var maybePrev: ?NFA = null;

                    for (0..node.Repetition.max.?) |i| {
                        const inner_nfa = try self.astToNfa(node.Repetition.left);
                        if (i == 0) {
                            try start.transitions.append(.{ .symbol = null, .to = inner_nfa.start });
                        }
                        if (maybePrev) |prev| {
                            try prev.accept.transitions.append(.{ .symbol = null, .to = inner_nfa.start });
                        }
                        if (i + 1 >= node.Repetition.min) {
                            try inner_nfa.accept.transitions.append(.{ .symbol = null, .to = accept });
                        }
                        maybePrev = inner_nfa;
                    }

                    accept.id = self.next_id;
                    self.next_id += 1;

                    if (node.Repetition.min == 0) {
                        try start.transitions.append(.{ .symbol = null, .to = accept });
                    }

                    return NFA { .start = start, .accept = accept };
                //NOTE: repetition then KLeene star (min != 0 and max == INFINITY)
                } else {
                    const start = try self.makeState(self.next_id);
                    self.next_id += 1;

                    const accept = try self.makeState(self.next_id);

                    var maybePrev: ?NFA = null;

                    for (0..node.Repetition.min) |i| {
                        const inner_nfa = try self.astToNfa(node.Repetition.left);
                        if (i == 0) {
                            try start.transitions.append(.{ .symbol = null, .to = inner_nfa.start });
                        }
                        if (maybePrev) |prev| {
                            try prev.accept.transitions.append(.{ .symbol = null, .to = inner_nfa.start });
                        }
                        maybePrev = inner_nfa;
                    }

                    accept.id = self.next_id;
                    self.next_id += 1;

                    try maybePrev.?.accept.transitions.append(.{ .symbol = null, .to = maybePrev.?.start });
                    try maybePrev.?.accept.transitions.append(.{ .symbol = null, .to = accept });

                    return NFA { .start = start, .accept = accept };

                }
            },
            else => {
                std.log.debug("Unhandled NFA transformation for regexNode of type: {s}", .{@tagName(node.*)});
                return error.NFAUnhandled;
            }
        };
    }


};
