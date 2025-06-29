const std = @import("std");
const Server = @import("Server.zig");
const Transport = @import("Transport.zig");

const log_level: std.log.Level = .debug;
pub const std_options: std.Options = .{
    .log_level = log_level,
    .logFn = logFn,
};

fn logFn(
    comptime level: std.log.Level,
    comptime scoped: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(level) > @intFromEnum(std_options.log_level)) return;
    _ = scoped;
    const color: []const u8 = comptime switch (level) {
        .err => "\x1b[31m",
        .info => "\x1b[32m",
        .debug => "\x1b[33m",
        .warn => "\x1b[35m",
    };

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(
        color ++ "[TinyZLS " ++ @tagName(level) ++ "] " ++ format ++ "\n\x1b[0m",
        args,
    ) catch return;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.log.info("Starting TinyZLS", .{});
    std.log.info("Log level: {s}", .{@tagName(log_level)});

    const transport = try Transport.init(
        allocator,
        .{
            .reader = std.io.getStdIn().reader().any(),
            .writer = std.io.getStdOut().writer().any(),
        },
    );
    var server: Server = try .init(allocator);
    defer server.deinit();
    server.setTransport(transport);

    try server.loop();
}

comptime {
    std.testing.refAllDecls(@This());
}
