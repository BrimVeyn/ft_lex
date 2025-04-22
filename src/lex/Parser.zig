const std = @import("std");
const print = std.debug.print;

const LexParser = @This();

const FileParser = struct {
    const FileSections = struct {
        fileName: []u8,
        raw: []const u8,
        lines: [][]const u8,
        definitions: ?[][]const u8 = null, 
        rules: [][]const u8 = undefined,
        userSubroutines: ?[][]const u8 = null,
    };

    pub fn getDefinitionSection(lines: [][]const u8) !struct {?[][]const u8, usize} {
        if (std.mem.eql(u8, lines[0][0..2], "%%")) 
            return .{null, 1};

        for (lines, 0..) |line, i| {
            if (std.mem.eql(u8, line[0..2], "%%"))
                return .{lines[0..i], i + 1};
        }
        return error.PrematureEOF;
    }

    pub fn parseContent(alloc: std.mem.Allocator, fileName: []u8, rawContent: []u8) !FileSections {
        const lines = blk: {
            var arr = std.ArrayList([]const u8).init(alloc);
            defer arr.deinit();
            var lines = std.mem.tokenizeScalar(u8, rawContent, '\n');
            while (lines.next()) |line| try arr.append(line);
            break: blk try arr.toOwnedSlice();
        };
        errdefer {
            alloc.free(lines);
            alloc.free(rawContent);
        }

        const maybe_defs, const it = getDefinitionSection(lines) catch |e| {
            std.debug.print("ft_lex:{s}:{d}: {!}\n", .{std.fs.path.basename(fileName), lines.len, e});
            return e;
        };

        if (maybe_defs) |defs| {
            std.log.info("Def: {s}", .{defs});
        } else {
            std.log.info("Defs: null", .{});
        }
        std.log.info("rests: {s}", .{lines[it..]});

        // const rules, it = getRulesSection(rawContent[it..]);
        // const subRoutine = getSubRoutine(rawContent[it..]);

        return .{
            .raw = rawContent,
            .fileName = fileName,
            .lines = lines,
            .definitions = maybe_defs,
        };
    }
};

pub fn fileMode(alloc: std.mem.Allocator, fileName: []u8) !FileParser.FileSections {
    var file = std.fs.cwd().openFile(fileName, .{}) catch |e| {
        print("ft_lex: Failed to open: {s}, reason: {!}\n", .{fileName, e});
        return e;
    };
    defer file.close();
    const rawContent = file.readToEndAlloc(alloc, 1e8) catch |e| {
        print("ft_lex: Failed to read: {s}, reason: {!}\n", .{fileName, e});
        return e;
    };

    return try FileParser.parseContent(alloc, fileName, rawContent);
}
