const std = @import("std");
const ParserModule = @import("Parser.zig");
const RegexNode = ParserModule.RegexNode;

const Green = "\x1b[32m"; // Green for Char and CharClass
const Yellow = "\x1b[33m"; // Yellow for Concat
const Cyan = "\x1b[36m"; // Cyan for Star
const Blue = "\x1b[34m"; // Blue for Alternation
const Reset = "\x1b[0m";  // Reset color
const INFINITY = 10_000_000;

pub fn dump(self: *const RegexNode, indent: usize) void {
    var pad: [1024]u8 = .{0} ** 1024;
    for (0..indent) |i| {
        pad[i] = ' ';
    }

    switch (self.*) {
        .Dot => {
            std.debug.print("{s}{s}{s}{s}\n", .{
                pad,
                Green,
                @tagName(.Dot),
                Reset
            });
        },
        .Char => {
            std.debug.print("{s}{s}{s}{s}({c})\n", .{
                pad,
                Green,
                @tagName(.Char),
                Reset,
                self.Char 
            });
        },
        .CharClass => {
            var buffer: [255]u8 = undefined;
            var len: usize = 0;

            for (0..255) |i| {
                if (self.CharClass.range.isSet(i)) {
                    buffer[len] = @as(u8, @intCast(i));
                    len += 1;
                }
            }
            std.debug.print("{s}{s}(negate={any}, chars=\"{s}\")\n", .{
                pad,
                @tagName(.CharClass),
                self.CharClass.negate,
                buffer[0..len],
            });
        },
        .Concat => {
            std.debug.print("{s}{s}{s}{s}(\n", .{ Yellow, pad, @tagName(.Concat), Reset });
            self.Concat.left.dump(indent + 1);
            self.Concat.right.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .Repetition => {
            std.debug.print("{s}{s}({d}, {?})(\n", .{ 
                pad,
                @tagName(.Repetition),
                self.Repetition.min,
                self.Repetition.max,
            });
            self.Repetition.left.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .Alternation => {
            std.debug.print("{s}{s}(\n", .{ pad, @tagName(.Alternation) });
            self.Alternation.left.dump(indent + 1);
            self.Alternation.right.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .AnchorStart => {
            std.debug.print("{s}{s}(\n", .{ pad, @tagName(.AnchorStart) });
            self.AnchorStart.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        .AnchorEnd => {
            std.debug.print("{s}{s}(\n", .{ pad, @tagName(.AnchorEnd) });
            self.AnchorEnd.dump(indent + 1);
            std.debug.print("{s})\n", .{ pad });
        },
        else => @panic("Unhandled RegexNode format !"),
    }
}
