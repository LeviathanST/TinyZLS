const std = @import("std");
const rpc = @import("rpc.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const message = rpc.readMessage(stdin, allocator) catch |err| {
        std.log.warn("Error reading message: {}\n", .{err});
        return;
    };
    errdefer allocator.free(message);
}

comptime {
    std.testing.refAllDecls(@This());
}
