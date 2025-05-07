const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "Tiny ZLS",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    const run_test_by_cmd = b.addSystemCommand(&.{ "sh", "-c", "zig test src/main.zig 2>&1 | cat" });
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_test_by_cmd.step);
}
