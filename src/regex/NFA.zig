const std                 = @import("std");
const ParserMakers        = @import("ParserMakers.zig");
const NFADump             = @import("NFADump.zig");
const DFAModule           = @import("DFA.zig");
const Rules               = @import("../lex/Rules.zig");
const LexParser           = @import("../lex/Parser.zig");
const G                   = @import("../globals.zig");
const DFA                 = DFAModule.DFA;
const ArrayList           = std.ArrayList;

const ParserModule        = @import("Parser.zig");
const RegexNode           = ParserModule.RegexNode;

pub const StateId         = usize;
pub const NFA_LIMIT       = 32_000;
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
            .ec => |ec| ec == rhs.ec,
            .epsilon => true,
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

    pub fn clone(self: State, alloc: std.mem.Allocator) !*State {
        const ret = try alloc.create(State);
        ret.* = State {
            .id = self.id,
            .transitions = try self.transitions.clone(),
        };
        return ret;
    }
};

pub const NFAError = error {
    NFAUnhandled,
    NFATooComplicated,
} || error { OutOfMemory };

pub const NFA = struct {
    start          : *State,
    accept         : *State,
    parseTree      : *RegexNode = undefined,
    lookAhead      : ?*NFA = null,
    matchStart     : bool = false,

    pub const stringify = NFADump.stringify;

    fn lengthRec(parseTree: *RegexNode) ?usize {
        switch (parseTree.*) {
            .Char => return 1,
            .CharClass => return 1,
            .Concat => |e| {
                const l, const r = .{ lengthRec(e.left), lengthRec(e.right) };
                return if (l == null or r == null) null else l.? + r.?;
            },
            .Alternation => |e| {
                const l, const r = .{ lengthRec(e.left), lengthRec(e.right) };
                return if (l == null or r == null or l.? != r.?) null else l.?;
            },
            .Repetition => |e| return {
                if (e.max) |max| return if (max == e.min)
                    max * if (lengthRec(e.left)) |l| l else return null else null;
                return null;
            },
            .Group => |e| return lengthRec(e),
            .AnchorStart => |e| return lengthRec(e),
            .TrailingContext => |e| return lengthRec(e.left),
        }
    }

    pub fn length(self: NFA) ?usize {
        return lengthRec(self.parseTree);
    }
};

pub const NFABuilder = struct {
    state_list: std.ArrayListUnmanaged(*State),
    alloc     : std.mem.Allocator,
    tc_pool   : std.heap.MemoryPool(NFA),
    next_id   : StateId = 1,
    depth     : usize = 0,
    //Parser is needed to allocate more RegexNodes when necessary
    parser    : *ParserModule.Parser,
    yy_ec     : *const [256]u8,

    pub fn init(alloc: std.mem.Allocator, parser: *ParserModule.Parser, yy_ec: *const [256]u8) !NFABuilder {
        return .{
            .state_list = try std.ArrayListUnmanaged(*State).initCapacity(alloc, 1),
            .tc_pool = std.heap.MemoryPool(NFA).init(alloc),
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
        self.tc_pool.deinit();
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


    pub fn astToNfa(self: *NFABuilder, node: *RegexNode) NFAError!NFA {
        self.depth = 0;
        var nfa = try self.astToNfaRec(node);
        nfa.parseTree = node;
        return nfa;
    }

    pub fn astToNfaRec(self: *NFABuilder, node: *RegexNode) NFAError!NFA {
        self.depth += 1;

        if (self.next_id > NFA_LIMIT or self.depth > RECURSION_LIMIT)
            return error.NFATooComplicated;

        return switch (node.*) {
            .Group => {
                return try self.astToNfa(node.Group);
            },
            .AnchorStart => {
                std.debug.assert(self.depth == 1);
                var inner = try self.astToNfa(node.AnchorStart);
                inner.matchStart = true;
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
                const lookaheadNFA = try self.astToNfa(node.TrailingContext.right);

                const ptr = try self.tc_pool.create();
                ptr.* = lookaheadNFA;

                return NFA { .start = matchNFA.start, .accept = matchNFA.accept, .lookAhead = ptr };
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
        };
    }

    //TODO: Remove this structure and add the fields inside the NFA struct
    pub const DFAFragment = struct {
        nfa: NFA,
        acceptList: []DFA.AcceptState,
        sc: usize = 0,
        trailingContextRuleId: ?usize = null,
    };

    pub fn merge(
        self: *NFABuilder,
        NFAs: []NFA, 
        lexParser: LexParser
    ) !struct { 
        ArrayList(DFAFragment),
        ArrayList(DFAFragment),
        ArrayList(DFAFragment),
    } {

        var merged_NFAs    = ArrayList(DFAFragment).init(self.alloc);
        var bol_NFAs       = ArrayList(DFAFragment).init(self.alloc);
        var tc_NFAs        = ArrayList(DFAFragment).init(self.alloc);
        var acceptList     = ArrayList(DFA.AcceptState).init(self.alloc);
        var bol_acceptList = ArrayList(DFA.AcceptState).init(self.alloc);
        var tc_acceptList  = ArrayList(DFA.AcceptState).init(self.alloc);
        errdefer {
            merged_NFAs.deinit(); bol_NFAs.deinit();
            acceptList.deinit(); bol_acceptList.deinit();
        }

        for (NFAs, lexParser.rules.items, 0..) |inner, *rule, it| {
            if (inner.lookAhead) |lookAhead| {
                //TODO: Determine if the trailing context and its rule are of arbitrary length.
                //If not we can omit the backtracking part of the matcher and add a precomputed backtracking in
                //the action associated with the rule.
                if (inner.length()) |len| {
                    std.log.info("INNER LEN: {d}", .{len});
                    rule.trailingContext = .{ .side = .Left, .value = len, };
                } else if (lookAhead.length()) |len| {
                    std.log.info("LOOKAHEAD LEN: {d}", .{len});
                    rule.trailingContext = .{ .side = .Right, .value = len };
                } else {
                    std.log.info("Both are of variable length", .{});
                    G.options.needTcBacktracking = true;
                }

                var start = try self.makeState(0);
                try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner.start});
                try tc_acceptList.append(.{ .state = inner.accept, .priority = it });
                try tc_NFAs.append(.{
                    .nfa = .{
                        .start = start,
                        .accept = NFAs[0].accept
                    },
                    .acceptList = try tc_acceptList.toOwnedSlice(),
                    .trailingContextRuleId = it,
                });
            }
        }

        self.next_id += 1;
        for (lexParser.definitions.startConditions.data.items, 0..) |sc, scId| {
            var start, var bol_start = .{ try self.makeState(0), try self.makeState(0) };
            for (NFAs, lexParser.rules.items, 0..) |inner, rule, it| {
                const found = blk: {
                    if (sc.type == .Inclusive and rule.sc.items.len == 0) break: blk true;
                    for (rule.sc.items) |c| if (std.mem.eql(u8, c.name, sc.name)) break: blk true;
                    break :blk false;
                };
                if (!found) continue;

                if (inner.matchStart == false and inner.lookAhead == null) {
                    try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner.start});
                    try acceptList.append(.{ .state = inner.accept, .priority = it });
                } else if (inner.lookAhead != null) {
                    try start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner.start});
                    try inner.accept.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner.lookAhead.?.start });
                    try acceptList.append(.{ .state = inner.lookAhead.?.accept, .priority = it });
                } else {
                    try bol_start.transitions.append(.{ .symbol = .{ .epsilon = {} }, .to = inner.start});
                    try bol_acceptList.append(.{ .state = inner.accept, .priority = it });
                }
            }

            try merged_NFAs.append(DFAFragment{
                .nfa = .{ 
                    .start = start,
                    .accept = if (acceptList.items.len != 0) NFAs[0].accept else start,
                },
                .acceptList = try acceptList.toOwnedSlice(),
                .sc = scId,
            });

            try bol_NFAs.append(DFAFragment{
                .nfa = .{ 
                    .start = bol_start,
                    .accept = if (bol_acceptList.items.len != 0) NFAs[0].accept else bol_start,
                },
                .acceptList = try bol_acceptList.toOwnedSlice(),
                .sc = scId,
            });
        }

        return .{
            merged_NFAs,
            bol_NFAs,
            tc_NFAs,
        };
    }
};
