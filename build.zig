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
        exe.root_module.addImport("lsp", lsp_module);
        b.installArtifact(exe);
    }

    const tiny_zls_module = b.addModule("tiny_zls", .{
        .root_source_file = b.path("src/tiny_zls.zig"),
        .target = target,
        .optimize = optimize,
    });
    tiny_zls_module.addImport("lsp", lsp_module);

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

        const ia = b.addInstallArtifact(client_exe, .{});
        const run_client_exe = b.addRunArtifact(ia.artifact);
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
        tests.root_module.addImport("lsp", lsp_module);

        const run_test = b.addRunArtifact(tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_test.step);
    }
}
