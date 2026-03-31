const std = @import("std");
const Puzzle = @import("Puzzle.zig");
const Solver = @import("Solver.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const a = arena.allocator();

    const puzzle = Puzzle{
        .col_hints = &.{ 1, 3, 4, 3 },
        .row_hints = &.{ 1, 3, 2, 1 },
        .nodes = &.{
            null,
            .a,
            null,
            null,
            null,
            null,
            null,
            null,
            .c,
            null,
            null,
            .b, 
            null,
            null,
            .a,
            null,
            .c,
            null,
            null,
            null,
            null,
            null,
            null,
            .b,
            null,
        },
    };

    const solver = try Solver.from(a, &puzzle);
    solver.printData();
    solver.printGrid();
}
