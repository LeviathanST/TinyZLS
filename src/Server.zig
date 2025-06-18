const std = @import("std");

const base_type = @import("base_type.zig");
const Transport = @import("Transport.zig");
const ReadError = Transport.ReadError;

const Server = @This();

transport: Transport,

pub fn onInitialize(self: Server) !void {
    const result: base_type.InitializeResult = .{
        .capabilities = .{ .hoverProvider = true },
        .serverInfo = .default(),
    };
    try self.transport.sendMessage(result);
}

pub fn loop(self: Server) !void {
    const message = self.transport.readMessage() catch |err| {
        std.log.err("Error reading message: {}\n", .{err});
        return err;
    };
    std.log.debug("[Server] received from client: {s}", .{message});
    if (message.len == 0) {
        std.log.err("Message is empty with content-length = 0!", .{});
        return ReadError.MessageEmpty;
    }
    try self.processRequest(message);
    self.transport.arena.deinit(); // Reset memory after reading once
}

pub fn deinit(self: *Server) void {
    self.transport.deinit();
}

pub fn parseRequest(self: Server, message: []const u8) !base_type.RequestMessage {
    const value = try std.json.parseFromSliceLeaky(
        base_type.RequestMessage,
        self.transport.arena.allocator(),
        message,
        .{},
    );
    return value;
}

pub fn processRequest(self: Server, message: []const u8) !void {
    const req = try self.parseRequest(message);
    if (!std.mem.eql(u8, req.method, "initialize")) return error.InvalidRequest;
    try self.onInitialize();
}
