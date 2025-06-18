const std = @import("std");
const Server = @import("Server.zig");
const Transport = @import("Transport.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    std.log.info("Starting TinyZLS", .{});

    const transport = try Transport.init(
        allocator,
        .{
            .reader = std.io.getStdIn().reader().any(),
            .writer = std.io.getStdOut().writer().any(),
        },
    );
    var server: Server = .{ .transport = transport };
    defer server.deinit();

    try server.loop();
}

comptime {
    std.testing.refAllDecls(@This());
}
