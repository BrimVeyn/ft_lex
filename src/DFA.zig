const std           = @import("std");
const NFAModule     = @import("NFA.zig");
const State         = NFAModule.State;
const Transition    = NFAModule.Transition;
const NFA           = NFAModule.NFA;

const stderr        = std.io.getStdErr();

const DFATransition = struct {
    symbol: ?u8,
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


const StateSetData = struct {
    transitions: std.ArrayList(DFATransition),
    accept: bool = false,
    
    pub fn init(alloc: std.mem.Allocator) StateSetData {
        return .{
            .transitions = std.ArrayList(DFATransition).init(alloc),
        };
    }

    pub fn deinit(self: *StateSetData) void {
        self.transitions.deinit();
    }
};

const StateSet      = std.AutoArrayHashMap(*State, void);
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
    accept_id: usize,
    nfa_start: *State,

    pub fn init(alloc: std.mem.Allocator, nfa: NFA) DFA {
        return .{
            .alloc = alloc,
            .data = DfaTable.init(alloc),
            .nfa_start = nfa.start,
            .accept_id = nfa.accept.id,
        };
    }

    pub fn deinit(self: *DFA) void {
        var dfa_it = self.data.iterator();
        defer self.data.deinit();

        while (dfa_it.next()) |entry| {
            entry.key_ptr.*.deinit();
            entry.value_ptr.*.deinit();
        }
    }

    pub fn stringify(self: DFA, alloc: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(alloc);
        defer buffer.deinit();

        var writer = buffer.writer();
        var dfa_it = self.data.iterator();

        while (dfa_it.next()) |entry|{
            const i_src = self.data.getIndex(entry.key_ptr.*);
            if (entry.value_ptr.accept == true) {
                try writer.print("d{?} [shape=\"doublecircle\"]\n", .{i_src.?});
            }
            // std.debug.print("({?}) => ", .{i_src});
            // try printStateSet(entry.key_ptr.*);
            for (entry.value_ptr.*.transitions.items) |t| {
                const i_dest = self.data.getIndex(t.to);
                try writer.print("d{?} -> d{?} [label=\"{c}\"]\n", .{i_src, i_dest, t.symbol orelse '#'});
            }
        }
        return try buffer.toOwnedSlice();
    }

    fn isAccept(self: *DFA, set: StateSet) bool {
        for (set.keys()) |s| if (s.id == self.accept_id) return true;
        return false;
    }

    fn epsilon_closure(self: *DFA, states: StateSet) !StateSet {
        var closure = try states.clone();

        var stack = std.ArrayList(*State).init(self.alloc);
        defer stack.deinit();

        for (states.keys()) |s| try stack.append(s);

        while (stack.pop()) |current| {
            for (current.transitions.items) |t| {
                if (t.symbol == null and !closure.contains(t.to)) {
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
                if (t.symbol != null and t.symbol == symbol) {
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
            .accept = self.isAccept(start_closure),
        });

        while (queue.pop()) |current_set| {
            // try printStateSet(current_set);
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
                    try self.data.put(closure, .{
                        .transitions = std.ArrayList(DFATransition).init(self.alloc),
                        .accept = self.isAccept(closure),
                    });
                    try queue.append(closure);

                    const maybe_value = self.data.getPtr(current_set);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{.symbol = symbol, .to = closure });
                    } else unreachable;
                } else {
                    const maybe_value = self.data.getPtr(current_set);
                    const closure_ptr = self.data.getKeyPtr(closure);
                    if (maybe_value) |value| {
                        try value.transitions.append(.{.symbol = symbol, .to = closure_ptr.?.* });
                    } else unreachable;
                    closure.deinit();
                }
            }
        }

    }
};

