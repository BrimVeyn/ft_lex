const std           = @import("std");
const NFAModule     = @import("NFA.zig");
const State         = NFAModule.State;
const Transition    = NFAModule.Transition;
const NFA           = NFAModule.NFA;

const StateSet      = std.AutoArrayHashMap(*State, bool);


pub const DFA = struct {
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) DFA {
        return .{
            .alloc = alloc,
        };
    }


    fn epsilon_closure(self: *DFA, states: StateSet) !StateSet {
        var closure = try states.clone();
        var stack = std.ArrayList(*State).init(self.alloc);

        for (states.keys()) |s| try stack.append(s);

        while (stack.pop()) |current| {
            for (current.transitions.items) |t| {
                if (t.symbol == null and !closure.contains(t.to)) {
                    try closure.put(t.to, true);
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
                    try moves.put(s, true);
                }
            }
        }

        return moves;
    }

    pub fn subset_construction(self: *DFA, nfa_start: *State) !void {
        var start_set = StateSet.init(self.alloc);
        try start_set.put(nfa_start, true);

        const start_closure = try self.epsilon_closure(start_set);

        for (start_closure.keys()) |k| {
            std.debug.print("Can go: {}\n", .{k});
        }

        var queue = std.ArrayList(StateSet).init(self.alloc);
        try queue.append(start_closure);

        while (queue.pop()) |current_set| {
            for (0..256) |s| {
                const symbol: u8 = @intCast(s);
                const gotos = try self.move(current_set, symbol);

                if (gotos.count() == 0) 
                    continue;

                const closure = try self.epsilon_closure(gotos);
                _ = closure;
                //if not in dfa
                //Add transition between current_set and closure and add to queue
                //else
                //add transition between current_set and closure and continue

            }
        }
    }
    // Perform closure on the current state set
    // For each input symbol do the GOTO operation on the closure set.
    //    If the state set you get from the GOTO is not empty
    //       Do a closure of the state set.
    //       If it is a new set of states:
    //          add a transition between the state sets on the input 
    //          repeat the entire operation on this new set
    //       Else
    //          add a transition between the state sets on the input

};

