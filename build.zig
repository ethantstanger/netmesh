const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{ .name = "netmesh", .root_module = main_mod });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the executable");
    const run_exe = b.addRunArtifact(exe);
    run_step.dependOn(&run_exe.step);
}
