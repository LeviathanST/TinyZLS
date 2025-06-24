const std = @import("std");
const lsp = @import("lsp");

const Message = lsp.Message;
const RequestParams = lsp.RequestParams;

const expect = std.testing.expect;

test "Parse message" {
    const alloc = std.testing.allocator;
    const msg =
        \\ {
        \\   "jsonrpc": "2.0",
        \\   "id": 1,
        \\   "method": "initialize",
        \\   "params":  {}
        \\ }
    ;

    const parsed_msg = try std.json.parseFromSlice(Message, alloc, msg, .{});
    defer parsed_msg.deinit();
    const value: Message = parsed_msg.value;
    const req = value.request;

    try expect(std.mem.eql(u8, req.jsonrpc, "2.0"));
    try expect(req.id == 1);
    try expect(std.mem.eql(u8, req.method, "initialize"));
    try expect(@TypeOf(req.params.?) == RequestParams);
}
test "Stringify" {
    const alloc = std.testing.allocator;

    const req: Message.Request = .{
        .jsonrpc = "2.0",
        .id = 1,
        .method = "initialize",
        .params = .{
            .initialize = .{},
        },
    };

    const msg = try std.json.stringifyAlloc(alloc, req, .{});
    const expected_msg =
        \\{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
    ;
    try expect(std.mem.eql(u8, msg, expected_msg));
}
