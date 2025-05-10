const std = @import("std");
const lsp = @import("lsp.zig");

const types = lsp.types;
const Server = @import("Server.zig");

const base_protocol = lsp.base_protocol;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    const transport: base_protocol.TransportOverStdio = .init(stdin, stdout);
    const message = transport.readMessage(allocator) catch |err| {
        std.log.warn("Error reading message: {}\n", .{err});
        return;
    };
    defer allocator.free(message);
    std.log.debug("From server: received {s}", .{message});

    const parse = try std.json.parseFromSlice(types.Request, allocator, message, .{});
    defer parse.deinit();

    if (!parse.value.validate()) {
        return error.InvalidMessage;
    }

    try transport.writeMessage("received request from client!");
}

comptime {
    std.testing.refAllDecls(@This());
}
