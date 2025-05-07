const std           = @import("std");
const NFAModule     = @import("NFA.zig");
const State         = NFAModule.State;
const Transition    = NFAModule.Transition;
const NFA           = NFAModule.NFA;
const Symbol        = NFAModule.Symbol;
const stderr        = std.io.getStdErr();
const DFADump       = @import("DFADump.zig");

const DFATransition = struct {
    symbol: Symbol,
    to: StateSet,
};

const StateSetCtx = struct {
    pub fn hash(self: StateSetCtx, set: StateSet) u32 {
        _ = self;
        var h: u32 = 0;

        for (set.keys()) |state| {
            h ^= @as(u32, @intCast(state.id)); // XOR the state ids
        }

        return h;
    }

    pub fn eql(self: StateSetCtx, a: StateSet, b: StateSet, _: usize) bool {
        _ = self;
        if (a.count() != b.count()) 
            return false;

        for (a.keys()) |sA| {
            if (!b.contains(sA))
                return false;
        }
        return true;
    }
};

pub const Signature = struct {
    pub const SignatureTransition = struct {
        symbol: Symbol,
        group_id: usize,

        pub fn lessThanFn(_: void, a: SignatureTransition, b: SignatureTransition) bool {
            return Symbol.lessThanFn({}, a.symbol, b.symbol);
        }
    };
    data: std.ArrayList(SignatureTransition),
    accept_id: ?usize,

    pub fn dump(self: Signature) void {
        std.debug.print("SIG:\n", .{});
        for (self.data.items) |st| {
            std.debug.print("{?}: {}: {d}\n", .{self.accept_id, st.symbol, st.group_id});
        }
    }

    pub fn init(alloc: std.mem.Allocator, accept_id: ?usize) Signature {
        return .{ 
            .data = std.ArrayList(SignatureTransition).init(alloc),
            .accept_id = accept_id,
        };
    }

    pub fn deinit(self: *Signature) void {
        self.data.deinit();
    }

    pub fn sort(self: *Signature) void {
        std.mem.sort(SignatureTransition, self.data.items[0..], {}, SignatureTransition.lessThanFn);
    }

    pub fn eql(lhs: Signature, rhs: Signature) bool {
        if (lhs.data.items.len != rhs.data.items.len) return false;
        if (lhs.accept_id != rhs.accept_id) return false;
        for (lhs.data.items, 0..) |lst, it| {
            const rst = rhs.data.items[it];
            if (!Symbol.eql(lst.symbol, rst.symbol) or lst.group_id != rst.group_id) return false;
        }
        return true;
    }

    pub fn append(self: *Signature, item: SignatureTransition) !void {
        try self.data.append(item);
    }
};

fn getGroupIdFromSignature(P: Partition, s: Signature) ?usize {
    for (P.data.items, 0..) |Pdata, i| {
        std.debug.assert(Pdata.signature != null);
        if (Signature.eql(Pdata.signature.?, s)) return i;
    }
    return null;
}

fn getGroupIdFromSet(P: Partition, s: *StateSet) usize {
    for (P.data.items, 0..) |Pdata, i| {
        for (Pdata.set.keys()) |set| {
            if (set == s) return i;
        }
    }
    unreachable;
}

fn repositionD0(table: DfaTable, P: *Partition) void {
    const d0_index = blk: {
        for (P.data.items, 0..) |p, it| {
            for (p.set.keys()) |set| {
                const idx = table.getIndex(set.*).?;
                if (idx == 0) { 
                    //d0 is already at index 0, return unchanged
                    if (it == 0) return ;
                    break :blk it; 
                }
            }
        }
        unreachable;
    };

    std.log.info("D0 index: {d}", .{d0_index});

    for (P.data.items) |G| {
        for (G.signature.?.data.items) |*t| {
            if (t.group_id == d0_index) { t.group_id = 0; }
            else if (t.group_id == 0) { t.group_id = d0_index; }
        }
    }

    const tmp = P.data.items[d0_index];
    P.data.items[d0_index] = P.data.items[0];
    P.data.items[0] = tmp;

    std.debug.print("D0 in in group: {d}\n", .{d0_index});
}


const StateSetData = struct {
    transitions: std.ArrayList(DFATransition),
    accept_id: ?usize = null,
    
    pub fn init(alloc: std.mem.Allocator) StateSetData {
        return .{ .transitions = std.ArrayList(DFATransition).init(alloc), };
    }

    pub fn deinit(self: *StateSetData) void {
        self.transitions.deinit();
    }
};

const StateSet      = std.AutoArrayHashMap(*State, void);
const StateSetSet   = std.AutoArrayHashMap(*StateSet, void);

const Partition = struct {
    data: std.ArrayList(PartitionData),

    pub fn init(alloc: std.mem.Allocator) Partition {
        return .{ .data = std.ArrayList(PartitionData).init(alloc) };
    }

    pub fn append(self: *Partition, item: PartitionData) !void {
        try self.data.append(item);
    }

    pub fn deinit(self: *Partition) void {
        defer self.data.deinit();
        for (self.data.items) |*G| {
            if (G.signature) |*sig| sig.deinit();
            G.set.deinit();
        }
    }
};


const PartitionData = struct {
    set: StateSetSet,
    signature: ?Signature,
    accept_id: ?usize,
};

const DfaTable      = std.ArrayHashMap(StateSet, StateSetData, StateSetCtx, true);

pub fn printStateSet(self: StateSet) !void {
    var writer = stderr.writer();
    _ = try writer.write("{");
    for (self.keys(), 0..) |s, i| {
        if (i < self.keys().len - 1) {
            try writer.print("{d},", .{s.id});
        } else {
            try writer.print("{d}", .{s.id});
        }
    }
    _ = try writer.write("}\n");
}

pub const DFA = struct {
    alloc: std.mem.Allocator,
    data: DfaTable,
    minimized: Partition = undefined,
    accept_list: std.ArrayList(AcceptState),
    nfa_start: *State,
    yy_ec_highest: u8,

    pub const AcceptState = struct {
        state: *State,
        priority: usize,
    };

    pub fn init(
        alloc: std.mem.Allocator,
        nfa: NFA,
        accept_list: std.ArrayList(AcceptState),
        yy_ec_highest: u8
    ) DFA {
            return .{
                .alloc = alloc,
                .data = DfaTable.init(alloc),
                .nfa_start = nfa.start,
                .accept_list = accept_list,
                .yy_ec_highest = yy_ec_highest,
            };
    }

    pub fn deinit(self: *DFA) void {
        var dfa_it = self.data.iterator();
        defer {
            self.data.deinit();
            self.minimized.deinit();
        }

        while (dfa_it.next()) |entry| {
            entry.key_ptr.*.deinit();
            entry.value_ptr.*.deinit();
        }
    }

    pub const stringify = DFADump.stringify;
    pub const minimizedStringify = DFADump.minimizedStringify;

    fn getAcceptingRule(self: *DFA, set: StateSet) ?usize {
        var best: ?usize = null; 

        for (set.keys()) |s| {
            for (self.accept_list.items) |aState| {
                if (s.id == aState.state.id and (best == null or aState.priority < best.?)) {
                    best = aState.priority;
                }
            }
        }
        return best;
    }

    fn epsilon_closure(self: *DFA, states: StateSet) !StateSet {
        var closure = try states.clone();

        var stack = std.ArrayList(*State).init(self.alloc);
        defer stack.deinit();

        for (states.keys()) |s| try stack.append(s);

        while (stack.pop()) |current| {
            for (current.transitions.items) |t| {
                if (std.meta.activeTag(t.symbol) == .epsilon and !closure.contains(t.to)) {
                    try closure.put(t.to, {});
                    try stack.append(t.to);
                }
            }
        }

        return closure;
    }

    fn move(self: *DFA, states: StateSet, symbol: u8) !StateSet {
        var moves = StateSet.init(self.alloc);

        for (states.keys()) |s| {
            for (s.transitions.items) |t| {
                if (std.meta.activeTag(t.symbol) == .char and symbol == t.symbol.char) {
                    try moves.put(t.to, {});
                }
            }
        }
        return moves;
    }

    fn move_ec(self: *DFA, states: StateSet, ec: u8) !StateSet {
        var moves = StateSet.init(self.alloc);

        for (states.keys()) |s| {
            for (s.transitions.items) |t| {
                if (std.meta.activeTag(t.symbol) == .ec and ec == t.symbol.ec) {
                    try moves.put(t.to, {});
                }
            }
        }
        return moves;
    }

    pub fn subset_construction(self: *DFA) !void {
        var start_set = StateSet.init(self.alloc);
        defer start_set.deinit();
        try start_set.put(self.nfa_start, {});

        const start_closure = try self.epsilon_closure(start_set);

        var queue = std.ArrayList(StateSet).init(self.alloc);
        defer queue.deinit();

        try queue.append(start_closure);
        try self.data.put(start_closure, .{
            .transitions = std.ArrayList(DFATransition).init(self.alloc),
            .accept_id = self.getAcceptingRule(start_closure),
        });

        while (queue.pop()) |current_set| {
            // try printStateSet(current_set);
            for (0..256) |s| {
                const symbol: u8 = @intCast(s);
                var gotos = try self.move(current_set, symbol);
                defer gotos.deinit();

                if (gotos.count() == 0) 
                    continue;
                var closure = try self.epsilon_closure(gotos);

                if (!self.data.contains(closure)) {
                    try self.data.put(closure, .{
                        .transitions = std.ArrayList(DFATransition).init(self.alloc),
                        .accept_id = self.getAcceptingRule(closure),
                    });
                    try queue.append(closure);

                    const maybe_value = self.data.getPtr(current_set);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{ .symbol = .{ .char = symbol }, .to = closure });
                    } else unreachable;
                } else {
                    const maybe_value = self.data.getPtr(current_set);
                    const closure_ptr = self.data.getKeyPtr(closure);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{ .symbol = .{ .char = symbol }, .to = closure_ptr.?.* });
                    } else unreachable;
                    closure.deinit();
                }
            }
            //NOTE: Begin at id 1 since 0 is reserved for \x00
            for (1..self.yy_ec_highest + 1) |class_id| {
                const ec: u8 = @intCast(class_id);
                var gotos = try self.move_ec(current_set, ec);
                defer gotos.deinit();

                if (gotos.count() == 0) 
                    continue;
                var closure = try self.epsilon_closure(gotos);

                if (!self.data.contains(closure)) {
                    try self.data.put(closure, .{
                        .transitions = std.ArrayList(DFATransition).init(self.alloc),
                        .accept_id = self.getAcceptingRule(closure), 
                    });
                    try queue.append(closure);

                    const maybe_value = self.data.getPtr(current_set);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{.symbol = .{ .ec =  ec }, .to = closure });
                    } else unreachable;
                } else {
                    const maybe_value = self.data.getPtr(current_set);
                    const closure_ptr = self.data.getKeyPtr(closure);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{.symbol = .{ .ec = ec }, .to = closure_ptr.?.* });
                    } else unreachable;
                    closure.deinit();
                }
            }
        }
    }

    ///Using moore's algorithm
    pub fn minimize(self: *DFA) !void {
        var P = Partition.init(self.alloc);
        var Aset = StateSetSet.init(self.alloc);
        var NonASet = StateSetSet.init(self.alloc);

        var stateIt = self.data.iterator();
        while (stateIt.next()) |entry| {
            if (entry.value_ptr.accept_id != null) {
                try Aset.put(entry.key_ptr, {});
            } else {
                try NonASet.put(entry.key_ptr, {});
            }
        }
        try P.append(.{ .set = Aset, .signature = null, .accept_id = 0 });
        try P.append(.{ .set = NonASet, .signature = null, .accept_id = null });

        std.debug.print("PARTITION: \n", .{});
        try partitionDump(self.data, P);

        var some: usize = 0;
        while (some < 10000) :(some += 1) {
            var P_new = Partition.init(self.alloc);
            defer {
                P.deinit();
                P = P_new;
            }
            for (P.data.items, 0..) |Pdata, gI| {
                const G = Pdata.set;
                std.log.info("GROUP: {d}", .{gI});
                for (G.keys()) |set| {
                    const SdataId = self.data.getIndex(set.*).?;
                    const Sdata = self.data.get(set.*).?;
                    std.log.info("Evaluating signature for D:{d}", .{SdataId});
                    var signature = Signature.init(self.alloc, Pdata.accept_id);
                    for (Sdata.transitions.items) |transition| {
                        const transition_to_ptr = self.data.getKeyPtr(transition.to).?;
                        const g_id = getGroupIdFromSet(P, transition_to_ptr);
                        try signature.append(.{ .symbol = transition.symbol, .group_id = g_id });
                    }
                    signature.sort();
                    //Debug
                    signature.dump();
                    //
                    const g_id = getGroupIdFromSignature(P_new, signature);
                    std.debug.print("GID: {?}\n", .{g_id});
                    if (g_id == null) {
                        var Nset = StateSetSet.init(self.alloc);
                        try Nset.put(set, {});
                        try P_new.append(.{ .set = Nset, .signature = signature, .accept_id = Pdata.accept_id });
                    } else {
                        try P_new.data.items[g_id.?].set.put(set, {});
                        //We can free this signature, since we already know it
                        signature.deinit();
                    }
                }
            }
            std.log.info("OLD:", .{});
            try partitionDump(self.data, P);
            std.log.info("NEW:", .{});
            try partitionDump(self.data, P_new);
            if (P_new.data.items.len == P.data.items.len) {
                break;
            }
        }
        self.minimized = P;
        //Reposition d0 at index 0, so the minimized dfa starts with the group that contains d0
        repositionD0(self.data, &P);
    }
};

fn partitionDump(table: DfaTable, P: Partition) !void {
    var writer = stderr.writer();
    for (P.data.items, 0..) |Pdata, i| {
        const split = Pdata.set;
        try writer.print("{d}: {{ ", .{i});
        for (split.keys(), 0..) |set, inner_i| {
            const key = table.getIndex(set.*).?;
            if (inner_i == split.keys().len - 1) {
                try writer.print("{d} ", .{key});
            } else {
                try writer.print("{d}, ", .{key});
            }
        }
        _ = try writer.write("}\n");
    }
}
