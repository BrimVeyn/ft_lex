const std           = @import("std");
const ParserModule  = @import("Parser.zig");
const ParserMakers  = @import("ParserMakers.zig");
const NFADump       = @import("NFADump.zig");

pub const StateId = usize;

pub const NFA_LIMIT = 32_000;
pub const RECURSION_LIMIT = 10_000;

pub const Transition = struct {
    symbol: ?u8,
    to: *State,
};

pub const State = struct {
    id: StateId,
    transitions: std.ArrayList(Transition),
};

pub const NFAError = error {
    NFAUnhandled,
    NFATooComplicated,
} || error { OutOfMemory };

pub const NFA = struct {
    start: *State,
    accept: *State,
    lookAhead: ?*NFA = null,
    matchStart: bool = false,
    matchEnd: bool = false,
    start_condition: ?[64:0]u8 = null,

    pub const stringify = NFADump.stringify;
};

pub const NFABuilder = struct {
    state_list: std.ArrayListUnmanaged(*State),
    alloc: std.mem.Allocator,
    next_id: StateId = 1,
    depth: usize = 0,
    //Parser is need to allocate more RegexNodes when its needed
    parser: *ParserModule.Parser,

    pub fn init(alloc: std.mem.Allocator, parser: *ParserModule.Parser) !NFABuilder {
        return .{
            .state_list = try std.ArrayListUnmanaged(*State).initCapacity(alloc, 10),
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

    pub fn makeState(self: *NFABuilder, id: StateId) !*State {
        const node = try self.alloc.create(State);
        node.* = .{
            .id = id,
            .transitions = std.ArrayList(Transition).init(self.alloc),
        };
        try self.state_list.append(self.alloc, node);
        return node;
    }

    pub fn astToNfa(self: *NFABuilder, node: *ParserModule.RegexNode) NFAError!NFA {
        self.depth += 1;
        //NOTE: Avoid infinite recursion
        if (self.next_id > NFA_LIMIT or self.depth > RECURSION_LIMIT) {
            return error.NFATooComplicated;
        }

        return switch (node.*) {
            .Group => {
                return try self.astToNfa(node.Group);
            },
            .AnchorStart => {
                std.debug.assert(self.depth == 1);
                var inner: NFA = undefined;
                //If we know that anchorEnd is also active, parse its child directly so we can trigger
                //both matchStart and matchEnd on the root node.
                if (std.meta.activeTag(node.AnchorStart.*) == ParserModule.RegexNode.AnchorEnd) {
                    inner = try self.astToNfa(node.AnchorStart.AnchorEnd);
                    inner.matchStart = true;
                    inner.matchEnd = true;
                } else {
                    inner = try self.astToNfa(node.AnchorStart);
                    inner.matchStart = true;
                }

                return inner;
            },
            .StartCondition => {
                var inner: NFA = undefined;
                //Same applies here, if we know that it child has AnchorStart, we check for its child it has AnchorEnd 
                //and update the inner NFA accordingly
                if (std.meta.activeTag(node.StartCondition.left.*) == ParserModule.RegexNode.AnchorStart
                    and std.meta.activeTag(node.StartCondition.left.AnchorStart.*) == ParserModule.RegexNode.AnchorEnd) {
                    inner = try self.astToNfa(node.StartCondition.left.AnchorStart.AnchorEnd);
                    inner.matchStart = true;
                    inner.matchEnd = true;
                } else if (std.meta.activeTag(node.StartCondition.left.*) == ParserModule.RegexNode.AnchorStart) {
                    inner = try self.astToNfa(node.StartCondition.left.AnchorStart);
                    inner.matchStart = true;
                } else {
                    inner = try self.astToNfa(node.StartCondition.left);
                }

                inner.start_condition = .{0} ** 64;
                @memcpy(inner.start_condition.?[0..], node.StartCondition.name[0..]);
                return inner;
            },
            .AnchorEnd => {
                std.debug.assert(self.depth == 1);
                var inner = try self.astToNfa(node.AnchorEnd);
                inner.matchEnd = true;
                return inner;
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
            // else => {
            //     std.log.debug("Unhandled NFA transformation for regexNode of type: {s}", .{@tagName(node.*)});
            //     return error.NFAUnhandled;
            // }
        };
    }

    pub fn merge(self: *NFABuilder, NFAs: []NFA) !NFA {
        if (NFAs.len == 1) 
            return NFAs[0];

        const start = try self.makeState(0);
        const accept = try self.makeState(self.next_id);
        self.next_id += 1;

        for (NFAs) |inner| {
            try start.transitions.append(.{ .symbol = null, .to = inner.start});
            try inner.accept.transitions.append(.{.symbol = null, .to = accept});
        }

        return NFA{.start = start, .accept = accept };
    }
};
