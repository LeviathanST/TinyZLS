const std = @import("std");
const json = std.json;

const integer = isize;
const string = []const u8;
const any = json.Value;

/// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
pub const Request = struct {
    const Self = @This();

    jsonrpc: string = "2.0",
    id: integer,
    method: string,
    params: ?any, // Any

    pub fn validate(self: Self) bool {
        if (!std.mem.eql(u8, self.jsonrpc, "2.0")) {
            std.log.warn("JSON-RPC version is invalid!", .{});
            return false;
        }
        if (self.params == null) {
            return true;
        }
        return switch (self.params.?) {
            .object, .array => true,
            else => {
                std.log.warn("Invalid params type: Expected `struct` or `array`", .{});
                return false;
            },
        };
    }
};

pub fn Response(comptime T: type) type {
    return struct {
        const Self = @This();

        jsonrpc: string = "2.0",
        id: ?integer,
        result: ?T,
        @"error": ?ResponseError,

        pub const ResponseError = struct {
            code: integer,
            message: string,
            data: ?any,
        };

        pub fn init(reqId: ?integer, result: ?T, @"error": ?ResponseError) Self {
            return Self{
                .id = reqId,
                .result = result,
                .@"error" = @"error",
            };
        }

        pub fn validate(self: Self) bool {
            if (!std.mem.eql(u8, self.jsonrpc, "2.0")) {
                std.log.warn("JSON-RPC version is invalid!", .{});
                return false;
            }
            return switch (@typeInfo(T)) {
                .@"struct" => true,
                .array => |arrayInfo| {
                    switch (arrayInfo) {
                        .slice => true,
                        else => false,
                    }
                },
                .pointer => |pointerInfo| {
                    switch (pointerInfo) {
                        .slice => true,
                        else => false,
                    }
                },
                else => {
                    false;
                },
            };
        }
    };
}
pub const DocumentUri = string;
pub const InitializeParams = struct {
    processId: ?integer,
    rootPath: ?string,
    rootUri: ?DocumentUri,
    initializationOptions: ?any,
    capabilities: ClientCapabilities,
};
pub const ClientCapabilities = struct {};
pub const InitializeResult = struct {
    const Self = @This();
    capabilities: ServerCapabilities,

    pub fn init(capabilities: ServerCapabilities) Self {
        return Self{ .capabilities = capabilities };
    }
};
pub const ServerCapabilities = struct {
    hoverProvider: bool,
};
