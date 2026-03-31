const std = @import("std");
const Puzzle = @import("Puzzle.zig");

const Solver = @This();

const Cell = struct {
    const seg_mask = struct {
        // zig fmt: off
        const n     : u32 = 0x00000001;
        const n_ne  : u32 = 0x00000002;
        const n_e   : u32 = 0x00000004;
        const n_se  : u32 = 0x00000008;
        const ne    : u32 = 0x00000010;
        const ne_e  : u32 = 0x00000020;
        const ne_se : u32 = 0x00000040;
        const ne_s  : u32 = 0x00000080;
        const e     : u32 = 0x00000100;
        const e_se  : u32 = 0x00000200;
        const e_s   : u32 = 0x00000400;
        const e_sw  : u32 = 0x00000800;
        const se    : u32 = 0x00001000;
        const se_s  : u32 = 0x00002000;
        const se_sw : u32 = 0x00004000;
        const se_w  : u32 = 0x00008000;
        const s     : u32 = 0x00010000;
        const s_sw  : u32 = 0x00020000;
        const s_w   : u32 = 0x00040000;
        const s_nw  : u32 = 0x00080000;
        const sw    : u32 = 0x00100000;
        const sw_w  : u32 = 0x00200000;
        const sw_nw : u32 = 0x00400000;
        const sw_n  : u32 = 0x00800000;
        const w     : u32 = 0x01000000;
        const w_nw  : u32 = 0x02000000;
        const w_n   : u32 = 0x04000000;
        const w_ne  : u32 = 0x08000000;
        const nw    : u32 = 0x10000000;
        const nw_n  : u32 = 0x20000000;
        const nw_ne : u32 = 0x40000000;
        const nw_e  : u32 = 0x80000000;

        const full_n  = n  | n_ne | n_e   | n_se | sw_n | w_n   | nw_n;
        const full_ne = ne | ne_e | ne_se | ne_s | w_ne | nw_ne | n_ne;
        const full_e  = e  | e_se | e_s   | e_sw | nw_e | n_e   | ne_e;
        const full_se = se | se_s | se_sw | se_w | n_se | ne_se | e_se;
        const full_s  = s  | s_sw | s_w   | s_nw | ne_s | e_s   | se_s;
        const full_sw = sw | sw_w | sw_nw | sw_n | e_sw | se_sw | s_sw;
        const full_w  = w  | w_nw | w_n   | w_ne | se_w | s_w   | sw_w;
        const full_nw = nw | nw_n | nw_ne | nw_e | s_nw | sw_nw | w_nw;

        const full = full_n | full_ne | full_e | full_se | full_s | full_sw | full_w | full_nw;
        // zig fmt: on
    };

    seg_flags: u32,
    end_flags: u32,

    fn index(self: *const Cell, solver: *const Solver) usize {
        return self - solver.cells.ptr;
    }

    fn onSideW(self: *const Cell, solver: *const Solver) bool {
        return self.index(solver) % solver.puzzle.colCount() == 0;
    }

    fn onSideE(self: *const Cell, solver: *const Solver) bool {
        return (self.index(solver) + 1) % solver.puzzle.colCount() == 0;
    }

    fn onSideN(self: *const Cell, solver: *const Solver) bool {
        return @divTrunc(self.index(solver), solver.puzzle.rowCount()) == 0;
    }

    fn onSideS(self: *const Cell, solver: *const Solver) bool {
        return @divTrunc(self.index(solver), solver.puzzle.rowCount()) + 1 == solver.puzzle.rowCount();
    }

    fn getN(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideN(solver)) return null;
        return &solver.cells[self.index(solver) - solver.puzzle.colCount()];
    }

    fn getNE(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideN(solver) or self.onSideE(solver)) return null;
        return &solver.cells[self.index(solver) - solver.puzzle.colCount() + 1];
    }

    fn getE(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideE(solver)) return null;
        return &solver.cells[self.index(solver) + 1];
    }

    fn getSE(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideE(solver) or self.onSideS(solver)) return null;
        return &solver.cells[self.index(solver) + solver.puzzle.colCount() + 1];
    }

    fn getS(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideS(solver)) return null;
        return &solver.cells[self.index(solver) + solver.puzzle.colCount()];
    }

    fn getSW(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideS(solver) or self.onSideW(solver)) return null;
        return &solver.cells[self.index(solver) + solver.puzzle.colCount() - 1];
    }

    fn getW(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideW(solver)) return null;
        return &solver.cells[self.index(solver) - 1];
    }

    fn getNW(self: *const Cell, solver: *const Solver) ?*Cell {
        if (self.onSideW(solver) or self.onSideN(solver)) return null;
        return &solver.cells[self.index(solver) - solver.puzzle.colCount() - 1];
    }
};

puzzle: *const Puzzle,
cells: []Cell,

pub const FromError = error{ EndsInvalidLen, EndsMustBePairs };

pub fn from(a: std.mem.Allocator, puzzle: *const Puzzle) !Solver {
    try puzzle.validate();

    const cells = try a.alloc(Cell, puzzle.nodes.len);
    @memset(cells, .{ .seg_flags = Cell.seg_mask.full, .end_flags = 0 });

    var default: u32 = 0;
    for (puzzle.nodes) |it| {
        if (it) |end| default |= end.toEndFlags();
    }

    for (puzzle.nodes, 0..) |it, i| {
        cells[i].end_flags |= if (it) |end| end.toEndFlags() else default;
    }

    var solver = Solver{ .puzzle = puzzle, .cells = cells };
    solver.collapseSideCells();
    return solver;
}

const SolveError = error{};

pub fn solve(self: *Solver) SolveError!void {
    self.collapseAdjacentDisparateEnds();
}

fn collapseSideCells(self: *Solver) void {
    for (self.cells) |*it| {
        const mask = Cell.seg_mask;
        if (it.onSideN(self)) it.seg_flags &= ~(mask.full_nw | mask.full_n | mask.full_ne);
        if (it.onSideE(self)) it.seg_flags &= ~(mask.full_ne | mask.full_e | mask.full_se);
        if (it.onSideS(self)) it.seg_flags &= ~(mask.full_se | mask.full_s | mask.full_sw);
        if (it.onSideW(self)) it.seg_flags &= ~(mask.full_sw | mask.full_w | mask.full_nw);
    }
}

fn collapseAdjacentDisparateEnds(self: *Solver) void {
    for (self.cells) |*a| {
        if (a.getE(self)) |b| inner: {
            if (a.end_flags & b.end_flags != 0) break :inner;
            a.seg_flags &= ~Cell.seg_mask.full_e;
            b.seg_flags &= ~Cell.seg_mask.full_s;
        }

        if (a.getSE(self)) |b| inner: {
            if (a.end_flags & b.end_flags != 0) break :inner;
            a.seg_flags &= ~Cell.seg_mask.full_se;
            b.seg_flags &= ~Cell.seg_mask.full_nw;
        }

        if (a.getS(self)) |b| inner: {
            if (a.end_flags & b.end_flags != 0) break :inner;
            a.seg_flags &= ~Cell.seg_mask.full_s;
            b.seg_flags &= ~Cell.seg_mask.full_n;
        }
    }
}

fn cell(self: *const Solver, col: usize, row: usize) *Cell {
    return &self.cells[(row * (self.puzzle.row_hints.len + 1)) + col];
}

pub fn printData(self: *const Solver) void {
    const print = std.debug.print;

    print("col_hints:\n\n", .{});
    for (self.puzzle.col_hints) |it| {
        print("{?}\n", .{it});
    }

    print("\nrow_hints:\n\n", .{});
    for (self.puzzle.row_hints) |it| {
        print("{?}\n", .{it});
    }

    print("\ncells (seg_flags | end_flags):\n\n", .{});
    for (self.cells) |it| {
        print("{b:0>32} | {b:0>32}\n", .{ it.seg_flags, it.end_flags });
    }
}

pub fn printGrid(self: *const Solver) void {
    const print = std.debug.print;

    print("     ", .{});
    for (self.puzzle.col_hints) |it| {
        if (it) |hint| print(" {d:0>2}", .{hint}) else print("   ", .{});
    }
    print("\n   \u{250c}", .{});
    for (0..self.puzzle.colCount()) |_| {
        print("\u{2500}" ** 3, .{});
    }

    for (0..self.puzzle.rowCount()) |row| {
        if (row != 0) {
            const hint = self.puzzle.row_hints[row - 1];
            if (hint) |it| print("{d:0>2}", .{it}) else print("  ", .{});
            print(" \u{2502}", .{});
        }

        for (0..self.puzzle.colCount()) |col| {
            const c = self.cell(col, row);
            const str1 = if (c.seg_flags & Cell.seg_mask.nw != 0) "\u{2572}" else " ";
            const str2 = if (c.seg_flags & Cell.seg_mask.n != 0) "\u{2502}" else " ";
            const str3 = if (c.seg_flags & Cell.seg_mask.ne != 0) "\u{2571}" else " ";
            print("{s}{s}{s}", .{ str1, str2, str3 });
        }
        print("\n   \u{2502}", .{});
        for (0..self.puzzle.colCount()) |col| {
            const c = self.cell(col, row);
            const str1 = if (c.seg_flags & Cell.seg_mask.w != 0) "\u{2500}" else " ";
            const collapsed = c.end_flags != 0 and (c.end_flags & (c.end_flags - 1) == 0);
            const str2 = if (collapsed) &.{'A' + @as(u8, @ctz(c.end_flags))} else "\u{2022}";
            const str3 = if (c.seg_flags & Cell.seg_mask.e != 0) "\u{2500}" else " ";
            print("{s}{s}{s}", .{ str1, str2, str3 });
        }
        print("\n   \u{2502}", .{});
        for (0..self.puzzle.colCount()) |col| {
            const c = self.cell(col, row);
            const str1 = if (c.seg_flags & Cell.seg_mask.sw != 0) "\u{2571}" else " ";
            const str2 = if (c.seg_flags & Cell.seg_mask.s != 0) "\u{2502}" else " ";
            const str3 = if (c.seg_flags & Cell.seg_mask.se != 0) "\u{2572}" else " ";
            print("{s}{s}{s}", .{ str1, str2, str3 });
        }
        print("\n", .{});
    }
}
