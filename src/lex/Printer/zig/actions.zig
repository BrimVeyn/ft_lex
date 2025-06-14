const std                 =  @import("std");
const mem                 =  std.mem;
const LexParser           =  @import("../../Parser.zig");

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
\\        YY_DO_BEFORE_ACTION();
\\
;

const tcRight =
\\
\\        yy_buf_pos -= {d};
\\        yytext = yy_buffer[start_pos..yy_buf_pos];
\\        YY_DO_BEFORE_ACTION();
\\
;

pub fn printActions(lParser: LexParser, writer: anytype) !void {
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

        _ = try writer.write(rule.code.code);

        //Do not insert break statement if the action is fallthrough
        //TODO: fuck
        
        // if (!mem.eql(u8, "|", rule.code.code))
        //     _ = try writer.write(ruleTail);

        _ = try writer.write("\n    },\n");
    }
    _ = try writer.write(actionsTail);
}
