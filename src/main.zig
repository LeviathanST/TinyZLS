const std = @import("std");
const rpc = @import("rpc.zig");
const types = @import("type.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const message = rpc.readMessage(stdin, allocator) catch |err| {
        std.log.warn("Error reading message: {}\n", .{err});
        return;
    };
    defer allocator.free(message);

    const parse = try std.json.parseFromSlice(types.RequestMessage, allocator, message, .{});
    defer parse.deinit();

    if (!parse.value.validate()) {
        return error.InvalidMessage;
    }
}

comptime {
    std.testing.refAllDecls(@This());
}
