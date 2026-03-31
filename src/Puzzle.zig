const Puzzle = @This();

pub const End = enum { a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z };

col_hints: []const ?u8,
row_hints: []const ?u8,
nodes: []const ?End,

const ValidityError = error{NodesInvalidLen, UnpairedEnds};

pub fn validate(self: *const Puzzle) ValidityError!void {
    if (self.nodes.len != self.colCount() * self.rowCount()) return ValidityError.NodesInvalidLen;

    var cell_hint_counts: [26]u8 = .{0} ** 26;
    for (self.nodes) |it| {
        if (it == null) continue;
        cell_hint_counts[@intFromEnum(it.?)] += 1;
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
