//! https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
const std = @import("std");
const json = std.json;

pub const integer = isize;
pub const any = json.Value;

pub const LSPErrCode = enum(i32) {
    ServerNotInitialized = -32002,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
};

pub const InitializedParams = struct {};
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
