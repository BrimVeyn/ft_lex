const std                   = @import("std");
const LexTokenizerModule    = @import("Tokenizer.zig");
const LexTokenizer          = LexTokenizerModule.LexTokenizer;
const LexToken              = LexTokenizerModule.LexTokenizer.LexToken;
const LexTokenizerError     = LexTokenizerModule.LexTokenizer.LexTokenizerError;

const DefinitionsModule     = @import("Definitions.zig");
const Definitions           = DefinitionsModule.Definitions;

const LexParser = @This();

const LexParserError = error {
    TooLongAName,
    RecursiveDefinitionNotAllowed,
    NoSuchDefinition,
} || error { OutOfMemory };

definitions: Definitions,
// rules: Rules,
tokenizer: LexTokenizer,
alloc: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator, fileName: []u8) !LexParser {
    var file = std.fs.cwd().openFile(fileName, .{}) catch |e| {
        std.log.err("ft_lex: Failed to open: {s}, reason: {!}", .{fileName, e});
        return e;
    };
    defer file.close();
    const rawContent = file.readToEndAlloc(alloc, 1e8) catch |e| {
        std.log.err("ft_lex: Failed to read: {s}, reason: {!}", .{fileName, e});
        return e;
    };

    return .{
        .tokenizer = LexTokenizer.init(alloc, rawContent, fileName),
        .alloc = alloc,
        .definitions = try Definitions.init(alloc),
    };
}

pub fn deinit(self: *LexParser) void {
    self.alloc.free(self.tokenizer.input);
    self.definitions.deinit(self.alloc);
}

fn advance(self: *LexParser) !LexToken {
    return self.tokenizer.next();
}

fn logError(self: *LexParser, err: LexParserError) LexParserError {
    switch (err) {
        error.TooLongAName => std.log.err("{s}: bad substitution: too long a name", .{self.tokenizer.getFileName()}),
        error.RecursiveDefinitionNotAllowed => std.log.err("{s}: recursive definition not allowed", .{self.tokenizer.getFileName()}),
        error.NoSuchDefinition => std.log.err("{s}: no such definition", .{self.tokenizer.getFileName()}),
        else => {},
    }
    return err;
}

fn replaceName(self: *LexParser, idef: usize, sdef: usize, edef: usize, def: *[]u8) !struct { []u8, usize } {
    var buffer: [256]u8 = .{0} ** 256;
    var stream = std.io.fixedBufferStream(&buffer);
    var writer = stream.writer();

    const substitute = blk: {
        for (self.definitions.definitions.items, 0..) |innerDef, it| {
            // std.debug.print("Comparing: {s} w {s}\n", .{innerDef.name, def.*[sdef + 1..edef]});
            if (std.mem.eql(u8, innerDef.name, def.*[sdef + 1..edef])) {
                if (it == idef) return error.RecursiveDefinitionNotAllowed;
                // std.debug.print("match: {s}: {s}\n", .{def.*[sdef + 1..edef], innerDef.name});
                break :blk innerDef.substitute;
            }
        }
        return error.NoSuchDefinition;
    };

    var newIt: usize = 0;
    newIt += writer.write(def.*[0..sdef]) catch return error.TooLongAName;
    newIt += writer.write(substitute) catch return error.TooLongAName;
    _ = writer.write(def.*[edef + 1..]) catch return error.TooLongAName;

    return .{
        try self.alloc.dupe(u8, std.mem.trimRight(u8, buffer[0..], "\x00\n ")),
        newIt - 1,
    };
}

fn expandDefinitions(self: *LexParser) !void {
    for (0..self.definitions.definitions.items.len) |idef| {
        var def = self.definitions.definitions.items[idef];
        var quote, var brace, var register = [_]bool{ false, false, false };
        var it: usize = 0;
        var sdef, var edef = [_]usize {0, 0};

        while (it < def.substitute.len) : (it += 1) {
            const prev: ?u8 = if (it >= 1) def.substitute[it - 1] else null;
            const curr: u8 = def.substitute[it];

            // std.debug.print("{d}:{c}\n", .{it, curr});
            if (prev != null and prev == '\\')
                continue;

            switch (curr) {
                '"' => quote = !quote,
                '[' => brace = true,
                ']' => brace = false,
                '{' => if (!quote and !brace) { register = true; sdef = it; },
                '}' => if (!quote and !brace) { register = false; edef = it;
                    const newSub, it = try self.replaceName(idef, sdef, edef, &def.substitute);
                    self.alloc.free(def.substitute);
                    def.substitute = newSub;
                    self.definitions.definitions.items[idef] = def;
                },
                else => {},
            }
        }
        // std.debug.print("{s}: {s}\n", .{def.name, def.substitute});
    }
}

pub fn parse(self: *LexParser) !void {
    //Skip potential blank lines
    self.tokenizer.eatWhitespacesAndNewline();

    //Parse definition section
    outer: while (true) {
        const token = try self.advance();
        switch (token) {
            .cCode => |code| try self.definitions.cCodeFragments.append(self.alloc, code),
            .definition => |def| try self.definitions.definitions.append(
                self.alloc, .{
                    .name = def.name,
                    .substitute = try self.alloc.dupe(u8, def.substitute) 
            }),
            .startCondition => |start| { 
                defer start.name.deinit();
                switch (start.type) {
                    .Inclusive => try self.definitions.startConditions.inclusive.appendSlice(self.alloc, start.name.items[0..]),
                    .Exclusive => try self.definitions.startConditions.exclusive.appendSlice(self.alloc, start.name.items[0..]),
                }
            },
            .param => |p| switch (p) {
                .nPositions => |v| self.definitions.params.nPositions = v,
                .nStates => |v| self.definitions.params.nStates = v,
                .nTransitions => |v| self.definitions.params.nTransitions = v,
                .nParseTreeNodes => |v| self.definitions.params.nParseTreeNodes = v,
                .nPackedCharacterClass => |v| self.definitions.params.nPackedCharacterClass = v,
                .nOutputArray => |v| self.definitions.params.nOutputArray = v,
                .YYTextType => |v| self.definitions.yytextType = v,
            },
            .EndOfSection => break: outer,
            .comment => continue: outer,
            else => std.debug.print("Unimplemented parser\n", .{}),
        }
    }
    self.expandDefinitions() catch |e| return self.logError(e);

    self.tokenizer.changeContext(.Rules);
    //Skip potential blank lines
    self.tokenizer.eatWhitespacesAndNewline();

    outer: while (true) {
        const token = try self.advance();
        switch (token) {

            .EOF, .EndOfSection => break: outer,
            else => {}
        }
    }

    std.debug.print("{}\n", .{self.definitions});

    std.debug.print("End of definition section\n", .{});
}
