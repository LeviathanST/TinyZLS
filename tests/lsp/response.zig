const std = @import("std");
const lsp = @import("lsp");

const Message = lsp.Message;
const Result = lsp.Result;
const NotificationParams = lsp.NotificationParams;

const expect = std.testing.expect;
test "Stringify" {
    const alloc = std.testing.allocator;

    const res: Message.Response = .{
        .jsonrpc = "2.0",
        .id = 1,
        .result = .{
            .initialize = .{
                .capabilities = .{ .hoverProvider = true },
                .serverInfo = .{
                    .name = "tiny_zls",
                    .version = "0.0.0",
                },
            },
        },
    };

    const msg = try std.json.stringifyAlloc(alloc, res, .{ .whitespace = .indent_2 });
    const expected_msg =
        \\{
        \\  "jsonrpc": "2.0",
        \\  "id": 1,
        \\  "result": {
        \\    "capabilities": {
        \\      "hoverProvider": true
        \\    },
        \\    "serverInfo": {
        \\      "name": "tiny_zls",
        \\      "version": "0.0.0"
        \\    }
        \\  },
        \\  "error": null
        \\}
    ;
    try expect(std.mem.eql(u8, msg, expected_msg));
}
