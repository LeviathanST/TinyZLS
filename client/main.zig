const std = @import("std");
const tiny_zls = @import("tiny_zls");

const base_type = tiny_zls.base_type;

pub fn main() !void {
    std.log.info("Starting TinyZLS client", .{});

    var da = std.heap.DebugAllocator(.{}).init;
    const alloc = da.allocator();
    defer {
        const check = da.deinit();
        if (check == .leak) {
            std.log.warn("Leak memory is detect in client running!", .{});
        }
    }
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const req: base_type.RequestMessage = .{
        .id = 1,
        .method = "initialize",
    };

    var child: std.process.Child = .init(&.{args[1]}, alloc);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    try child.spawn();
    try child.waitForSpawn();

    var transport: tiny_zls.Transport = try .init(
        alloc,
        .{
            .writer = child.stdin.?.writer().any(),
            .reader = child.stdout.?.reader().any(),
        },
    );
    defer transport.deinit();
    try transport.sendMessage(req);
    const res = try transport.readMessage();

    std.log.debug("[Client] received from server: {s}", .{res});

    _ = try child.kill();
}
