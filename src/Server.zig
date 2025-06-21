//! Notification will be treated as request,
//! but return `avoid` when processing
const std = @import("std");

const lsp = @import("lsp");
const base_type = lsp.base_type;
const Transport = @import("Transport.zig");
const ReadError = Transport.ReadError;

const Server = @This();

const RequestMessage = lsp.RequestMessage;
const ResponseMessage = lsp.ResponseMessage;
const ParamTypes = lsp.ParamTypes;
const ResultTypes = lsp.ResultTypes;
const RequestParams = lsp.RequestParams;
const Result = lsp.Result;

transport: ?Transport = null,
status: Status = .uninitialized,
allocator: std.mem.Allocator,
_arena: *std.heap.ArenaAllocator,

pub const Status = enum {
    uninitialized,
    initializing,
    initialized,
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

pub fn onInitialized(self: *Server) void {
    if (self.status == .initialized) {
        std.log.err("Server has been initialized!", .{});
        return error.InvalidRequest;
    }
    if (self.status == .uninitialized) {
        std.log.err("Please request to initialize server before notification!", .{});
        return error.InvalidRequest;
    }
    self.*.status = .initialized;
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
pub fn sendMessage(
    self: *Server,
    comptime method: []const u8,
    params: ParamTypes(method),
) !ResultTypes(method) {
    std.debug.assert(@hasField(RequestParams, method));

    const res = switch (@field(RequestParams, method)) {
        .initialize => try self.onInitialize(params),
        .initialized => try self.onInitialized(),
        .other => .{},
    };
    return res;
}

pub fn sendMessageToClient(
    self: *Server,
    comptime method: []const u8,
    params: ParamTypes(method),
    id: base_type.integer,
) !void {
    const res: ResponseMessage = blk: {
        const rs = self.sendMessage(method, params) catch |err| {
            break :blk .{
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
        };
        break :blk .withRawResult(method, id, rs);
    };

    try self.transport.?.writeMessage(res);
}

pub fn processRequest(self: *Server, message: []const u8) !void {
    const rm = try RequestMessage.parseFromSlice(self.allocator, message);

    switch (rm.params) {
        .other => std.log.err("Catch unknown req", .{}),
        inline else => |params, method| try self.sendMessageToClient(@tagName(method), params, rm.id),
    }
}
