const std        = @import("std");
const mem        = std.mem;
const LexParser  = @import("../../Parser.zig");
const RuleModule = @import("../../Rules.zig");
const Rule       = RuleModule.Rule;

const labeledActionsHead =
\\    do_action: switch (accept_id) {
\\
;

const actionsHead =
\\    switch (accept_id) {
\\
;

const actionsTail =
\\        else => yyout.?.writer().print("error: Unknown action id: {d}", .{accept_id}) catch {},
\\    }
\\
;

const ruleHead =
\\        {d} =>
\\
;

const tcLeft =
\\
\\        yy_buf_pos = start_pos + {d};
\\        yytext = yy_buffer[start_pos..yy_buf_pos];
\\
;

const tcRight =
\\
\\        yy_buf_pos -= {d};
\\        yytext = yy_buffer[start_pos..yy_buf_pos];
\\
;


pub fn atLeaseOneOr(rules: []Rule) bool {
    for (rules) |rule| {
        if (std.mem.eql(u8, rule.code.code, "|"))
            return true;
    }
    return false;
}


pub fn printActions(lParser: LexParser, writer: anytype) !void {
    if (atLeaseOneOr(lParser.rules.items))
        _ = try writer.write(labeledActionsHead)
    else
        _ = try writer.write(actionsHead);

    for (lParser.rules.items, 0..) |rule, i| {
        _ = try writer.print(ruleHead, .{i + 1});
        _ = try writer.write("    {");

        //NOTE: Instead of generating the backtracking loop, we produce
        //these small code pieces to backtrack instantaneously
        if (rule.trailingContext.value) |leng| {
            switch (rule.trailingContext.side) {
                .Left => try writer.print(tcLeft, .{leng}),
                .Right => try writer.print(tcRight, .{leng}),
            }
        }

        if (mem.eql(u8, "|", rule.code.code)) {
            _ = try writer.print("continue: do_action {d};\n", .{i + 2});
        } else {
            _ = try writer.write(rule.code.code);
        }

        _ = try writer.write("\n    },\n");
    }
    _ = try writer.write(actionsTail);
}
