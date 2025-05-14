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
    pub fn hash(_: StateSetCtx, set: StateSet) u32 {
        var h: u32 = 0;

        for (set.keys()) |state| {
            h ^= @as(u32, @intCast(state.id)); // XOR the state ids
        }

        return h;
    }

    pub fn eql(_: StateSetCtx, a: StateSet, b: StateSet, _: usize) bool {
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
            if (t.group_id == d0_index) { t.group_id = 0; }
            else if (t.group_id == 0) { t.group_id = d0_index; }
        }
    }

    const tmp = P.data.items[d0_index];
    P.data.items[d0_index] = P.data.items[0];
    P.data.items[0] = tmp;
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

    pub const DfaTable = std.ArrayHashMap(StateSet, StateSetData, StateSetCtx, true);
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
        var NonASet = StateSetSet.init(self.alloc);

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
                    var newSet = StateSetSet.init(self.alloc);
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
                const G = Pdata.set;
                _ = gI;
                // std.log.info("GROUP: {d}", .{gI});
                for (G.keys()) |set| {
                    const SdataId = self.data.getIndex(set.*).?;
                    _ = SdataId;
                    const Sdata = self.data.get(set.*).?;
                    // std.log.info("Evaluating signature for D:{d}", .{SdataId});
                    var signature = Signature.init(self.alloc, Pdata.accept_id);
                    for (Sdata.transitions.items) |transition| {
                        const transition_to_ptr = self.data.getKeyPtr(transition.to).?;
                        const g_id = getGroupIdFromSet(P, transition_to_ptr);
                        try signature.append(.{ .symbol = transition.symbol, .group_id = g_id });
                    }
                    signature.sort();
                    //Debug
                    // signature.dump();
                    //
                    const g_id = getGroupIdFromSignature(P_new, signature);
                    // std.debug.print("GID: {?}\n", .{g_id});
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
            // std.log.info("OLD:", .{});
            // try P.dump(self.data);
            // std.log.info("NEW:", .{});
            // try P_new.dump(self.data);
            if (P_new.data.items.len == P.data.items.len) {
                break;
            }
        }
        //Reposition d0 at index 0, so the minimized dfa starts with the group that contains d0
        repositionD0(self.data, &P);
        self.minimized = P;
    }

    const TestTransTable = [_][6]u8 {
       [_]u8 { 0,  17,  19,  0,  0,  1, },
       [_]u8 { 0,  0,  4,  5,  0,  0, },
       [_]u8 { 0,  0, 16, 17,  0,  0, },
       [_]u8 { 11,  0,  0,  0, 12,  0, },
       [_]u8 { 9,  0,  0,  0,  0,  0, },
       [_]u8 { 6,  0,  0,  0,  0,  0, },
       [_]u8 { 0,  0,  0,  7,  0,  0, },
       [_]u8 { 0,  0,  0,  0,  0,  8, },
       [_]u8 { 0,  0,  0,  0,  0,  0, },
       [_]u8 { 0, 10,  0,  0,  0,  0, },
       [_]u8 { 0,  0,  0,  0,  0,  8, },
       [_]u8 { 0,  0,  0, 15,  0,  0, },
       [_]u8 { 0,  0,  0, 13, 14,  0, },
       [_]u8 { 0,  0,  0,  0,  0,  8, },
       [_]u8 { 0,  0,  0,  0,  0,  8, },
       [_]u8 { 0,  0,  0,  0,  0,  8, },
       [_]u8 { 0,  0,  0,  0, 19,  0, },
       [_]u8 { 0,  0,  0, 18,  0,  0, },
       [_]u8 { 0,  0,  0,  0,  0,  8, },
       [_]u8 { 0,  0,  0,  0,  0,  8, },
    };

    pub fn compress(self: *DFA) !void {
        try self.minimized.dump(self.data);

        //Keep track of the transition count to fill the yy_nxt array later
        var nTransition: usize = 0;

        var realTransTable = try std.ArrayList(std.ArrayList(?usize))
            .initCapacity(self.alloc, self.minimized.data.items.len);

        for (self.minimized.data.items, 0..) |state, i| {
            realTransTable.appendAssumeCapacity(try std.ArrayList(?usize).initCapacity(self.alloc, self.yy_ec_highest + 1));
            realTransTable.items[i].expandToCapacity();
            @memset(realTransTable.items[i].items[0..], null);

            nTransition += state.signature.?.data.items.len;
            for (state.signature.?.data.items) |transition| {
                realTransTable.items[i].items[transition.symbol.ec] = transition.group_id;
            }
        }

        //
        // nTransition = 0;
        // const testTransTable = blk: {
        //     var ret = try std.ArrayList(std.ArrayList(?usize))
        //         .initCapacity(self.alloc, TestTransTable.len);
        //     for (TestTransTable, 0..) |row, i| {
        //         ret.appendAssumeCapacity(try std.ArrayList(?usize).initCapacity(self.alloc, row.len));
        //         ret.items[i].expandToCapacity();
        //         @memset(ret.items[i].items[0..], null);
        //         for (row, 0..) |t, j| { 
        //             if (t != 0) { 
        //                 ret.items[i].items[j] = t;
        //                 nTransition += 1;
        //             }
        //         }
        //     }
        //     break: blk ret;
        // };

        // var default = try std.ArrayList(usize).initCapacity(self.alloc, TestTransTable.len);
        // default.expandToCapacity();

        const transTableLen = realTransTable.items.len;
        const transTable = realTransTable;

        transTableDump(transTable);

        var base = try std.ArrayList(usize).initCapacity(self.alloc, transTableLen);
        var next = try std.ArrayList(usize).initCapacity(self.alloc, transTableLen);
        var check = try std.ArrayList(usize).initCapacity(self.alloc, transTableLen);
        base.expandToCapacity();

        const padding = blk: {
            var count:usize = 0;
            for (transTable.items[0].items) |t| {
                if (t != null) break;
                try next.append(0);
                try check.append(0);
                count += 1;
            }
            break: blk count;
        };

        for (transTable.items[0..], 0..) |row, i| {
            var offset: usize = 0;

            const allNotNull: std.ArrayList(usize) = blk: {
                var ret = std.ArrayList(usize).init(self.alloc);
                for (row.items, 0..) |t, j| { if (t != null) try ret.append(j); }
                break: blk ret;
            };

            //For all rows above the current, check that all not null values have only zeroes above them
            //otherwise, increase offset by one until its true
            std.debug.print("{s}Need to check for {d}..{d}{s}\n", .{
                Red,
                0,
                i,
                Reset,
            });
            outer: while (true) {
                defer offset += 1;

                for (transTable.items[0..i], 0..) |aRow, indexLookup|  {
                    const aRowOffset = base.items[indexLookup];
                    // std.debug.print("{s}Arow[{d}], Offset: {d}{s}\n", .{
                    //     Green,
                    //     indexLookup,
                    //     aRowOffset,
                    //     Reset,
                    // });

                    for (allNotNull.items) |rowIndex| {
                        const realIndex = rowIndex + offset;
                        // std.debug.print("Off: {d}, Checking: {d}\n", .{offset, row.items[rowIndex].?});
                        // std.debug.print("RealIndex: {d}\n", .{realIndex});
                        if (realIndex < aRowOffset) {
                            // std.debug.print("pitfall 1\n", .{});
                            continue;
                        } else if (realIndex >= (aRow.items.len + aRowOffset)) {
                            // std.debug.print("pitfall 2\n", .{});
                            continue;
                        } else if (aRow.items[realIndex - aRowOffset] == null) {
                            // std.debug.print("pitfall 3\n", .{});
                            continue;
                        } else {
                            continue :outer;
                        }
                    }
                }
                base.items[i] = offset;
                break: outer;
            }
        }

        var globalOffset = padding;
        std.debug.print("nTransition: {d}\n", .{nTransition});
        std.debug.print("base: {any}\n", .{base.items});
        while (nTransition > 0) {
            var it: usize = 0;
            std.debug.print("offset: {d}\n", .{globalOffset});
            var caught: bool = false;
            while (it < transTable.items.len) {
                const rowOffset = base.items[it];
                const row = transTable.items[it];
                std.debug.print("Row: {any}\n", .{row.items});

                if (
                    globalOffset < rowOffset 
                    or globalOffset >= (row.items.len + rowOffset) 
                    or row.items[globalOffset - rowOffset] == null
                ) {
                    it += 1;
                } else {
                    nTransition -= 1;
                    try check.append(it);
                    try next.append(row.items[globalOffset - rowOffset].?);
                    std.debug.print("Caught: {d}\n", .{row.items[globalOffset - rowOffset].?});
                    globalOffset += 1;
                    caught = true;
                }
            }
            if (!caught) {
                std.debug.print("NOT FOUND\n", .{});
                try next.append(0);
                try check.append(0);
                globalOffset += 1;
            }
        }

        transTableDump(transTable);
        compressedTableDump(base, next, check);
    }
};

const Green         = "\x1b[32m"; // Green for Char and CharClass
const BrightGreen   = "\x1b[92m"; // Bright green for literal chars
const Yellow        = "\x1b[33m"; // Yellow for Concat and TrailingContext
const Cyan          = "\x1b[36m"; // Cyan for Repetition
const Blue          = "\x1b[34m"; // Blue for Alternation
const Magenta       = "\x1b[35m"; // Magenta for Groups
const Red           = "\x1b[31m"; // Red for Anchors
const White         = "\x1b[97m"; // White for label text
const Reset         = "\x1b[0m";  // Reset color

const VecUsize = std.ArrayList(usize);

fn compressedTableDump(base: VecUsize, next: VecUsize, check: VecUsize) void {
    const helper = struct {
        fn head(str: []const u8) void { std.debug.print("{s:10}:", .{str}); }
        fn body(table: VecUsize) void { for (table.items) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
        fn enumerate(max: usize) void { for (0..max) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
    };

    const maxLen = std.sort.max(
        usize, 
        &[_]usize{base.items.len, next.items.len, check.items.len},
        {}, std.sort.asc(usize)
    ).?;

    helper.head("index");
    helper.enumerate(maxLen);
    helper.head("base");
    helper.body(base);
    helper.head("next");
    helper.body(next);
    helper.head("check");
    helper.body(check);
}

fn transTableDump(table: std.ArrayList(std.ArrayList(?usize))) void {
    const helper = struct {
        fn head(str: []const u8) void { std.debug.print("{s:10}:", .{str}); }
        fn body(t: VecUsize) void { for (t.items) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
        fn enumerate(min:usize, max:usize) void { for (min..max) |i| std.debug.print("{d:4}", .{i}); std.debug.print("\n", .{}); }
    };

    helper.head("state/ec");
    helper.enumerate(0, table.items[0].items.len);
    for (table.items, 0..) |row, i| {
        var buffer:[100]u8 = .{0} ** 100;
        _ = std.fmt.bufPrint(&buffer, "{d:10}", .{i}) catch return ;
        helper.head(buffer[0..]);

        for (row.items) |maybe_t| {
            if (maybe_t) |t| {
                std.debug.print("{d:4}", .{t});
            } else {
                std.debug.print("{s}{d:4}{s}", .{Red, 0, Reset});
            }
        }
        std.debug.print("\n", .{});
    }
}

// fn nextState(state: usize, symbol: u8) usize {
//     const index: usize = cDFA.base[state] + symbol;
//     if (cDFA.check[index] == state) {
//         return cDFA.next[index];
//     } else return 0;
// }

