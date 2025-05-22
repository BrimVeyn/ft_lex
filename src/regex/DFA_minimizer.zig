const std           = @import("std");
const DFAModule     = @import("DFA.zig");
const DFA           = DFAModule.DFA;
const StateSet      = DFAModule.StateSet;

const NFAModule     = @import("NFA.zig");
const State         = NFAModule.State;
const Transition    = NFAModule.Transition;
const NFA           = NFAModule.NFA;
const Symbol        = NFAModule.Symbol;

const stderr        = std.io.getStdErr();
const DFAMinimizer  = @This();

//This global variable is used to pad a DFA with x offset
//meaning that we can safely merge different branches later on
pub var offset: usize = 0;

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

    pub fn deinit(self: *Signature) void { self.data.deinit(); }
    pub fn append(self: *Signature, item: SignatureTransition) !void { try self.data.append(item); }

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

pub const Partition = struct {
    const StateSetSet   = std.AutoArrayHashMap(*StateSet, void);

    pub const PartitionData = struct {
        set: StateSetSet,
        signature: ?Signature,
        accept_id: ?usize,
    };

    data: std.ArrayList(PartitionData),

    pub fn init(alloc: std.mem.Allocator) Partition {
        return .{ .data = std.ArrayList(PartitionData).init(alloc) };
    }

    pub fn append(self: *Partition, item: PartitionData) !void {
        try self.data.append(item);
    }

    pub fn appendSlice(self: *Partition, items: []PartitionData) !void {
        try self.data.appendSlice(items);
    }

    pub fn deinit(self: *Partition) void {
        defer self.data.deinit();
        for (self.data.items) |*G| {
            if (G.signature) |*sig| sig.deinit();
            G.set.deinit();
        }
    }

    pub fn dump(self: Partition, table: DFA.DfaTable) !void {
        var writer = stderr.writer();
        for (self.data.items, 0..) |Pdata, i| {
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
};

fn repositionD0(table: DFA.DfaTable, P: *Partition) void {
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

    for (P.data.items) |G| {
        for (G.signature.?.data.items) |*t| {
            if (t.group_id == d0_index + @This().offset) { t.group_id = @This().offset; }
            else if (t.group_id == @This().offset) { t.group_id = d0_index + @This().offset; }
        }
    }

    const tmp = P.data.items[d0_index];
    P.data.items[d0_index] = P.data.items[0];
    P.data.items[0] = tmp;
}

pub fn minimize(self: *DFA) !void {
    self.offset = @This().offset;

    var P = Partition.init(self.alloc);
    var NonASet = Partition.StateSetSet.init(self.alloc);

    var stateIt = self.data.iterator();
    while (stateIt.next()) |entry| {
        if (entry.value_ptr.accept_id) |accept_id| {
            const maybe_idx = blk: {
                for (P.data.items, 0..) |G, i|
                if (G.accept_id == accept_id) break: blk i;
                break :blk null;
            };

            if (maybe_idx) |idx| {
                try P.data.items[idx].set.put(entry.key_ptr, {});
            } else {
                var newSet = Partition.StateSetSet.init(self.alloc);
                try newSet.put(entry.key_ptr, {});
                try P.append(.{ .set = newSet, .signature = null, .accept_id = accept_id });
            }
        } else {
            try NonASet.put(entry.key_ptr, {});
        }
    }
    if (NonASet.count() == 0) { NonASet.deinit(); } 
    else { try P.append(.{ .set = NonASet, .signature = null, .accept_id = null }); }

    // std.debug.print("PARTITION: \n", .{});
    // try P.dump(self.data);

    var some: usize = 0;
    while (some < 10000) :(some += 1) {
        var P_new = Partition.init(self.alloc);
        defer {
            P.deinit();
            P = P_new;
        }
        for (P.data.items, 0..) |Pdata, gI| {
            _ = gI;
            const G = Pdata.set;

            for (G.keys()) |set| {
                const SdataId = self.data.getIndex(set.*).?;
                _ = SdataId;

                const Sdata = self.data.get(set.*).?;
                var signature = Signature.init(self.alloc, Pdata.accept_id);

                for (Sdata.transitions.items) |transition| {
                    const transition_to_ptr = self.data.getKeyPtr(transition.to).?;
                    const g_id = getGroupIdFromSet(P, transition_to_ptr) + @This().offset;
                    try signature.append(.{ .symbol = transition.symbol, .group_id = g_id });
                }
                signature.sort();

                const g_id = getGroupIdFromSignature(P_new, signature);
                if (g_id == null) {
                    var Nset = Partition.StateSetSet.init(self.alloc);
                    try Nset.put(set, {});
                    try P_new.append(.{ .set = Nset, .signature = signature, .accept_id = Pdata.accept_id });
                } else {
                    try P_new.data.items[g_id.?].set.put(set, {});
                    //We can free this signature, since we already know it
                    signature.deinit();
                }
            }
        }
        if (P_new.data.items.len == P.data.items.len)
        break;
    }

    //Reposition d0 at index 0, so the minimized dfa starts with the group that contains d0
    repositionD0(self.data, &P);
    self.minimized = P;
    self.yy_accept = try self.getAcceptTable();
    @This().offset += self.minimized.?.data.items.len;
}
