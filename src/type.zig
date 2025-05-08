const std = @import("std");
const json = std.json;

const integer = isize;
const string = []const u8;
const any = json.Value;

/// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
pub const RequestMessage = struct {
    const Self = @This();
    jsonrpc: string = "2.0",
    id: integer,
    method: string,
    params: any, // Any

    pub fn validate(self: Self) bool {
        if (!std.mem.eql(u8, self.jsonrpc, "2.0")) {
            std.log.warn("JSON-RPC version is invalid!", .{});
            return false;
        }
        return switch (self.params) {
            .object, .array => true,
            else => {
                std.log.warn("Invalid params type: Expected `struct` or `array`", .{});
                return false;
            },
        };
    }
};
