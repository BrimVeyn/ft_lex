const std = @import("std");

const EC = @This();

yy_ec: [256]u8 = .{0} ** 256,
maxEc: u8 = 0,

pub fn buildEquivalenceTable(
    alloc: std.mem.Allocator,
    sets: std.AutoArrayHashMap(std.StaticBitSet(256), void),
) !EC {
    var ret = EC{};
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
        ret.yy_ec[ch] = class_id;
    }
    //NOTE: yy_ec[0] aka \x00 is reserved with class_id 0 to signal eof
    ret.yy_ec[0x00] = 0;
    ret.maxEc = next_id - 1;
    return ret;
}
