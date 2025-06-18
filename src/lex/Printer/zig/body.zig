const G               = @import("../../../globals.zig");
const LexOptions      = G.LexOptions;
const LexParser       = @import("../../Parser.zig");

const Templates       = @import("Templates.zig");
const TemplatesYYMore = @import("TemplatesYYMore.zig");
const TemplatesREJECT = @import("TemplatesREJECT.zig");

const Actions         = @import("actions.zig");

pub fn printBody(lexParser: LexParser, writer: anytype) anyerror!void {
    _ = try writer.write(Templates.sectionOne);

    if (!G.options.fast)
        _ = try writer.write(Templates.nextStateFn);

    if (!G.options.yyWrapDefined)
        _ = try writer.write(Templates.defaultYyWrap);

    if (!G.options.needYYMore)
        _ = try writer.write(TemplatesYYMore.noYYmoreFallback);

    if (!G.options.needREJECT) {
        _ = try writer.write(TemplatesREJECT.noRejectFallback);
    } else {
        _ = try writer.write(TemplatesREJECT.rejectDefinition);
    }

    _ = try writer.write(Templates.sectionTwo);


    if (G.options.needYYMore)
        _ = try writer.write(TemplatesYYMore.yyMoreSectionOne);

    if (!G.options.needREJECT) {
        _ = try writer.write(Templates.sectionThree);
        if (G.options.fast)
            _  = try writer.write(Templates.nextLogicFast)
        else
            _ = try writer.write(Templates.nextLogic);
        _ = try writer.write(Templates.sectionThreeP2);
    } else {
        _ = try writer.write(TemplatesREJECT.rejectBodySectionThree);
        if (G.options.fast)
            _  = try writer.write(Templates.nextLogicFast)
        else
            _ = try writer.write(Templates.nextLogic);
        _ = try writer.write(TemplatesREJECT.rejectBodySectionThreeP2);
    }

    if (G.options.needTcBacktracking)
        _ = try writer.write(TemplatesYYMore.tcBacktracking);

    if (!G.options.needYYMore) {
        _ = try writer.write(Templates.sectionFour);
    } else {
        _ = try writer.write(TemplatesYYMore.yyMoreSectionTwo);
    }

    try Actions.printActions(lexParser, writer);

    if (!G.options.needYYMore) {
        _ = try writer.write(Templates.sectionFive);
    } else {
        _ = try writer.write(TemplatesYYMore.yyMoreBodySectionFive);
    }

    if (G.options.needREJECT)
        _ = try writer.write(TemplatesREJECT.rejectResetDirective);

    if (!G.options.needYYMore) {
        _ = try writer.write(Templates.sectionSix);
    } else {
        _ = try writer.write(TemplatesYYMore.yyMoreBodySectionSix);
    }

    if (!G.options.mainDefined) {
        _ = try writer.write(Templates.defaultMain);
    }
}

