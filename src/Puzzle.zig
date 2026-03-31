const Puzzle = @This();

pub const End = enum {
    // zig fmt: off
    a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z, 
    // zig fmt: on

    pub fn toEndFlags(self: End) u32 {
        return @as(u32, 1) << @intFromEnum(self);
    }
};

col_hints: []const ?u8,
row_hints: []const ?u8,
nodes: []const ?End,

const ValidityError = error{ NodesInvalidLen, UnpairedEnds };

pub fn validate(self: *const Puzzle) ValidityError!void {
    if (self.nodes.len != self.colCount() * self.rowCount()) return ValidityError.NodesInvalidLen;

    var cell_hint_counts: [26]u8 = .{0} ** 26;
    for (self.nodes) |it| {
        if (it) |end| cell_hint_counts[@intFromEnum(end)] += 1;
    }
    for (cell_hint_counts) |it| {
        if (it != 2 and it != 0) return ValidityError.UnpairedEnds;
    }
}

pub fn colCount(self: *const Puzzle) usize {
    return self.col_hints.len + 1;
}

pub fn rowCount(self: *const Puzzle) usize {
    return self.row_hints.len + 1;
}
