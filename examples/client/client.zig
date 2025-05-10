//! First at all, we need to install the lsp server (tiny_zls)
//! ```zig
//! zig build
//! ```
//! Then
//! ```zig
//! zig build run-example-client -- zig-out/bin/tiny_zls
//! ```
const std = @import("std");
const lsp = @import("lsp");
const TransportOverStdio = lsp.base_protocol.TransportOverStdio;

const types = lsp.types;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var child: std.process.Child = .init(&.{args[1]}, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    try child.spawn();
    try child.waitForSpawn();

    const request: types.Request = .{
        .id = 1,
        .method = "hehe",
        .params = null,
    };
    try std.testing.expect(request.validate());

    const transport: TransportOverStdio = .init(child.stdout.?.reader(), child.stdin.?.writer());
    try transport.writeMessage(request);

    const message = try transport.readMessage(allocator);
    std.log.debug("From client: received from server {s}", .{message});
    _ = try child.kill();
    return;
}
