/// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
const std = @import("std");
const json = std.json;

pub const integer = isize;
const any = json.Value;

pub fn ParamsType(comptime method: []const u8) type {
    if (!@hasField(RequestParams, method)) return void;
    return @FieldType(RequestParams, method);
}
pub const RequestParams = union(enum) {
    initialize: InitializeParams,
    other: OtherMethod,
};

const OtherMethod = struct {};

pub const LSPErrCode = enum(i32) {
    ServerNotInitialized = -32002,
    InvalidRequest = -32600,
};

pub const RequestJSONMessage = struct {
    const Self = @This();
    jsonrpc: []const u8 = "2.0",
    id: integer,
    method: []const u8,
    params: ?any = null,
};

pub const ResponseJSONMessage = struct {
    const Self = @This();
    id: integer,
    result: ?any = null,
    @"error": ?ResponseError = null,

    const ResponseError = struct {
        code: integer,
        message: []const u8,
        data: ?any = null,
    };
};

pub const InitializeParams = struct {};
pub const InitializeResult = struct {
    capabilities: ServerCapabilities,
    serverInfo: ServerInfo,

    pub const ServerCapabilities = struct {
        hoverProvider: bool,
    };
    pub const ServerInfo = struct {
        name: []const u8,
        version: []const u8,

        pub fn default() ServerInfo {
            return .{ .name = "tiny_zls", .version = "0.0.0" };
        }
    };
};

pub fn RequestMessage(comptime Params: type) type {
    return struct {
        const Self = @This();
        jsonrpc: []const u8 = "2.0",
        id: integer,
        params: Params,

        pub fn parseFromSlice(alloc: std.mem.Allocator, s: []const u8) !Self {
            const parsed = try std.json.parseFromSlice(RequestJSONMessage, alloc, s, .{});
            defer parsed.deinit();
            const value: RequestJSONMessage = parsed.value;

            var self = try alloc.create(Self);
            errdefer alloc.destroy(self);
            self.id = value.id;

            const param_fields = std.meta.fields(Params);
            inline for (param_fields) |f| {
                if (std.mem.eql(u8, f.name, value.method)) {
                    self.params = @unionInit(
                        Params,
                        f.name,
                        (try std.json.parseFromValue(
                            f.type,
                            alloc,
                            value.params.?,
                            .{},
                        )).value,
                    );
                }
            }
            self.*.id = value.id;
            return self.*;
        }
    };
}
