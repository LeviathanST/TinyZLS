const std = @import("std");
const lsp = @import("lsp");
const tiny_zls = @import("tiny_zls");

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

    const req: lsp.Message.Request = .{
        .jsonrpc = "2.0",
        .id = 1,
        .method = "initialize",
        .params = .{
            .initialize = .{},
        },
    };

    try transport.writeMessage(req);
    const res = try transport.readMessage();
    std.log.debug("[Client] received from server: \n{s}", .{res});

    const noti: lsp.Message.Notification = .{
        .jsonrpc = "2.0",
        .method = "initialized",
        .params = .{
            .initialized = .{},
        },
    };
    try transport.writeMessage(noti);

    const req1: lsp.Message.Request = .{
        .jsonrpc = "2.0",
        .id = 1,
        .method = "shutdown",
        .params = .{
            .shutdown = {},
        },
    };

    try transport.writeMessage(req1);
    const res1 = try transport.readMessage();
    std.log.debug("[Client] received from server: \n{s}", .{res1});

    const noti1: lsp.Message.Notification = .{
        .jsonrpc = "2.0",
        .method = "exit",
        .params = .{
            .exit = {},
        },
    };
    try transport.writeMessage(noti1);
    _ = try child.kill();
}
