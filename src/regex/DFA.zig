const std                   = @import("std");
const ArrayList             = std.ArrayList;
const ArrayListUnmanaged    = std.ArrayListUnmanaged;
const stderr                = std.io.getStdErr();

const NFAModule             = @import("NFA.zig");
const DFAFragment           = NFAModule.NFABuilder.DFAFragment;
const State                 = NFAModule.State;
const Transition            = NFAModule.Transition;
const NFA                   = NFAModule.NFA;
const Symbol                = NFAModule.Symbol;

const DFADump               = @import("DFADump.zig");
const DFAMinimizer          = @import("DFA_minimizer.zig");
const Partition             = DFAMinimizer.Partition;

const EC                    = @import("EquivalenceClasses.zig");

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

pub const StateSet      = std.AutoArrayHashMap(*State, void);

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
    const TransitionTable = ArrayList(ArrayList(i16));
    const CompressedTransitionTable = struct {
        base: []i16,
        check: []i16,
        next: []i16,
        default: []i16,
    };

    pub const DfaTable = std.ArrayHashMap(StateSet, StateSetData, StateSetCtx, true);
    pub const AcceptState = struct {
        state: *State,
        priority: usize,
    };

    alloc: std.mem.Allocator,
    epsilon_cache: std.AutoHashMap(StateSet, StateSet) = undefined,
    data: DfaTable = undefined,
    minimized: ?Partition = null,
    accept_list: []AcceptState = undefined,
    transTable: ?TransitionTable = null,
    cTransTable: ?CompressedTransitionTable = null,
    nfa_start: *State = undefined,
    yy_ec_highest: u8 = 0,
    yy_accept: ?[]i16 = null,
    offset: usize = 0,


    pub fn buildFromNFA(alloc: std.mem.Allocator, nfa: NFA, acceptList: []AcceptState, maxEc: u8) !DFA {
        var dfa = DFA.init(alloc, nfa, acceptList, maxEc);

        try dfa.subset_construction();
        try dfa.minimize();
        //HACK: The compression in unnecessary here and for debug purpose only
        // try dfa.compress();

        return dfa;
    }

    pub fn buildEmptyDFa(alloc: std.mem.Allocator, maxEc: u8) !DFA {
        const nfa = try NFAModule.NFABuilder.initEmpty(alloc);
        var dummy_al = try std.ArrayListUnmanaged(DFA.AcceptState).initCapacity(alloc, 1);
        defer dummy_al.deinit(alloc);
        return buildFromNFA(alloc, nfa, try dummy_al.toOwnedSlice(alloc), maxEc);
    }

    pub fn init(
        alloc: std.mem.Allocator,
        nfa: NFA,
        accept_list: []AcceptState,
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
        defer {
            self.data.deinit();
            if (self.minimized) |*m| m.deinit();
            if (self.yy_accept) |a| self.alloc.free(a);
        }

        var dfa_it = self.data.iterator();
        while (dfa_it.next()) |entry| {
            entry.key_ptr.*.deinit();
            entry.value_ptr.*.deinit();
        }
        if (self.cTransTable) |ctt| {
            self.alloc.free(ctt.next);
            self.alloc.free(ctt.base);
            self.alloc.free(ctt.check);
            self.alloc.free(ctt.default);
        }
        if (self.transTable) |tt| {
            for (tt.items) |row| row.deinit();
            tt.deinit();
        }
    }

    pub fn mergedDeinit(self: *DFA) void {
        self.alloc.free(self.accept_list);
        self.minimized.?.data.deinit();

        if (self.cTransTable) |ctt| {
            self.alloc.free(ctt.next);
            self.alloc.free(ctt.base);
            self.alloc.free(ctt.check);
            self.alloc.free(ctt.default);
        }
        if (self.transTable) |tt| {
            for (tt.items) |row| row.deinit();
            tt.deinit();
        }
        if (self.yy_accept) |a| self.alloc.free(a);
    }

    pub const stringify = DFADump.stringify;
    pub const minimizedStringify = DFADump.minimizedStringify;

    fn getAcceptingRule(self: *DFA, set: StateSet) ?usize {
        var best: ?usize = null; 

        for (set.keys()) |s| {
            for (self.accept_list) |aState| {
                if (s.id == aState.state.id and (best == null or aState.priority < best.?)) {
                    best = aState.priority;
                }
            }
        }
        return best;
    }

    inline fn epsilon_closure(self: *DFA, states: StateSet) !StateSet {
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

    inline fn move(self: *DFA, states: StateSet, symbol: u8) !StateSet {
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

    inline fn move_ec(self: *DFA, states: StateSet, ec: u8) !StateSet {
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
        // self.epsilon_cache = std.AutoHashMap(StateSet, StateSet).init(self.alloc);
        // defer self.epsilon_cache.deinit();

        while (queue.pop()) |current_set| {
            //NOTE: Begin at id 1 since 0 is reserved for \x00
            for (1..self.yy_ec_highest + 1) |class_id| {
                const ec: u8 = @intCast(class_id);
                var gotos = try self.move_ec(current_set, ec);
                defer gotos.deinit();

                if (gotos.count() == 0) continue;

                var closure = try self.epsilon_closure(gotos);

                // const closure = self.epsilon_cache.get(gotos) orelse try self.epsilon_closure(gotos);
                // try self.epsilon_cache.put(gotos, closure);

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

    //TODO: remove this strcucture and store sc, and tc fields in DFA
    pub const DFA_SC = struct {
        dfa: DFA,
        sc: usize,
        trailingContextRuleId: ?usize = null,
    };

    pub const minimize = DFAMinimizer.minimize;

    pub fn buildAndMergeFromNFAs(
        alloc: std.mem.Allocator,
        mergedNFAs: ArrayList(DFAFragment),
        bolMergedNFAs: ArrayList(DFAFragment),
        tcNFAs: ArrayList(DFAFragment),
        ec: EC,
    ) !struct {
        DFA,
        ArrayListUnmanaged(DFA_SC),
        ArrayListUnmanaged(DFA_SC),
        ArrayListUnmanaged(DFA_SC),
    } {
        var DFAs = try ArrayListUnmanaged(DFA_SC).initCapacity(alloc, mergedNFAs.items.len);
        var bol_DFAs = try ArrayListUnmanaged(DFA_SC).initCapacity(alloc, 1);
        var tc_DFAs = try ArrayListUnmanaged(DFA_SC).initCapacity(alloc, 1);
        errdefer {
            DFAs.deinit(alloc);
            bol_DFAs.deinit(alloc);
            tc_DFAs.deinit(alloc);
        }

        for (mergedNFAs.items, 0..) |nfa, it| {
            _ = it;
            // std.debug.print("[NORMAL] DFA {d}\n\n", .{it});
            const dfa = try DFA.buildFromNFA(alloc, nfa.nfa, nfa.acceptList, ec.maxEc);
            try DFAs.append(alloc, .{ .dfa = dfa, .sc = nfa.sc });
        }

        for (bolMergedNFAs.items, 0..) |nfa, it| {
            _ = it;
            // std.debug.print("[BOL] DFA {d}\n\n", .{it});
            // std.debug.print("{s}\n", .{try nfa.nfa.stringify(alloc)});
            const dfa = try DFA.buildFromNFA(alloc, nfa.nfa, nfa.acceptList, ec.maxEc);
            try bol_DFAs.append(alloc, .{ .dfa = dfa, .sc = nfa.sc });
        }

        for (tcNFAs.items) |nfa| {
            const dfa = try DFA.buildFromNFA(alloc, nfa.nfa, nfa.acceptList, ec.maxEc);
            try tc_DFAs.append(alloc, .{ .dfa = dfa, .sc = nfa.sc, .trailingContextRuleId = nfa.trailingContextRuleId.? });
        }

        const finalDfa = try merge(DFAs, bol_DFAs, tc_DFAs);
        return .{ finalDfa, DFAs, bol_DFAs, tc_DFAs };
    }

    pub fn merge(
        DFAs: ArrayListUnmanaged(DFA_SC),
        bolDFAs: ArrayListUnmanaged(DFA_SC),
        tcDFAs: ArrayListUnmanaged(DFA_SC),
    ) !DFA {
        var merged = DFA {
            .alloc = DFAs.items[0].dfa.alloc,
            .yy_ec_highest = DFAs.items[0].dfa.yy_ec_highest,
        };

        var acceptList = std.ArrayList(AcceptState).init(merged.alloc);
        defer acceptList.deinit();

        var minDfa = Partition.init(merged.alloc);

        for (DFAs.items) |dfa_sc| {
            try acceptList.appendSlice(dfa_sc.dfa.accept_list);
            try minDfa.appendSlice(dfa_sc.dfa.minimized.?.data.items);
        }

        for (bolDFAs.items) |dfa_sc| {
            const dfaRow = blk: {
                for (DFAs.items) |nDFa_sc|
                if (nDFa_sc.sc == dfa_sc.sc) break :blk minDfa.data.items[nDFa_sc.dfa.offset];
                unreachable;
            };
            var bolRow = &dfa_sc.dfa.minimized.?.data.items[0];

            outer: for (dfaRow.signature.?.data.items) |transition| {
                for (bolRow.signature.?.data.items) |bolTrans| {
                    if (Symbol.eql(transition.symbol, bolTrans.symbol))
                        continue: outer;
                }
                try bolRow.signature.?.append(transition);
            }
            bolRow.signature.?.sort();

            try acceptList.appendSlice(dfa_sc.dfa.accept_list);
            try minDfa.appendSlice(dfa_sc.dfa.minimized.?.data.items);
        }

        for (tcDFAs.items) |tc_dfa| {
            try acceptList.appendSlice(tc_dfa.dfa.accept_list);
            try minDfa.appendSlice(tc_dfa.dfa.minimized.?.data.items);
        }

        merged.minimized = minDfa;
        merged.accept_list = try acceptList.toOwnedSlice();
        merged.yy_accept = try merged.getAcceptTable();

        try merged.compress();
        return merged;
    }

    pub fn getAcceptTable(self: DFA) ![]i16 {
        if (self.minimized) |m| {
            var ret = try ArrayList(i16).initCapacity(self.alloc, m.data.items.len);
            defer ret.deinit();

            ret.expandToCapacity();
            @memset(ret.items[0..], 0);

            for (m.data.items, ret.items) |s, *a| {
                if (s.accept_id) |id| a.* = @intCast(id + 1);
            }
            return ret.toOwnedSlice();
        } else @panic("MinDFA not built !");
    }

    pub fn compress(self: *DFA) !void {
        const minDFA = self.minimized orelse return error.MissingMinDFA;
        // try minDFA.dump(self.data);

        //Keep track of the transition count to fill the yy_nxt array later
        var nTransition: usize = 0;

        var realTransTable = try ArrayList(ArrayList(i16))
            .initCapacity(self.alloc, minDFA.data.items.len);

        for (minDFA.data.items, 0..) |state, i| {
            realTransTable.appendAssumeCapacity(try ArrayList(i16).initCapacity(self.alloc, self.yy_ec_highest + 1));
            realTransTable.items[i].expandToCapacity();
            @memset(realTransTable.items[i].items[0..], -1);

            nTransition += state.signature.?.data.items.len;
            for (state.signature.?.data.items) |transition| {
                realTransTable.items[i].items[transition.symbol.ec] = @intCast(transition.group_id);
            }
        }

        self.transTable = realTransTable;

        const transTableLen = realTransTable.items.len;
        var transTable = realTransTable;

        var base    =   try ArrayList(i16).initCapacity(self.alloc, transTableLen);
        var next    =   try ArrayList(i16).initCapacity(self.alloc, transTableLen);
        var check   =   try ArrayList(i16).initCapacity(self.alloc, transTableLen);
        var default =   try ArrayList(i16).initCapacity(self.alloc, transTableLen);
        defer {
            base.deinit();
            next.deinit();
            check.deinit();
            default.deinit();
        }
        base.expandToCapacity();
        default.expandToCapacity();
        @memset(default.items[0..], -1);


        var ommitable = ArrayList(struct {usize, usize}).init(self.alloc);
        defer ommitable.deinit();

        const candidates: ArrayList(ArrayList(struct {usize, *[]i16})) = outer: {
            var cs = try ArrayList(ArrayList(struct{usize, *[]i16})).initCapacity(self.alloc, transTableLen);
            for (0..transTableLen) |_| cs.appendAssumeCapacity(ArrayList(struct{usize, *[]i16}).init(self.alloc));

            for (0..transTableLen) |y| {
                const it = transTableLen - 1 - y;
                for (0..it) |i_y| {
                    var reverse: bool = false;
                    const append: bool = iblk: {
                        var dominant: ?u1 = null;
                        var jamRow: struct {bool, bool} = .{true, true};
                        var oneEqual: bool = false;
                        for (transTable.items[it].items, transTable.items[i_y].items, 0..) |a, b, i| {
                            _ = i;
                            const aJam = (a == -1);
                            const bJam = (b == -1);
                            if (!aJam) jamRow[0] = false;
                            if (!bJam) jamRow[1] = false;
                            if (dominant == null) {
                                if (!aJam and bJam) dominant = 1;
                                if (aJam and !bJam) dominant = 0;
                            }
                            if (aJam and !bJam and dominant == 1) break: iblk false;
                            if (!aJam and bJam and dominant == 0) break: iblk false;
                            if (!aJam and !bJam and a == b) oneEqual = true;
                        }
                        if (dominant == 0) reverse = true;
                        break: iblk (oneEqual and !jamRow[0] and !jamRow[1]);
                    };
                    if (append) {
                        const indexa, const indexb = if (reverse) .{it, i_y} else . {i_y, it};
                        // std.debug.print("On analyzing row: {d} with reverse as {}\n", .{it, reverse});
                        // std.debug.print("Append: {d} to {d}\n", .{indexa, indexb});
                        try cs.items[indexb].append(.{indexa, &transTable.items[indexa].items});
                    }
                }
            }
            break: outer cs;
        };
        defer {
            for (candidates.items) |c| c.deinit();
            candidates.deinit();
        }


        // for (candidates.items, 0..) |cs, i| { 
            // std.log.info("c for {d} : {any}", .{i, cs.items});
        // }

        for (0..transTableLen) |it| {
            const c = candidates.items[it];
            const bestMatch: ?struct {usize, i16} = blk: {
                var best: ?struct {usize, i16} = null;
                for (c.items) |row| {
                    const score = iblk: {
                        var score: ?usize = null;
                        // std.debug.print("Row: {any} with: {any}\n", .{transTable.items[it].items, row[1].*});
                        for (row[1].*, 0..) |elem, x| {
                            if (elem != -1 and transTable.items[it].items[x] == elem) {
                                score = if (score) |s| s + 1 else 1;
                            }
                        }
                        break: iblk score;
                    };
                    if (score == null) continue;
                    if (best == null or score.? > best.?[0]) best = .{score.?, @intCast(row[0])};
                }
                break: blk if (best) |b| b
                    else null;
            };
            if (bestMatch == null) continue;

            for (transTable.items[it].items, 0..) |elem, x| {
                if (elem != -1 and elem == transTable.items[@intCast(bestMatch.?[1])].items[x]) {
                    try ommitable.append(.{it, x});
                }
            }
            default.items[it] = bestMatch.?[1];
            // std.debug.print("BestMatch for row: {d} -> {any}\n", .{it, bestMatch});
        }

        // std.debug.print("List of ommitables:\n {any}\n", .{ommitable.items});
        // transTableDump(transTable);


        if (ommitable.items.len != 0) {
            var clone = try transTable.clone();
            for (clone.items) |*row| {
                row.* = try row.clone();
            }
            for (ommitable.items) |c| {
                clone.items[c[0]].items[c[1]] = -1;
            }
            transTable = clone;
            nTransition -= ommitable.items.len;
        }
        defer {
            if (ommitable.items.len != 0) {
                for (transTable.items) |row| row.deinit();
                transTable.deinit();
            }
        }

        // std.debug.print("\n\n", .{});
        // transTableDump(transTable);

        const padding = blk: {
            var count:usize = 0;
            for (transTable.items[0].items) |t| {
                if (t != -1) break;
                count += 1;
            }
            break: blk count;
        };

        for (transTable.items[0..], 0..) |row, i| {
            var offset: usize = 0;

            const allNotNull: std.ArrayList(usize) = blk: {
                var ret = std.ArrayList(usize).init(self.alloc);
                for (row.items, 0..) |t, j| { if (t != -1) try ret.append(j); }
                break: blk ret;
            };
            defer allNotNull.deinit();
            // std.debug.print("Not null of: {d} -> {any}\n", .{i, allNotNull.items});

            //For all rows above the current, check that all not null values have only zeroes above them
            //otherwise, increase offset by one until its true
            // std.debug.print("{s}Need to check for {d}..{d}{s}\n", .{ Red, 0, i, Reset, });
            outer: while (true) {
                defer offset += 1;

                for (transTable.items[0..i], 0..) |aRow, indexLookup|  {
                    const aRowOffset: usize = @intCast(base.items[indexLookup]);
                    // std.debug.print("{s}Arow[{d}], Offset: {d}{s}\n", .{
                    //     Green,
                    //     indexLookup,
                    //     aRowOffset,
                    //     Reset,
                    // });

                    for (allNotNull.items) |rowIndex| {
                        const realIndex = rowIndex + offset;
                        if (
                            realIndex < aRowOffset or
                            realIndex >= (aRow.items.len + aRowOffset) or
                            aRow.items[realIndex - aRowOffset] == -1
                        ) {
                            continue;
                        } else {
                            continue :outer;
                        }
                    }
                }
                base.items[i] = @intCast(offset);
                break: outer;
            }
        }

        // compressedTableDump(base, next, check, default);
        var globalOffset = padding - padding;
        while (nTransition != 0) {
            var it: usize = 0;
            var caught: bool = false;
            while (it < transTable.items.len) {
                const rowOffset: usize = @intCast(base.items[it]);
                const row = transTable.items[it];

                if (
                    globalOffset < rowOffset 
                    or globalOffset >= (row.items.len + rowOffset) 
                    or row.items[globalOffset - rowOffset] == -1
                ) {
                    it += 1;
                } else {
                    nTransition -= 1;
                    try check.append(@intCast(it));
                    try next.append(row.items[globalOffset - rowOffset]);
                    globalOffset += 1;
                    caught = true;
                }
            }
            if (!caught) {
                try next.append(-1);
                try check.append(-1);
                globalOffset += 1;
            }
        }


        const maxOffset: usize = @intCast(std.mem.max(i16, base.items[0..]));
        if ((maxOffset + self.yy_ec_highest) >= next.items.len) {
            const diff = (maxOffset + self.yy_ec_highest) - next.items.len + 1;
            for (0..diff) |_| {
                try next.append(-1);
                try check.append(-1);
            }
        }

        DFADump.transTableDump(transTable);
        std.debug.print("\n", .{});
        DFADump.compressedTableDump(base, next, check, default);
        std.debug.print("\n\n", .{});

        self.cTransTable = .{ 
            .check = try check.toOwnedSlice(),
            .base = try base.toOwnedSlice(),
            .next = try next.toOwnedSlice(),
            .default = try default.toOwnedSlice(),
        };
    }

    fn getNext(
        ctt: CompressedTransitionTable,
        state: usize,
        symbol: u8
    ) i16 {
        var s = state;
        while (true) {
            if (ctt.check[@as(usize, @intCast(ctt.base[s])) + symbol] == s)
                return ctt.next[@as(usize, @intCast(ctt.base[s])) + symbol];
            s = if (ctt.default[s] == -1) return -1 else @intCast(ctt.default[s]);
        }
    }

    pub fn compareTTToCTT(self: DFA) !bool {
        const tt = self.transTable orelse return error.NoTT;
        const ctt = self.cTransTable orelse return error.NoCTT;
        for (0..tt.items.len) |y| {
            for (0..tt.items[0].items.len) |x| {
                const ec: u8 = @intCast(x);
                const expected =  tt.items[y].items[x];
                const got = getNext(ctt, y, ec);
                if (expected != got) {
                    std.log.err("Invalid compression on state: {d}, symbol: {d}", .{y, ec});
                    return false;
                }
            }
        }
        return true;
    }

};
