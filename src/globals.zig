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
    maxPositions: usize       = 5000,
    maxStates: usize          = 32000,
    maxTransitions: usize     = 10000,
    maxParseTreeNodes: usize  = 2000,
    maxPackedCharClass: usize = 2000,
    maxSizeDFA: usize         = 10000,
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
