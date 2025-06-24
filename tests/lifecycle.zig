const std = @import("std");
const tiny_zls = @import("tiny_zls");

const expect = std.testing.expect;

test "Basic" {
    const alloc = std.testing.allocator;
    var server = try tiny_zls.Server.init(alloc);
    defer server.deinit();

    _ = try server.handleRequest("initialize", .{});
    try expect(server.status == .initializing);

    try server.processNotification("initialized", .{});
    try expect(server.status == .initialized);

    _ = try server.handleRequest("shutdown", {});
    try expect(server.status == .shutdown);

    try server.processNotification("exit", {});
    try expect(server.status == .exit);
}
