const std                 =  @import("std");
const ArrayListUnmanaged  =  std.ArrayListUnmanaged;

const DFAModule           =  @import("../../../regex/DFA.zig");
const DFA                 =  DFAModule.DFA;
const LexParser       = @import("../../Parser.zig");

pub fn printSCEnum(
    lParser: LexParser,
    dfas: ArrayListUnmanaged(DFA.DFA_SC),
    bol_dfas: ArrayListUnmanaged(DFA.DFA_SC),
    writer: anytype
) !void {
    _ = try writer.write("enum {\n");
    for (lParser.definitions.startConditions.data.items, dfas.items[0..], bol_dfas.items[0..]) |sc, dfa, bol| {
        //NOTE: We encode both Bol and Regular start position in a single int rather than creating an other enum.
        //Flex is smarter than that with table representation as the bol start is always one state after the sc regular start.
        //But with current implementation, it'll be a lot of overhead to use this representation.
        // std.debug.print("Offset bol: {d}, offset regular: {d}\n", .{bol.dfa.offset, dfa.dfa.offset});
        const value = (bol.dfa.offset << @as(u6, 16)) + dfa.dfa.offset; 
        _ = try writer.print("    {s} = {d},\n", .{sc.name, value});
    }
    _ = try writer.write("};\n\n");
}
