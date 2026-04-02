const std = @import("std");
const Puzzle = @import("Puzzle.zig");
const Solver = @import("Solver.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const puzzle = Puzzle{
        .cut_hints = &.{
            .{ .col = 2, .row = null },
            .{ .col = null, .row = null },
            .{ .col = null, .row = null },
            .{ .col = null, .row = 1 },
            .{ .col = 3, .row = 1 },
        },
        .end_pairs = &.{
            .{ .{ .x = 0, .y = 1 }, .{ .x = 2, .y = 3 } },
            .{ .{ .x = 3, .y = 1 }, .{ .x = 3, .y = 4 } },
            .{ .{ .x = 2, .y = 2 }, .{ .x = 4, .y = 4 } },
            .{ .{ .x = 4, .y = 1 }, .{ .x = 3, .y = 5 } },
        },
    };

    var solver = try Solver.from(a, &puzzle);
    solver.solve() catch |err| {
        std.debug.print("==============================\n{}\n==============================\n", .{err});
    };
    solver.printData();
    solver.printGrid();
}
