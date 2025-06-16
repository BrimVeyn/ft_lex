const G = @This();

pub const YYTextType = enum {
    Array,
    Pointer,
};

pub const LexOptions = struct {
    inputName: []const u8     = "stdin",
    t: bool                   = false,
    n: bool                   = false,
    v: bool                   = false,
    fast: bool                = false,
    zig: bool                 = false,
    mainDefined: bool         = false,
    yyWrapDefined: bool       = false,
    needTcBacktracking: bool  = false,
    needYYMore: bool          = false,
    needREJECT: bool          = false,
    maxPositions: usize       = 2500,
    maxStates: usize          = 500,
    maxTransitions: usize     = 2000,
    maxParseTreeNodes: usize  = 1000,
    maxPackedCharClass: usize = 1000,
    maxSizeDFA: usize         = 3000,
    yyTextType: YYTextType    = .Pointer,
};

pub var options = LexOptions{};

pub var ParseTreeNodes: usize  = 0;
pub var PackedCharClass: usize = 0;
pub var States: usize          = 0;
pub var Positions: usize       = 0;
pub var Transitions: usize     = 0;
pub var DFASize: usize         = 0;


pub fn resetGlobals() void {
    options         = .{};
    ParseTreeNodes  = 0;
    PackedCharClass = 0;
    States          = 0;
    Positions       = 0;
    Transitions     = 0;
    DFASize         = 0;
}

pub fn incrementParseTreeNodes() void {
    ParseTreeNodes += 1;
}
