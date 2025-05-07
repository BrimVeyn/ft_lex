const std           = @import("std");
const ParserModule  = @import("Parser.zig");
const ParserMakers  = @import("ParserMakers.zig");
const NFADump       = @import("NFADump.zig");
const DFAModule     = @import("DFA.zig");
const DFA           = DFAModule.DFA;
pub const StateId   = usize;


pub const NFA_LIMIT = 32_000;
pub const RECURSION_LIMIT = 10_000;

pub const Symbol = union(enum) {
    char: u8,
    ec: u8,
    epsilon: void,

    pub fn eql(lhs: Symbol, rhs: Symbol) bool {
        if (std.meta.activeTag(lhs) != std.meta.activeTag(rhs))
            return false;

        return switch (lhs) {
            .char => |c| c == rhs.char,
            .epsilon => true,
            .ec => |ec| ec == rhs.ec,
        };
    }

    /// Should only be used in DFA (no epsilon transitions)
    pub fn lessThanFn(_: void, a: Symbol, b: Symbol) bool {
        const tagA = std.meta.activeTag(a);
        const tagB = std.meta.activeTag(b);

        if (tagA == .char and tagB == .ec) return true;
        if (tagA == .ec and tagB == .char) return false;
        if (tagA == .ec and tagB == .ec) {
            return (a.ec < b.ec);
        } else {
            return (a.char < b.char);
        }
    }
};

pub const Transition = struct {
    symbol: Symbol,
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
    yy_ec: *[256]u8,

    pub fn init(alloc: std.mem.Allocator, parser: *ParserModule.Parser, yy_ec: *[256]u8) !NFABuilder {
        return .{
            .state_list = try std.ArrayListUnmanaged(*State).initCapacity(alloc, 10),
            .alloc = alloc,
            .parser = parser,
            .yy_ec = yy_ec,
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

                try start.transitions.append(.{ .symbol = .{ .char = node.Char }, .to = accept });
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

                try start.transitions.append(.{.symbol = .{ .epsilon = {} }, .to = left_nfa.start });
                try start.transitions.append(.{.symbol = .{ .epsilon = {} }, .to = right_nfa.start });

                try left_nfa.accept.transitions.append(.{.symbol = .{ .epsilon = {} }, .to = accept });
                try right_nfa.accept.transitions.append(.{.symbol = .{ .epsilon = {} }, .to = accept });
                return NFA { .start = start, .accept = accept};
            },
            .CharClass => |class| {
                const start = try self.makeState(self.next_id);
                self.next_id += 1;
                var accept = try self.makeState(self.next_id);

                var used_classes = std.StaticBitSet(256).initEmpty();
                for (0..256) |i| {
                    const iU8: u8 = @intCast(i);
                    if ((!class.negate and class.range.isSet(iU8)) or
                        (class.negate and !class.range.isSet(iU8))
                    ) {
                        const ec = self.yy_ec[iU8];
                        //NOTE: ec 0 is reserved for \x00 and canno't be matched, even with negated classes
                        if (ec == 0) 
                            continue;
                        used_classes.set(ec);
                    }
                }

                var used_it = used_classes.iterator(.{});
                // std.debug.print("classes:\n", .{});
                while (used_it.next()) |ec_id| {
                    const ec: u8 = @intCast(ec_id);
                    // std.debug.print("CLASSES: {d}\n", .{ec});
                    try start.transitions.append(.{.symbol = .{ .ec = ec }, .to = accept });
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

                    try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner_nfa.start});
                    try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = accept});

                    try inner_nfa.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner_nfa.start });
                    try inner_nfa.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = accept });

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
                            try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner_nfa.start });
                        }
                        if (maybePrev) |prev| {
                            try prev.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner_nfa.start });
                        }
                        if (i + 1 >= node.Repetition.min) {
                            try inner_nfa.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = accept });
                        }
                        maybePrev = inner_nfa;
                    }

                    accept.id = self.next_id;
                    self.next_id += 1;

                    if (node.Repetition.min == 0) {
                        try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = accept });
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
                            try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner_nfa.start });
                        }
                        if (maybePrev) |prev| {
                            try prev.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner_nfa.start });
                        }
                        maybePrev = inner_nfa;
                    }

                    accept.id = self.next_id;
                    self.next_id += 1;

                    try maybePrev.?.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = maybePrev.?.start });
                    try maybePrev.?.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = accept });

                    return NFA { .start = start, .accept = accept };

                }
            },
            // else => {
            //     std.log.debug("Unhandled NFA transformation for regexNode of type: {s}", .{@tagName(node.*)});
            //     return error.NFAUnhandled;
            // }
        };
    }

    pub fn merge(self: *NFABuilder, NFAs: []NFA) !struct { NFA, std.ArrayList(DFA.AcceptState) } {
        var acceptList = std.ArrayList(DFA.AcceptState).init(self.alloc);
        errdefer acceptList.deinit();

        const start = try self.makeState(0);
        self.next_id += 1;

        for (NFAs, 0..) |inner, it| {
            try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner.start});
            try acceptList.append(.{ .state = inner.accept, .priority = it });
        }

        return .{
            NFA{.start = start, .accept = NFAs[0].accept },
            acceptList,
        };
    }
};
