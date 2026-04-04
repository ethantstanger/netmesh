const std = @import("std");
const Puzzle = @import("Puzzle.zig");

const Solver = @This();

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

        const full_side_n = full_nw | full_n | full_ne;
        const full_side_e = full_ne | full_e | full_se;
        const full_side_s = full_se | full_s | full_sw;
        const full_side_w = full_sw | full_w | full_nw;

        const full = full_n | full_ne | full_e | full_se | full_s | full_sw | full_w | full_nw;
        const full_end = n | ne | e | se | s | sw | w | nw;
        const full_path = full & ~full_end;
        // zig fmt: on
};

const Node = struct {
    seg_flags: u32,
    end_flags: u32,

    fn index(self: *const Node, solver: *const Solver) usize {
        return self - solver.nodes.ptr;
    }

    fn onSideW(self: *const Node, solver: *const Solver) bool {
        return self.index(solver) % solver.puzzle.size() == 0;
    }

    fn onSideE(self: *const Node, solver: *const Solver) bool {
        return (self.index(solver) + 1) % solver.puzzle.size() == 0;
    }

    fn onSideN(self: *const Node, solver: *const Solver) bool {
        return @divTrunc(self.index(solver), solver.puzzle.size()) == 0;
    }

    fn onSideS(self: *const Node, solver: *const Solver) bool {
        return @divTrunc(self.index(solver), solver.puzzle.size()) + 1 == solver.puzzle.size();
    }

    fn n(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideN(solver)) return null;
        return &solver.nodes[self.index(solver) - solver.puzzle.size()];
    }

    fn ne(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideN(solver) or self.onSideE(solver)) return null;
        return &solver.nodes[self.index(solver) - solver.puzzle.size() + 1];
    }

    fn e(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideE(solver)) return null;
        return &solver.nodes[self.index(solver) + 1];
    }

    fn se(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideE(solver) or self.onSideS(solver)) return null;
        return &solver.nodes[self.index(solver) + solver.puzzle.size() + 1];
    }

    fn s(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideS(solver)) return null;
        return &solver.nodes[self.index(solver) + solver.puzzle.size()];
    }

    fn sw(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideS(solver) or self.onSideW(solver)) return null;
        return &solver.nodes[self.index(solver) + solver.puzzle.size() - 1];
    }

    fn w(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideW(solver)) return null;
        return &solver.nodes[self.index(solver) - 1];
    }

    fn nw(self: *const Node, solver: *const Solver) ?*Node {
        if (self.onSideW(solver) or self.onSideN(solver)) return null;
        return &solver.nodes[self.index(solver) - solver.puzzle.size() - 1];
    }

    fn setSegFlagsAndPropagate(self: *Node, solver: *const Solver, new_flags: u32) void {
        const prop_n = self.seg_flags & seg_mask.full_n != 0 and new_flags & seg_mask.full_n == 0;
        const prop_ne = self.seg_flags & seg_mask.full_ne != 0 and new_flags & seg_mask.full_ne == 0;
        const prop_e = self.seg_flags & seg_mask.full_e != 0 and new_flags & seg_mask.full_e == 0;
        const prop_se = self.seg_flags & seg_mask.full_se != 0 and new_flags & seg_mask.full_se == 0;
        const prop_s = self.seg_flags & seg_mask.full_s != 0 and new_flags & seg_mask.full_s == 0;
        const prop_sw = self.seg_flags & seg_mask.full_sw != 0 and new_flags & seg_mask.full_sw == 0;
        const prop_w = self.seg_flags & seg_mask.full_w != 0 and new_flags & seg_mask.full_w == 0;
        const prop_nw = self.seg_flags & seg_mask.full_nw != 0 and new_flags & seg_mask.full_nw == 0;

        if (prop_n) {
            if (self.n(solver)) |it| it.seg_flags &= ~seg_mask.full_s;
        }
        if (prop_ne) {
            if (self.ne(solver)) |it| it.seg_flags &= ~seg_mask.full_sw;
        }
        if (prop_e) {
            if (self.e(solver)) |it| it.seg_flags &= ~seg_mask.full_w;
        }
        if (prop_se) {
            if (self.se(solver)) |it| it.seg_flags &= ~seg_mask.full_nw;
        }
        if (prop_s) {
            if (self.s(solver)) |it| it.seg_flags &= ~seg_mask.full_n;
        }
        if (prop_sw) {
            if (self.sw(solver)) |it| it.seg_flags &= ~seg_mask.full_ne;
        }
        if (prop_w) {
            if (self.w(solver)) |it| it.seg_flags &= ~seg_mask.full_e;
        }
        if (prop_nw) {
            if (self.nw(solver)) |it| it.seg_flags &= ~seg_mask.full_se;
        }

        self.seg_flags = new_flags;
    }

    fn areEndFlagsCollapsed(self: *const Node) bool {
        return self.end_flags != 0 and (self.end_flags & (self.end_flags - 1) == 0);
    }

    fn getEndPrintChar(self: *const Node) ?u8 {
        if (!self.areEndFlagsCollapsed()) return null;
        return 'A' + @as(u8, @ctz(self.end_flags));
    }

    fn getPrintColor(self: *const Node) *const [7:0]u8 {
        if (!self.areEndFlagsCollapsed()) return "\x1b[0;37m";
        return switch (@as(u8, @ctz(self.end_flags)) % 6) {
            0 => "\x1b[0;31m",
            1 => "\x1b[0;32m",
            2 => "\x1b[0;33m",
            3 => "\x1b[0;34m",
            4 => "\x1b[0;35m",
            else => "\x1b[0;37m",
        };
    }
};

const Cell = struct {
    const CutState = enum { untakeable, untaken, taken };

    nw: *Node,
    ne: *Node,
    sw: *Node,
    se: *Node,
    cut_state: CutState,

    fn isSingleUntaken(self: *const Cell) bool {
        if (self.cut_state != .untaken) return false;
        return true;
    }

    fn takeCut(self: *const Cell, solver: *const Solver) void {
        self.nw.setSegFlagsAndPropagate(solver, self.nw.seg_flags & seg_mask.full_se);
        self.ne.setSegFlagsAndPropagate(solver, self.ne.seg_flags & seg_mask.full_sw);
        self.sw.setSegFlagsAndPropagate(solver, self.sw.seg_flags & seg_mask.full_ne);
        self.se.setSegFlagsAndPropagate(solver, self.se.seg_flags & seg_mask.full_nw);

        self.nw.setSegFlagsAndPropagate(solver, self.nw.seg_flags & ~(seg_mask.full_e | seg_mask.full_s));
        self.ne.setSegFlagsAndPropagate(solver, self.ne.seg_flags & ~(seg_mask.full_w | seg_mask.full_s));
        self.sw.setSegFlagsAndPropagate(solver, self.sw.seg_flags & ~(seg_mask.full_e | seg_mask.full_n));
        self.se.setSegFlagsAndPropagate(solver, self.se.seg_flags & ~(seg_mask.full_w | seg_mask.full_n));
    }
};

puzzle: *const Puzzle,
nodes: []Node,
last_read_cells: []Cell,

pub const FromError = error{ EndsInvalidLen, EndsMustBePairs };

pub fn from(a: std.mem.Allocator, puzzle: *const Puzzle) !Solver {
    try puzzle.validate();

    const nodes = try a.alloc(Node, puzzle.size() * puzzle.size());
    errdefer a.free(nodes);

    const llc = try a.alloc(Cell, puzzle.size());
    errdefer a.free(llc);

    const end_flags = (@as(u32, 1) << @intCast(puzzle.end_pairs.len)) - 1;
    @memset(nodes, .{ .seg_flags = seg_mask.full_path, .end_flags = end_flags });

    var solver = Solver{ .puzzle = puzzle, .nodes = nodes, .last_read_cells = llc };
    for (puzzle.end_pairs, 0..) |pair, i| {
        for (pair) |it| {
            solver.node(it.x, it.y).end_flags = @as(u32, 1) << @intCast(i);
        }
    }

    for (solver.nodes) |*it| {
        if (it.onSideN(&solver)) it.seg_flags &= ~seg_mask.full_side_n;
        if (it.onSideE(&solver)) it.seg_flags &= ~seg_mask.full_side_e;
        if (it.onSideS(&solver)) it.seg_flags &= ~seg_mask.full_side_s;
        if (it.onSideW(&solver)) it.seg_flags &= ~seg_mask.full_side_w;
    }

    return solver;
}

const SolveError = error{ImpossibleCutHint};

pub fn solve(self: *const Solver) SolveError!void {
    self.collapseAdjacentDisparateEnds();

    while (true) {
        var buffer: [1024]u8 = undefined;
        var threaded = std.Io.Threaded.init_single_threaded;
        const io = threaded.io();
        var reader = std.Io.File.stdin().reader(io, &buffer);
        _ = reader.interface.takeByte() catch unreachable;

        self.printGrid();

        for (0..self.puzzle.cut_hints.len) |i| {
            try self.collapseCells(.col, i);
            try self.collapseCells(.row, i);
        }
    }
}

fn collapseAdjacentDisparateEnds(self: *const Solver) void {
    for (self.nodes) |*a| {
        if (a.e(self)) |b| inner: {
            if (a.end_flags & b.end_flags != 0) break :inner;
            a.seg_flags &= ~seg_mask.full_e;
            b.seg_flags &= ~seg_mask.full_w;
        }

        if (a.se(self)) |b| inner: {
            if (a.end_flags & b.end_flags != 0) break :inner;
            a.seg_flags &= ~seg_mask.full_se;
            b.seg_flags &= ~seg_mask.full_nw;
        }

        if (a.s(self)) |b| inner: {
            if (a.end_flags & b.end_flags != 0) break :inner;
            a.seg_flags &= ~seg_mask.full_s;
            b.seg_flags &= ~seg_mask.full_n;
        }

        if (a.sw(self)) |b| inner: {
            if (a.end_flags & b.end_flags != 0) break :inner;
            a.seg_flags &= ~seg_mask.full_sw;
            b.seg_flags &= ~seg_mask.full_ne;
        }
    }
}

const Axis = enum { col, row };
fn collapseCells(self: *const Solver, axis: Axis, i: usize) SolveError!void {
    const hint = (if (axis == .col) self.puzzle.cut_hints[i].col else self.puzzle.cut_hints[i].row) orelse return;
    const cells_meta = self.readCellsWithMeta(axis, i);

    const taken_and_untaken_cuts = cells_meta.taken_cuts + cells_meta.untaken_cuts;
    if (taken_and_untaken_cuts < hint) return SolveError.ImpossibleCutHint;
    if (taken_and_untaken_cuts != hint) return;

    for (self.last_read_cells) |c| {
        if (c.isSingleUntaken()) c.takeCut(self);
    }
}

const CellsMeta = struct {
    taken_cuts: u8,
    untaken_cuts: u8,
};

fn readCellsWithMeta(self: *const Solver, axis: Axis, i: usize) CellsMeta {
    var cells_meta = CellsMeta{ .taken_cuts = 0, .untaken_cuts = 0 };
    for (0..self.puzzle.cut_hints.len) |j| {
        const c = if (axis == .col) self.cell(i, j) else self.cell(j, i);
        self.last_read_cells[j] = c;

        if (c.cut_state == .taken) cells_meta.taken_cuts += 1;
        if (c.cut_state == .untaken) cells_meta.untaken_cuts += 1;
    }

    return cells_meta;
}

fn cell(self: *const Solver, col: usize, row: usize) Cell {
    const nw = self.node(col, row);
    const ne = self.node(col + 1, row);
    const sw = self.node(col, row + 1);
    const se = self.node(col + 1, row + 1);

    const cut_state: Cell.CutState = state: {
        if (nw.seg_flags & ~(seg_mask.full_e | seg_mask.full_s) == 0) break :state .untakeable;
        if (ne.seg_flags & ~(seg_mask.full_w | seg_mask.full_s) == 0) break :state .untakeable;
        if (sw.seg_flags & ~(seg_mask.full_e | seg_mask.full_n) == 0) break :state .untakeable;
        if (se.seg_flags & ~(seg_mask.full_w | seg_mask.full_n) == 0) break :state .untakeable;

        const is_left = nw.seg_flags & ~seg_mask.full_se == 0;
        const is_right = ne.seg_flags & ~seg_mask.full_sw == 0;
        if (is_left and is_right) break :state .taken;

        const has_left = nw.seg_flags & seg_mask.full_se != 0;
        const has_right = ne.seg_flags & seg_mask.full_sw != 0;
        if (has_left and has_right) break :state .untaken;
        break :state .untakeable;
    };

    return .{ .nw = nw, .ne = ne, .sw = sw, .se = se, .cut_state = cut_state };
}

fn node(self: *const Solver, x: usize, y: usize) *Node {
    return &self.nodes[(y * self.puzzle.size()) + x];
}

pub fn printData(self: *const Solver) void {
    const print = std.debug.print;

    print("col_hints:\n\n", .{});
    for (self.puzzle.cut_hints) |it| {
        print("{?}\n", .{it.col});
    }

    print("\nrow_hints:\n\n", .{});
    for (self.puzzle.cut_hints) |it| {
        print("{?}\n", .{it.row});
    }

    print("\nnodes (seg_flags | end_flags):\n\n", .{});
    for (self.nodes) |it| {
        print("{b:0>32} | {b:0>32}\n", .{ it.seg_flags, it.end_flags });
    }
}

pub fn printGrid(self: *const Solver) void {
    const print = std.debug.print;

    print("     ", .{});
    for (self.puzzle.cut_hints) |it| {
        if (it.col) |hint| print(" {d:0>2}", .{hint}) else print("   ", .{});
    }
    print("\n   \u{250c}", .{});
    for (0..self.puzzle.size()) |_| {
        print("\u{2500}" ** 3, .{});
    }

    for (0..self.puzzle.size()) |y| {
        if (y != 0) {
            const hint = self.puzzle.cut_hints[y - 1].row;
            if (hint) |it| print("{d:0>2}", .{it}) else print("  ", .{});
            print(" \u{2502}", .{});
        }

        for (0..self.puzzle.size()) |x| {
            const n = self.node(x, y);
            const c = n.getPrintColor();
            const str1 = if (n.seg_flags & seg_mask.full_nw != 0) "\u{2572}" else " ";
            const str2 = if (n.seg_flags & seg_mask.full_n != 0) "\u{2502}" else " ";
            const str3 = if (n.seg_flags & seg_mask.full_ne != 0) "\u{2571}" else " ";
            print("{s}{s}{s}{s}\x1b[0m", .{ c, str1, str2, str3 });
        }
        print("\n   \u{2502}", .{});
        for (0..self.puzzle.size()) |x| {
            const n = self.node(x, y);
            const c = n.getPrintColor();
            const str1 = if (n.seg_flags & seg_mask.full_w != 0) "\u{2500}" else " ";
            const str2 = if (n.getEndPrintChar()) |it| &.{it} else "\u{2022}";
            const str3 = if (n.seg_flags & seg_mask.full_e != 0) "\u{2500}" else " ";
            print("{s}{s}{s}{s}\x1b[0m", .{ c, str1, str2, str3 });
        }
        print("\n   \u{2502}", .{});
        for (0..self.puzzle.size()) |x| {
            const n = self.node(x, y);
            const c = n.getPrintColor();
            const str1 = if (n.seg_flags & seg_mask.full_sw != 0) "\u{2571}" else " ";
            const str2 = if (n.seg_flags & seg_mask.full_s != 0) "\u{2502}" else " ";
            const str3 = if (n.seg_flags & seg_mask.full_se != 0) "\u{2572}" else " ";
            print("{s}{s}{s}{s}\x1b[0m", .{ c, str1, str2, str3 });
        }
        print("\n", .{});
    }
}
