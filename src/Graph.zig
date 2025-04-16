const std = @import("std");
const NFA = @import("NFA.zig").NFA;
const DFA = @import("DFA.zig").DFA;

const format:[]const u8 = 
\\digraph Combined {{
\\    rankdir=LR;
\\    node [shape=circle];
\\ edge [fontname="monospace"];
\\ node [fontname="monospace", shape=circle];
\\
\\ subgraph cluster_dfa {{
\\  label="DFA for {s}"
\\{s}
\\ }}
\\
\\ subgraph cluster_nfa {{
\\  label="NFA for {s}"
\\
\\  start [shape=point, width=0.2];
\\  edge [style=solid];
\\  start -> n1;
\\
\\{s}
\\ }}
\\}}
;
//regex, nfa, regex, dfa


pub fn dotFormat(regex: []const u8, nfa: NFA, dfa: DFA) void {
    const nfa_str = nfa.stringify(std.heap.page_allocator) catch return;
    const dfa_str = dfa.stringify(std.heap.page_allocator) catch return;
    defer {
        std.heap.page_allocator.free(nfa_str);
        std.heap.page_allocator.free(dfa_str);
    }

    std.debug.print(format, .{regex, dfa_str, regex, nfa_str});
}
