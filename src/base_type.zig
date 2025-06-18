const std = @import("std");
const json = std.json;

const integer = isize;
const any = json.Value;

/// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
pub const RequestMessage = struct {
    const Self = @This();
    jsonrpc: []const u8 = "2.0",
    id: integer,
    method: []const u8,
    params: ?any = null,
};

pub const ResponseMessage = struct {
    const Self = @This();
    id: integer,
    result: ?any,
    @"error": ?ResponseError,

    const ResponseError = struct {
        code: integer,
        message: []const u8,
        data: ?any,
    };
};

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
