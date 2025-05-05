const std               = @import("std");

const DefinitionsModule = @import("Definitions.zig");
const Definitions       = DefinitionsModule.Definitions;

pub const Rule = struct {
    regex: []u8,
    code: Definitions.CCode,

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; _ = options;
        try std.json.stringify(self, .{.whitespace = .indent_2}, writer);
    }
};
