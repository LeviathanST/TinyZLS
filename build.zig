const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "tiny_zls",
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

    // -------------------Example---------------------
    const lsp_module = b.addModule("lsp", .{
        .root_source_file = b.path("src/lsp.zig"),
        .target = target,
        .optimize = optimize,
    });

    const example_client_exe = b.addExecutable(.{
        .name = "transport_client_example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/client/client.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lsp", .module = lsp_module },
            },
        }),
    });
    b.installArtifact(example_client_exe);
    const run_example_client = b.addRunArtifact(example_client_exe);
    const run_example_client_step = b.step("run-example-client", "Run the example client");
    run_example_client.addArtifactArg(exe);
    run_example_client_step.dependOn(&run_example_client.step);
}
