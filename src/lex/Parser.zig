const std                   = @import("std");
const LexTokenizerModule    = @import("Tokenizer.zig");
const LexTokenizer          = LexTokenizerModule.LexTokenizer;
const LexToken              = LexTokenizerModule.LexTokenizer.LexToken;
const LexTokenizerError     = LexTokenizerModule.LexTokenizer.LexTokenizerError;

const DefinitionsModule     = @import("Definitions.zig");
const Definitions           = DefinitionsModule.Definitions;

const RuleModule            = @import("Rules.zig");
const Rule                  = RuleModule.Rule;

const LexParser = @This();

const LexParserError = error {
    TooLongAName,
    RecursiveDefinitionNotAllowed,
    NoSuchDefinition,
    InvalidDefinition,
    InvalidStartCondition,
    NoRulesGiven,
} || error { OutOfMemory };


definitions: Definitions,
rules: std.ArrayListUnmanaged(Rule),
userSubroutines: ?[]u8 = null,
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
        .rules = try std.ArrayListUnmanaged(Rule).initCapacity(alloc, 10),
        .definitions = try Definitions.init(alloc),
    };
}

pub fn deinit(self: *LexParser) void {
    self.alloc.free(self.tokenizer.input);
    self.definitions.deinit(self.alloc);
    for (self.rules.items) |r| r.deinit(self.alloc);
    self.rules.deinit(self.alloc);
}

fn advance(self: *LexParser) !LexToken {
    return self.tokenizer.next();
}

fn logError(self: *LexParser, err: LexParserError) LexParserError {
    switch (err) {
        error.TooLongAName => std.log.err("{s}: bad substitution: too long a name", .{self.tokenizer.getFileName()}),
        error.RecursiveDefinitionNotAllowed => std.log.err("{s}: recursive definition not allowed", .{self.tokenizer.getFileName()}),
        error.NoSuchDefinition => std.log.err("{s}: no such definition", .{self.tokenizer.getFileName()}),
        error.InvalidDefinition => std.log.err("{s}: invalid regex", .{self.tokenizer.getFileName()}),
        error.InvalidStartCondition => std.log.err("{s}: invalid start condition", .{self.tokenizer.getFileName()}),
        error.NoRulesGiven => std.log.err("{s}: no rule given", .{self.tokenizer.getFileName()}),
        else => {},
    }
    return err;
}

fn isValidName(slice: []u8) bool {
    if (slice.len == 0) return false;
    if (!(std.ascii.isAlphabetic(slice[0]) or slice[0] == '_')) return false;
    for (slice[1..]) |c| {
        if (!(std.ascii.isAlphanumeric(c) or c == '_')) return false;
    }
    return true;
}

fn expandDefinition(self: *LexParser, idef: usize, sdef: usize, edef: usize, def: *[]u8) !struct { []u8, usize } {
    var buffer: [256]u8 = .{0} ** 256;
    var stream = std.io.fixedBufferStream(&buffer);
    var writer = stream.writer();

    const substitute = blk: {
        for (self.definitions.definitions.items, 0..) |innerDef, it| {
            if (std.mem.eql(u8, innerDef.name, def.*[sdef + 1..edef])) {
                if (it == idef) return error.RecursiveDefinitionNotAllowed;
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
        var quote, var register = [_]bool{ false, false };
        var brace: usize = 0;
        var it: usize = 0;
        var sdef, var edef = [_]usize {0, 0};

        while (it < def.substitute.len) : (it += 1) {
            const curr: u8 = def.substitute[it];
            if (curr == '\\') { it += 1; continue; }

            switch (curr) {
                '"' => quote = if (brace == 0) !quote else quote,
                '[' => brace += if (!quote) 1 else 0,
                ']' => brace -|= if (!quote) 1 else 0,
                '{' => if (!quote and brace == 0) { register = true; sdef = it; },
                '}' => if (!quote and brace == 0) { 
                    if (register == false) return error.InvalidDefinition;
                    register = false; edef = it;
                    if (!isValidName(def.substitute[sdef + 1..edef])) {
                        continue;
                    }
                    const newSub, it = try self.expandDefinition(idef, sdef, edef, &def.substitute);
                    self.alloc.free(def.substitute);
                    def.substitute = newSub;
                    self.definitions.definitions.items[idef] = def;
                },
                else => {},
            }
        }
    }
}

fn expandRule(self: *LexParser, sSub: usize, eSub: usize, regex: *[]u8) !struct { []u8, usize } {
    var buffer: [256]u8 = .{0} ** 256;
    var stream = std.io.fixedBufferStream(&buffer);
    var writer = stream.writer();

    const substitute = blk: {
        for (self.definitions.definitions.items) |innerDef| {
            if (std.mem.eql(u8, innerDef.name, regex.*[sSub + 1..eSub])) {
                break :blk innerDef.substitute;
            }
        }
        return error.NoSuchDefinition;
    };

    var newIt: usize = 0;
    newIt += writer.write(regex.*[0..sSub]) catch return error.TooLongAName;
    newIt += writer.write(substitute) catch return error.TooLongAName;
    _ = writer.write(regex.*[eSub + 1..]) catch return error.TooLongAName;

    return .{
        try self.alloc.dupe(u8, std.mem.trimRight(u8, buffer[0..], "\x00\n ")),
        newIt - 1,
    };
}

fn expandRules(self: *LexParser) !void {
    for (0..self.rules.items.len) |idef| {
        var rule = self.rules.items[idef];
        var quote, var register = [_]bool{ false, false };
        var brace: usize = 0;
        var it: usize = 0;
        var sSub, var eSub = [_]usize {0, 0};

        // std.debug.print("Rule: {s}\n", .{rule});
        while (it < rule.regex.len) : (it += 1) {
            const curr: u8 = rule.regex[it];
            if (curr == '\\') { it += 1; continue; }
            // std.debug.print("char: {c}, quote: {}, brace: {d}\n", .{curr, quote, brace});

            switch (curr) {
                '"' => quote = if (brace == 0) !quote else quote,
                '[' => brace += if (!quote) 1 else 0,
                ']' => brace -|= if (!quote) 1 else 0,
                '{' => if (!quote and brace == 0) { register = true; sSub = it; },
                '}' => if (!quote and brace == 0) { 
                    if (register == false) {

                        // std.debug.print("Rule: {s}\n", .{rule});
                        return error.InvalidDefinition;
                    }
                    register = false; eSub = it;

                    if (!isValidName(rule.regex[sSub + 1..eSub])) 
                        continue;

                    const newSub, it = try self.expandRule(sSub, eSub, &rule.regex);
                    self.alloc.free(rule.regex);
                    rule.regex = newSub;
                    self.rules.items[idef] = rule;
                },
                else => {},
            }
        }
        // std.debug.print("After sub: {s}\n", .{rule.regex});
    }
}
fn parseDefinitions(self: *LexParser) !void {
    //Skip potential blank lines
    self.tokenizer.eatWhitespacesAndNewline();

    //Parse definition section
    outer: while (true) {
        const token = try self.advance();
        // std.debug.print("TOKEN: {}", .{token});
        switch (token) {
            .cCode => |code| try self.definitions.cCodeFragments.append(self.alloc, code),
            .definition => |def| try self.definitions.definitions.append(
                self.alloc, .{
                    .name = def.name,
                    .substitute = try self.alloc.dupe(u8, def.substitute) 
            }),
            .startCondition => |start| { 
                defer start.name.deinit();
                for (start.name.items) |n| {
                    try self.definitions.startConditions.data.append(self.alloc, .{.type = start.type, .name = n});
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
    std.debug.print("{}\n", .{self.definitions});
}

fn extractStartConditions(self: *LexParser) !void {
    for (self.rules.items) |*r| {
        if (r.regex[0] != '<') 
            continue;

        var outer_it: usize = 1;
        outer: while (true) {
            if (r.regex[outer_it] == '>') break;
            if (r.regex[outer_it] == ',') outer_it += 1;

            for (self.definitions.startConditions.data.items) |sc| {
                if (std.mem.startsWith(u8, r.regex[outer_it..], sc.name)) {
                    std.debug.print("Matched with: {s}\n", .{sc.name});
                    try r.sc.append(sc);
                    outer_it += sc.name.len;
                    continue :outer;
                }
            }
            return error.InvalidStartCondition;
        }

        for (r.sc.items) |some| {
            std.debug.print("{}\n", .{some});
        }

    }
}

fn parseRules(self: *LexParser) !void {
    //Skip potential blank lines
    self.tokenizer.eatWhitespacesAndNewline();

    outer: while (true) {
        const token = try self.advance();
        // std.debug.print("Token: {}\n", .{token});
        switch (token) {
            .rule => |r| try self.rules.append(self.alloc, Rule.init(self.alloc, try self.alloc.dupe(u8, r.regex), r.code)),
            .EOF, .EndOfSection => break: outer,
            else => {}
        }
    }
    if (self.rules.items.len == 0) {
        return self.logError(error.NoRulesGiven);
    }
    //Expand {DEFINITION}
    self.expandRules() catch |e| return self.logError(e);
    self.extractStartConditions() catch |e| return self.logError(e);

    for (self.rules.items) |item| std.debug.print("{}\n", .{item});
}

fn parseUserSubroutines(self: *LexParser) !void {
    //Skip potential blank lines
    self.tokenizer.eatWhitespacesAndNewline();
    const maybeSuroutine = try self.advance();
    switch (maybeSuroutine) {
        .userSuboutines => |routine| self.userSubroutines = routine,
        else => self.userSubroutines = null,
    }
    // std.debug.print("Subroutine: \"{s}\"\n", .{self.userSubroutines orelse "null"});
}

pub fn parse(self: *LexParser) !void {

    try self.parseDefinitions();
    self.tokenizer.changeContext(.Rules);
    try self.parseRules();
    self.tokenizer.changeContext(.UserSubroutines);
    try self.parseUserSubroutines();

}
