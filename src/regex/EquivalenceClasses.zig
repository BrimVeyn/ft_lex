const std = @import("std");

pub fn buildEquivalenceTable(
    alloc: std.mem.Allocator,
    sets: std.AutoArrayHashMap(std.StaticBitSet(256), void),
    yy_ec: *[256]u8)
!u8 {

    var signatures = std.AutoArrayHashMap(std.StaticBitSet(256), u8).init(alloc);
    defer signatures.deinit();

    var next_id: u8 = 1;

    for (0..256) |c| {
        const ch: u8 = @intCast(c);
        var signature = std.StaticBitSet(256).initEmpty();

        for (sets.keys(), 0..) |set, idx| {
            signature.setValue(idx, set.isSet(ch));
        }

        if (!signatures.contains(signature)) {
            try signatures.put(signature, next_id);
            next_id += 1;
        }

        const class_id = signatures.get(signature) orelse return error.UnexpectedClass;
        yy_ec[ch] = class_id;
    }
    //NOTE: yy_ec[0] aka \x00 is reserved with class_id 0 to signal eof
    yy_ec[0x00] = 0;
    return next_id - 1;
}
