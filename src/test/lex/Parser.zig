// const std = @import("std");
// const LexParser = @import("../../lex/Parser.zig");
//
// test "One definition, one rule" {
//     const alloc = std.testing.allocator;
//     const fileName = "./src/test/lex/inputs/one_definition_one_rule.l";
//     const sections = try LexParser.fileMode(alloc, @constCast(fileName[0..]));
//     defer {
//         alloc.free(sections.raw);
//         alloc.free(sections.lines);
//     }
//
//     const expected = [_][]const u8{ 
//         "DIGIT [0-9]" 
//     };
//
//     try std.testing.expect(sections.definitions != null);
//     try std.testing.expect(expected.len == sections.definitions.?.len);
//
//     if (sections.definitions) |defs| {
//         for (defs, 0..) |def, i| {
//             try std.testing.expectEqualStrings(def, expected[i]);
//         }
//     } else {
//         return error.DefIsNull;
//     }
// }
//
// test "No definition, one rule" {
//     const alloc = std.testing.allocator;
//     const fileName = "./src/test/lex/inputs/no_definitions.l";
//     const sections = try LexParser.fileMode(alloc, @constCast(fileName[0..]));
//     defer {
//         alloc.free(sections.raw);
//         alloc.free(sections.lines);
//     }
//     try std.testing.expectEqual(null, sections.definitions);
// }
//
// test "Premature EOF" {
//     const alloc = std.testing.allocator;
//     const fileName = "./src/test/lex/inputs/premature_eof.l";
//     try std.testing.expectError(error.PrematureEOF, LexParser.fileMode(alloc, @constCast(fileName[0..])));
// }
//
// test "Minimum format" {
//     const alloc = std.testing.allocator;
//     const fileName = "./src/test/lex/inputs/minimum_format.l";
//     const sections = try LexParser.fileMode(alloc, @constCast(fileName[0..]));
//     defer {
//         alloc.free(sections.raw);
//         alloc.free(sections.lines);
//     }
//     try std.testing.expectEqual(null, sections.definitions);
// }
