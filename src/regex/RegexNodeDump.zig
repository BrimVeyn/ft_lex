const std              = @import("std");
const ParserModule     = @import("Parser.zig");
const RegexNode        = ParserModule.RegexNode;
const INFINITY         = ParserModule.INFINITY;
const Ascii            = @import("Ascii.zig");

const Green         = "\x1b[32m"; // Green for Char and CharClass
const BrightGreen   = "\x1b[92m"; // Bright green for literal chars
const Yellow        = "\x1b[33m"; // Yellow for Concat and TrailingContext
const Cyan          = "\x1b[36m"; // Cyan for Repetition
const Blue          = "\x1b[34m"; // Blue for Alternation
const Magenta       = "\x1b[35m"; // Magenta for Groups
const Red           = "\x1b[31m"; // Red for Anchors
const White         = "\x1b[97m"; // White for label text
const Reset         = "\x1b[0m";  // Reset color

pub fn dump(self: *const RegexNode, indent: usize) void {
    var pad: [1024]u8 = .{0} ** 1024;
    for (0..indent) |i| {
        pad[i] = ' ';
    }

    switch (self.*) {
        .Char => {
            std.debug.print("{s}{s}{s}{s}({s}{c}|{d}{s})\n", .{
                pad, Green, @tagName(self.*), Reset,
                BrightGreen, if (std.ascii.isPrint(self.Char)) self.Char else '.', self.Char, Reset,
            });
        },
        .Group => {
            std.debug.print("{s}{s}{s}(\n", .{ pad, Magenta, @tagName(self.*) });
            self.Group.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .CharClass => {
            var buffer: [255]u8 = undefined;
            var len: usize = 0;

            for (0..std.math.maxInt(u8)) |i| {
                const iU8: u8 = @intCast(i);
                if (self.CharClass.range.isSet(i)) {
                    buffer[len] = if (Ascii.isGraph(iU8)) iU8 else '.';
                    len += 1;
                }
            }
            std.debug.print("{s}{s}(negate={any}, chars=\"{s}{s}{s}\")\n", .{
                pad,
                Green,
                self.CharClass.negate,
                BrightGreen, buffer[0..len], Reset,
            });
        },
        .Concat => {
            std.debug.print("{s}{s}{s}{s}(\n", .{ Yellow, pad, @tagName(.Concat), Reset });
            self.Concat.left.dump(indent + 1);
            self.Concat.right.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .Repetition => {
            std.debug.print("{s}{s}{s}({d}, {?})(\n", .{ 
                Cyan, pad, @tagName(.Repetition),
                self.Repetition.min,
                self.Repetition.max,
            });
            self.Repetition.left.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .Alternation => {
            std.debug.print("{s}{s}{s}(\n", .{ Blue, pad, @tagName(.Alternation) });
            self.Alternation.left.dump(indent + 1);
            self.Alternation.right.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .AnchorStart => {
            std.debug.print("{s}{s}{s}(\n", .{ Red, pad, @tagName(.AnchorStart) });
            self.AnchorStart.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .TrailingContext => {
            std.debug.print("{s}{s}{s}{s}(\n", .{ Yellow, pad, @tagName(self.*), Reset });
            std.debug.print("{s}ToConsume: {s}", .{ White, Reset });
            self.TrailingContext.left.dump(indent + 1);
            std.debug.print("{s}Lookahead: {s}", .{ White, Reset });
            self.TrailingContext.right.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
    }
}
