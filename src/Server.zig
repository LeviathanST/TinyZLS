const std = @import("std");

const base_type = @import("lsp.zig").base_type;
const Transport = @import("Transport.zig");
const ReadError = Transport.ReadError;

const Server = @This();
const RequestMessage = base_type.RequestMessage(base_type.RequestParams);

transport: Transport,
status: Status = .uninitialized,
allocator: std.mem.Allocator,
_arena: *std.heap.ArenaAllocator,

pub const Status = enum {
    uninitialized,
    initializing,
    initialized,
    shutdown,
};

pub fn init(transport: Transport, allocator: std.mem.Allocator) !Server {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    return .{
        .allocator = arena.allocator(),
        .transport = transport,
        ._arena = arena,
    };
}
pub fn deinit(self: *Server) void {
    const alloc = self._arena.child_allocator;
    self._arena.deinit();
    alloc.destroy(self._arena);
    self.transport.deinit();
}

pub fn onInitialize(self: *Server, params: base_type.InitializeParams) !base_type.InitializeResult {
    // TODO:
    _ = params;
    errdefer self.*.status = .uninitialized;

    if (self.status == .initialized) {
        std.log.err("The server has been initialized!", .{});
        return error.InvalidRequest;
    }
    if (self.status == .initializing) {
        std.log.err("The server is initializing!", .{});
        return error.InvalidRequest;
    }
    self.*.status = .initializing;
    const result: base_type.InitializeResult = .{
        .capabilities = .{ .hoverProvider = true },
        .serverInfo = .default(),
    };
    return result;
}

/// Main loop
pub fn loop(self: *Server) !void {
    while (self.status != .shutdown) {
        const message = self.transport.readMessage() catch |err| {
            std.log.err("Error reading message: {}\n", .{err});
            return err;
        };
        std.log.debug("[Server] received from client: \n{s}", .{message});
        if (message.len == 0) {
            std.log.err("Message is empty with content-length = 0!", .{});
            return ReadError.MessageEmpty;
        }
        try self.processRequest(message);
    }
}

pub fn parseRequest(self: Server, message: []const u8) !std.json.Parsed(base_type.RequestJSONMessage) {
    const value = try std.json.parseFromSlice(
        base_type.RequestJSONMessage,
        self.allocator,
        message,
        .{},
    );
    return value;
}

/// Assert in this function ensure `method` existed.
pub fn sendMessage(self: *Server, comptime method: []const u8, params: base_type.ParamsType(method)) !void {
    std.debug.assert(@hasField(base_type.RequestParams, method));

    const res = switch (@field(base_type.RequestParams, method)) {
        .initialize => try self.onInitialize(params),
        .other => .{},
    };
    try self.transport.writeMessage(res);
}
pub fn sendMessageWithError(self: *Server, comptime method: []const u8, params: base_type.ParamsType(method), id: base_type.integer) !void {
    self.sendMessage(method, params) catch |err| {
        const res_err: base_type.ResponseJSONMessage = .{
            .id = id,
            .@"error" = .{
                .code = switch (err) {
                    error.InvalidRequest => @intFromEnum(base_type.LSPErrCode.InvalidRequest),
                    else => unreachable,
                },
                .message = @errorName(err),
                .data = null,
            },
        };
        try self.transport.writeMessage(res_err);
        return;
    };
}

pub fn processRequest(self: *Server, message: []const u8) !void {
    const rm = try RequestMessage.parseFromSlice(self.allocator, message);

    switch (rm.params) {
        .other => std.log.err("Catch unknown req", .{}),
        inline else => |params, method| try self.sendMessageWithError(@tagName(method), params, rm.id),
    }
}
