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

const DFADump               = @import("DFA_Dump.zig");
const DFAMinimizer          = @import("DFA_minimizer.zig");
const DFACompression        = @import("DFA_compression.zig");
const Partition             = DFAMinimizer.Partition;

const EC                    = @import("EquivalenceClasses.zig");
const LexParser             = @import("../lex/Parser.zig");
const G                     = @import("../globals.zig");

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
    transitions: ArrayList(DFATransition),
    accept_id  : ?usize = null,
    accept_list: ?[]usize,

    pub fn init(alloc: std.mem.Allocator) StateSetData {
        return .{ .transitions = ArrayList(DFATransition).init(alloc), };
    }

    pub fn deinit(self: *StateSetData, alloc: std.mem.Allocator) void {
        if (self.accept_list) |al| alloc.free(al);
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
    const TransitionTable = struct {
        nTransition: usize,
        data: ArrayList(ArrayList(i16)),
    };

    const CompressedTransitionTable = struct {
        base   : []i16,
        check  : []i16,
        next   : []i16,
        default: []i16,
    };

    pub const AcceptState = struct {
        state: *State,
        priority: usize,
    };

    pub const DfaTable = std.ArrayHashMap(StateSet, StateSetData, StateSetCtx, true);

    alloc        : std.mem.Allocator,
    lexParser    : *LexParser,
    // epsilon_cache: std.AutoHashMap(StateSet, StateSet) = undefined,
    data         : DfaTable = undefined,
    minimized    : ?Partition = null,
    accept_list  : []AcceptState = undefined,
    transTable   : ?TransitionTable = null,
    cTransTable  : ?CompressedTransitionTable = null,
    nfa_start    : *State = undefined,
    yy_ec_highest: u8 = 0,
    yy_accept    : ?[]i32 = null,
    offset       : usize = 0,


    pub fn buildFromNFA(
        alloc: std.mem.Allocator,
        lexParser: *LexParser,
        nfa: NFA,
        acceptList: []AcceptState, maxEc: u8
    ) !DFA {
        var dfa = DFA.init(alloc, lexParser, nfa, acceptList, maxEc);
        try dfa.subset_construction();
        try dfa.minimize();

        //HACK: The compression in unnecessary here and only used for debug purposes
        // try dfa.compress();
        return dfa;
    }

    pub fn init(
        alloc: std.mem.Allocator,
        lexParser: *LexParser,
        nfa: NFA,
        accept_list: []AcceptState,
        yy_ec_highest: u8
    ) DFA {
        return .{
            .alloc = alloc,
            .lexParser = lexParser,
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
            entry.value_ptr.*.deinit(self.alloc);
        }
        if (self.cTransTable) |ctt| {
            self.alloc.free(ctt.next);
            self.alloc.free(ctt.base);
            self.alloc.free(ctt.check);
            self.alloc.free(ctt.default);
        }
        if (self.transTable) |tt| {
            for (tt.data.items) |row| row.deinit();
            tt.data.deinit();
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
            for (tt.data.items) |row| row.deinit();
            tt.data.deinit();
        }
        if (self.yy_accept) |a| self.alloc.free(a);
    }

    pub const stringify          = DFADump.stringify;
    pub const minimizedStringify = DFADump.minimizedStringify;
    pub const minimize           = DFAMinimizer.minimize;
    pub const compress           = DFACompression.compress;

    fn getAcceptingRule(self: *DFA, set: StateSet) !struct { ?usize, ?[]usize } {
        var best: ?usize = null; 
        var all = if (G.options.needREJECT) 
                ArrayList(usize).init(self.alloc) else null;

        for (set.keys()) |s| {
            for (self.accept_list) |aState| {
                if (s.id == aState.state.id) {
                    if (G.options.needREJECT)
                        try all.?.append(aState.priority + 1);

                    if (best == null or (aState.priority + 1) < best.?)
                        best = (aState.priority + 1);
                }
            }
        }
        if (all) |a| 
            std.mem.sort(usize, a.items[0..], {}, std.sort.asc(usize));

        return .{ 
            best,
            if (all) |*a| try a.toOwnedSlice() else null 
        };
    }

    inline fn epsilon_closure(self: *DFA, states: StateSet) !StateSet {
        var closure = try states.clone();

        var stack = ArrayList(*State).init(self.alloc);
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

        var queue = ArrayList(StateSet).init(self.alloc);
        defer queue.deinit();

        try queue.append(start_closure);
        const accept_id, const accept_list = try self.getAcceptingRule(start_closure);
        try self.data.put(start_closure, .{
            .transitions = ArrayList(DFATransition).init(self.alloc),
            .accept_id = accept_id,
            .accept_list = accept_list,
        });
        // self.epsilon_cache = std.AutoHashMap(StateSet, StateSet).init(self.alloc);
        // defer self.epsilon_cache.deinit();

        while (queue.pop()) |current_set| {
            for (0..256) |s| {
                const symbol: u8 = @intCast(s);
                var gotos = try self.move(current_set, symbol);
                defer gotos.deinit();

                // const symbol_graph = if (std.ascii.isPrint(symbol)) symbol else '.';
                // std.debug.print("symbol: {c}|{d} found: ", .{symbol_graph, symbol});
                // try printStateSet(gotos);

                if (gotos.count() == 0) 
                    continue;

                var closure = try self.epsilon_closure(gotos);
                // try printStateSet(closure);

                if (!self.data.contains(closure)) {
                    const inner_accept_id, const inner_accept_list = try self.getAcceptingRule(closure);
                    try self.data.put(closure, .{
                        .transitions = std.ArrayList(DFATransition).init(self.alloc),
                        .accept_id = inner_accept_id,
                        .accept_list = inner_accept_list,
                    });
                    try queue.append(closure);

                    const maybe_value = self.data.getPtr(current_set);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{.symbol = .{ .char =  symbol }, .to = closure });
                    } else unreachable;
                } else {
                    const maybe_value = self.data.getPtr(current_set);
                    const closure_ptr = self.data.getKeyPtr(closure);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{.symbol = .{ .char = symbol }, .to = closure_ptr.?.* });
                    } else unreachable;
                    closure.deinit();
                }
            }
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
                    const inner_accept_id, const inner_accept_list = try self.getAcceptingRule(closure);
                    try self.data.put(closure, .{
                        .transitions = ArrayList(DFATransition).init(self.alloc),
                        .accept_id = inner_accept_id,
                        .accept_list = inner_accept_list,
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


    pub fn buildAndMergeFromNFAs(
        alloc: std.mem.Allocator,
        lexParser: *LexParser,
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
        var DFAs     = try ArrayListUnmanaged(DFA_SC).initCapacity(alloc, mergedNFAs.items.len);
        var bol_DFAs = try ArrayListUnmanaged(DFA_SC).initCapacity(alloc, 1);
        var tc_DFAs  = try ArrayListUnmanaged(DFA_SC).initCapacity(alloc, 1);
        errdefer {
            DFAs.deinit(alloc);
            bol_DFAs.deinit(alloc);
            tc_DFAs.deinit(alloc);
        }

        for (mergedNFAs.items) |nfa| {
            const dfa = try DFA.buildFromNFA(alloc, lexParser, nfa.nfa, nfa.acceptList, ec.maxEc);
            try DFAs.append(alloc, .{ .dfa = dfa, .sc = nfa.sc });
        }

        for (bolMergedNFAs.items) |nfa| {
            const dfa = try DFA.buildFromNFA(alloc, lexParser, nfa.nfa, nfa.acceptList, ec.maxEc);
            try bol_DFAs.append(alloc, .{ .dfa = dfa, .sc = nfa.sc });
        }

        for (tcNFAs.items) |nfa| {
            const dfa = try DFA.buildFromNFA(alloc, lexParser, nfa.nfa, nfa.acceptList, ec.maxEc);
            try tc_DFAs.append(alloc, .{ .dfa = dfa, .sc = nfa.sc, .trailingContextRuleId = nfa.trailingContextRuleId.? });
        }

        const finalDfa = try merge(DFAs, bol_DFAs, tc_DFAs);
        return .{ finalDfa, DFAs, bol_DFAs, tc_DFAs };
    }

    pub fn merge(
        DFAs   : ArrayListUnmanaged(DFA_SC),
        bolDFAs: ArrayListUnmanaged(DFA_SC),
        tcDFAs : ArrayListUnmanaged(DFA_SC),
    ) !DFA {
        var merged = DFA {
            .lexParser = DFAs.items[0].dfa.lexParser,
            .alloc = DFAs.items[0].dfa.alloc,
            .yy_ec_highest = DFAs.items[0].dfa.yy_ec_highest,
        };

        var acceptList = ArrayList(AcceptState).init(merged.alloc);
        defer acceptList.deinit();

        var minDfa = Partition.init(merged.alloc);

        for (DFAs.items) |dfa_sc| {
            try acceptList.appendSlice(dfa_sc.dfa.accept_list);
            try minDfa.appendSlice(dfa_sc.dfa.minimized.?.data.items);
        }

        for (bolDFAs.items) |dfa_sc| {
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
    
        try merged.buildTransTable();
        if (!G.options.fast)
            try merged.compress();
        return merged;
    }

    pub fn getAcceptTable(self: DFA) ![]i32 {
        if (self.minimized) |m| {
            const ret = try self.alloc.alloc(i32, m.data.items.len);
            @memset(ret, 0);

            for (m.data.items, ret) |s, *a| {
                if (s.accept_id) |id| a.* = @intCast(id);
            }
            return ret;
        } else @panic("MinDFA not built !");
    }

    pub fn buildTransTable(self: *DFA) !void {
        const minDFA = self.minimized orelse return error.MissingMinDFA;

        //Keep track of the transition count to fill the yy_nxt array later
        var nTransition: usize = 0;

        if (G.options.fast) {
            var realTransTable = try ArrayList(ArrayList(i16))
            .initCapacity(self.alloc, minDFA.data.items.len);

            for (minDFA.data.items, 0..) |state, i| {
                realTransTable.appendAssumeCapacity(try ArrayList(i16).initCapacity(self.alloc, std.math.maxInt(u8)));
                realTransTable.items[i].expandToCapacity();
                @memset(realTransTable.items[i].items[0..], -1);

                nTransition += state.signature.?.data.items.len;
                for (state.signature.?.data.items) |transition| {
                    realTransTable.items[i].items[transition.symbol.char] = @intCast(transition.group_id);
                }
            }

            self.transTable = .{
                .data = realTransTable,
                .nTransition = nTransition,
            };

        } else {
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

            self.transTable = .{
                .data = realTransTable,
                .nTransition = nTransition,
            };
        }

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
        for (0..tt.data.items.len) |y| {
            for (0..tt.data.items[0].items.len) |x| {
                const ec: u8 = @intCast(x);
                const expected =  tt.data.items[y].items[x];
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
