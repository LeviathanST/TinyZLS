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
    const lsp_module = b.addModule("lsp", .{
        .root_source_file = b.path("src/lsp/lsp.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        b.installArtifact(exe);
        const run_exe = b.addRunArtifact(exe);
        const run_step = b.step("run", "Run the application");
        run_step.dependOn(&run_exe.step);

        const run_test_by_cmd = b.addSystemCommand(&.{ "sh", "-c", "zig test src/main.zig 2>&1 | cat" });
        const test_step = b.step("test", "Run unit tests");
        exe.root_module.addImport("lsp", lsp_module);
        test_step.dependOn(&run_test_by_cmd.step);
    }

    const tiny_zls_module = b.addModule("tiny_zls", .{
        .root_source_file = b.path("src/tiny_zls.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        // Sample client
        const client_exe = b.addExecutable(.{
            .name = "tiny_zls_client",
            .root_source_file = b.path("client/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        client_exe.root_module.addImport("tiny_zls", tiny_zls_module);
        client_exe.root_module.addImport("lsp", lsp_module);

        b.installArtifact(client_exe);
        const run_client_exe = b.addRunArtifact(client_exe);
        const run_client_step = b.step("run-client", "Run the client application");
        run_client_exe.addArtifactArg(exe);
        run_client_step.dependOn(&run_client_exe.step);
    }

    {
        const tests = b.addTest(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = target,
            .optimize = optimize,
            .test_runner = .{
                .path = b.path("tests/test_runner.zig"),
                .mode = .simple,
            },
        });
        tests.root_module.addImport("tiny_zls", tiny_zls_module);

        const run_test = b.addRunArtifact(tests);
        const test_step = b.step("tests", "Run unit tests");
        test_step.dependOn(&run_test.step);
    }
}
