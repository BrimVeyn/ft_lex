const G = @This();

pub const LexOptions = struct {
    inputName: []const u8    = "stdin",
    t: bool                  = false,
    n: bool                  = false,
    v: bool                  = false,
    f: bool                  = false,
    needTcBacktracking: bool = false,
    needYYMore: bool         = false,
};

pub var options = LexOptions{};
