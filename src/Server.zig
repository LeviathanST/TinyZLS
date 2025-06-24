//! Notification will be treated as request,
//! but return `avoid` when processing
const std = @import("std");

const lsp = @import("lsp");
const base_type = lsp.base_type;
const Transport = @import("Transport.zig");
const ReadError = Transport.ReadError;

const Server = @This();

const Message = lsp.Message;
const RequestParams = lsp.RequestParams;
const NotificationParams = lsp.NotificationParams;
const Result = lsp.Result;

transport: ?Transport = null,
status: Status = .uninitialized,
allocator: std.mem.Allocator,
_arena: *std.heap.ArenaAllocator,

pub const Status = enum {
    uninitialized,
    initializing,
    initialized,
    shutdown,
};

/// We not assign `transport` here for testing,
/// please use `.setTransport()`.
pub fn init(allocator: std.mem.Allocator) !Server {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    return .{
        .allocator = arena.allocator(),
        ._arena = arena,
    };
}
pub fn setTransport(self: *Server, transport: Transport) void {
    self.*.transport = transport;
}
pub fn deinit(self: *Server) void {
    const alloc = self._arena.child_allocator;
    self._arena.deinit();
    alloc.destroy(self._arena);
    if (self.transport) |transport| {
        @constCast(&transport).deinit();
    }
}

pub fn onInitialize(self: *Server, params: base_type.InitializeParams) !base_type.InitializeResult {
    // TODO:
    _ = params;
    errdefer self.*.status = .uninitialized;
    std.log.debug("The server is initializing.", .{});

    if (self.status == .initialized) {
        std.log.warn("The server has been initialized!", .{});
    }

    self.*.status = .initializing;
    const result: base_type.InitializeResult = .{
        .capabilities = .{ .hoverProvider = true },
        .serverInfo = .default(),
    };
    return result;
}
pub fn onInitialized(self: *Server, _: base_type.InitializedParams) !void {
    if (self.status != .initializing) {
        std.log.err("The server receives a initialized notification but not receives a initialize request before!", .{});
        return error.InvalidRequest;
    }

    if (self.status == .initialized) {
        std.log.err("The server is already initialized", .{});
        return error.InvalidHeader;
    }
    self.*.status = .initialized;
}

/// Main loop
pub fn loop(self: *Server) !void {
    while (true) {
        const message = self.transport.?.readMessage() catch |err| {
            std.log.err("Error reading message: {}\n", .{err});
            return err;
        };
        std.log.debug("[Server] received from client: \n{s}", .{message});
        if (message.len == 0) {
            std.log.err("Message is empty with content-length = 0!", .{});
            return ReadError.MessageEmpty;
        }
        try self.processMessage(message);
    }
}

/// Assert in this function ensure `method` existed.
pub fn handleRequest(
    self: *Server,
    comptime method: []const u8,
    params: RequestParams.typeFromMethod(method),
) !Result.typeFromMethod(method) {
    std.debug.assert(@hasField(RequestParams, method));

    const res = switch (@field(RequestParams, method)) {
        .initialize => try self.onInitialize(params),
    };
    return res;
}

/// Handle request then send message.
pub fn processRequest(
    self: *Server,
    comptime method: []const u8,
    params: RequestParams.typeFromMethod(method),
    id: base_type.integer,
) !void {
    const res: Message.Response = blk: {
        const rs = self.handleRequest(method, params) catch |err| {
            break :blk .{
                .id = id,
                .@"error" = .{
                    .code = switch (err) {
                        error.InvalidRequest => @intFromEnum(base_type.LSPErrCode.ServerNotInitialized),
                        error.InvalidRequest => @intFromEnum(base_type.LSPErrCode.InvalidRequest),
                        error.InvalidRequest => @intFromEnum(base_type.LSPErrCode.MethodNotFound),
                        else => unreachable,
                    },
                    .message = @errorName(err),
                    .data = null,
                },
            };
        };
        break :blk .{
            .jsonrpc = "2.0",
            .id = id,
            .result = @unionInit(Result, method, rs),
            .@"error" = null,
        };
    };

    try self.transport.?.writeMessage(res);
}

pub fn processNotification(
    self: *Server,
    comptime method: []const u8,
    params: NotificationParams.typeFromMethod(method),
) !void {
    switch (@field(NotificationParams, method)) {
        .initialized => try self.onInitialized(params),
    }
}

pub fn processMessage(self: *Server, message: []const u8) !void {
    const msg = try std.json.parseFromSlice(Message, self.allocator, message, .{});
    defer msg.deinit();

    const value = msg.value;
    switch (value) {
        .notification => |noti| switch (noti.params.?) {
            inline else => |union_value, tag| try self.processNotification(@tagName(tag), union_value),
        },
        .request => |req| switch (req.params.?) {
            inline else => |union_value, tag| try self.processRequest(@tagName(tag), union_value, req.id),
        },
        .response => std.log.debug("Client send a response", .{}),
    }
}
