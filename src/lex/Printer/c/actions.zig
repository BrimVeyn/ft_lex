const std                 =  @import("std");
const mem                 =  std.mem;
const LexParser           =  @import("../../Parser.zig");

const actionsHead =
\\    switch (accept_id) {
\\
;

const actionsTail =
\\        default:
\\            fprintf(stderr, "Unknown action id: %d\n", accept_id);
\\            break;
\\        }
\\
;

const ruleHead =
\\        case {d}:
\\
;

const ruleTail =
\\
\\        break;
\\
;

const tcLeft =
\\
\\        yy_buffer[yy_buf_pos] = yy_hold_char;
\\        yy_buf_pos = start_pos + {d};
\\        yyleng = {0d};
\\        YY_DO_BEFORE_ACTION
\\
;

const tcRight =
\\
\\        yy_buffer[yy_buf_pos] = yy_hold_char;
\\        yy_buf_pos -= {d};
\\        yyleng -= {0d};
\\        YY_DO_BEFORE_ACTION
\\
;

pub fn printActions(lParser: LexParser, writer: anytype) !void {
    _ = try writer.write(actionsHead);
    for (lParser.rules.items, 0..) |rule, i| {
        _ = try writer.print(ruleHead, .{i + 1});
        _ = try writer.write("{");

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
        if (!mem.eql(u8, "|", rule.code.code))
            _ = try writer.write(ruleTail);

        _ = try writer.write("\n}");
    }
    _ = try writer.write(actionsTail);
}
