const std = @import("std");

pub const Definitions = struct {

    pub const CCode = struct {
        lineNo: usize,
        code: []u8,
    };

    pub const Definition = struct {
        name: []u8,
        substitute: []u8,
    };

    pub const StartConditions = struct {
        inclusive: std.ArrayListUnmanaged([]u8),
        exclusive: std.ArrayListUnmanaged([]u8),

        pub fn init(alloc: std.mem.Allocator) !StartConditions {
            return .{
                .inclusive = try std.ArrayListUnmanaged([]u8).initCapacity(alloc, 5),
                .exclusive = try std.ArrayListUnmanaged([]u8).initCapacity(alloc, 5),
            };
        }

        pub fn deinit(self: *StartConditions, alloc: std.mem.Allocator) void {
            self.exclusive.deinit(alloc);
            self.inclusive.deinit(alloc);
        }
    };

    pub const YYTextType = enum { Array, Pointer, };

    pub const Params = struct {
        nPositions: usize = 2500,               //%p n
        nStates: usize = 500,                   //%n n
        nTransitions: usize = 2000,             //%a n
        nParseTreeNodes: usize = 1000,          //%e n
        nPackedCharacterClass: usize = 1000,    //%k n
        nOutputArray: usize = 3000,             //%o n
    };

    yytextType: YYTextType = .Array,
    cCodeFragments: std.ArrayListUnmanaged(CCode),
    definitions: std.ArrayListUnmanaged(Definition),
    params: Params = .{},
    startConditions: StartConditions,

    pub fn init(alloc: std.mem.Allocator) !Definitions {
        return .{
            .cCodeFragments = try std.ArrayListUnmanaged(CCode).initCapacity(alloc, 5),
            .definitions = try std.ArrayListUnmanaged(Definition).initCapacity(alloc, 5),
            .startConditions = try StartConditions.init(alloc),
        };
    }

    pub fn deinit(self: *Definitions, alloc: std.mem.Allocator) void {
        self.cCodeFragments.deinit(alloc);
        for (self.definitions.items) |item| alloc.free(item.substitute);
        self.definitions.deinit(alloc);
        self.startConditions.deinit(alloc);
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();

        try jws.objectField("Parameters");
        try jws.write(self.params);

        try jws.objectField("YYTextType");
        try jws.print("{s}", .{@tagName(self.yytextType)});

        try jws.objectField("Inclusive conditions");
        try jws.beginArray();
        for (self.startConditions.inclusive.items) |cond| { try jws.print("{s}", .{cond}); }
        try jws.endArray();

        try jws.objectField("Exclusive conditions");
        try jws.beginArray();
        for (self.startConditions.exclusive.items) |cond| { try jws.print("{s}", .{cond}); }
        try jws.endArray();

        try jws.objectField("Definitions");
        try jws.beginArray();
        for (self.definitions.items) |cond| { try jws.write(cond); }
        try jws.endArray();

        try jws.objectField("Code fragments");
        try jws.beginArray();
        for (self.cCodeFragments.items) |code| { try jws.write(code); }
        try jws.endArray();


        try jws.endObject();
    }

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; _ = options;
        try std.json.stringify(self, .{.whitespace = .indent_1}, writer);
    }
};
