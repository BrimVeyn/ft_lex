const std       = @import("std");
const ArrayList = std.ArrayList;

const DFAModule = @import("DFA.zig");
const DFADump   = @import("DFA_Dump.zig");
const DFA       = DFAModule.DFA;

pub fn compress(self: *DFA) !void {
    const transTableLen = self.transTable.?.data.items.len;
    var transTable = self.transTable.?.data;
    var nTransition = self.transTable.?.nTransition;

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


    for (0..transTableLen) |it| {
        const c = candidates.items[it];
        const bestMatch: ?struct {usize, i16} = blk: {
            var best: ?struct {usize, i16} = null;
            for (c.items) |row| {
                const score = iblk: {
                    var score: ?usize = null;
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
    }

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

        const allNotNull: ArrayList(usize) = blk: {
            var ret = ArrayList(usize).init(self.alloc);
            for (row.items, 0..) |t, j| { if (t != -1) try ret.append(j); }
            break: blk ret;
        };
        defer allNotNull.deinit();

        //For all rows above the current, check that all not null values have only zeroes above them
        //otherwise, increase offset by one until its true
        // std.debug.print("{s}Need to check for {d}..{d}{s}\n", .{ Red, 0, i, Reset, });
        outer: while (true) {
            defer offset += 1;

            for (transTable.items[0..i], 0..) |aRow, indexLookup|  {
                const aRowOffset: usize = @intCast(base.items[indexLookup]);

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

    // DFADump.transTableDump(transTable);
    // std.debug.print("\n", .{});
    // DFADump.compressedTableDump(base, next, check, default);
    // std.debug.print("\n\n", .{});

    self.cTransTable = .{ 
        .check = try check.toOwnedSlice(),
        .base = try base.toOwnedSlice(),
        .next = try next.toOwnedSlice(),
        .default = try default.toOwnedSlice(),
    };
}
