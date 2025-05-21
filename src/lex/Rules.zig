const std                   = @import("std");

const DefinitionsModule     = @import("Definitions.zig");
const Definitions           = DefinitionsModule.Definitions;
const SCType                = Definitions.StartConditions.SCType;

pub const Rule = struct {
    regex: []u8,
    code: Definitions.CCode,
    sc: std.ArrayList(SCType) = undefined,

    pub fn init(alloc: std.mem.Allocator, regex: []u8, code: Definitions.CCode) Rule {
        return .{
            .regex = regex,
            .code = code,
            .sc = std.ArrayList(SCType).init(alloc),
        };
    }

    pub fn deinit(self: Rule, alloc: std.mem.Allocator) void {
        alloc.free(self.regex);
        self.sc.deinit();
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("Pattern");
        try jws.write(self.regex);
        try jws.objectField("Code");
        try jws.write(self.code);
        try jws.objectField("SC");
        try jws.beginArray();
        for (self.sc.items) |seq| { try jws.write(seq); }
        try jws.endArray();
        try jws.endObject();
    }

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; _ = options;
        try std.json.stringify(self, .{.whitespace = .indent_2}, writer);
    }
};
