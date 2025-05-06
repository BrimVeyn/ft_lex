const ColorCycler = @This();

pub fn getColor(_: *ColorCycler, idx: usize) []const u8 {
    const map = [_][]const u8 {
        "lightgoldenrod2", "mediumpurple", "moccasin",
        "lightblue", "lightsalmon", "khaki1",
        "palegreen", "skyblue", "salmon",
        "turquoise", "coral", "plum",
        "lightsteelblue", "orchid", "peachpuff",
        "honeydew", "lavender", "lemonchiffon",
    }; 
    return map[idx % map.len];
}
