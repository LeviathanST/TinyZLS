const std = @import("std");
const lsp = @import("lsp");

const Message = lsp.Message;
const NotificationParams = lsp.NotificationParams;

const expect = std.testing.expect;

test "Parse message" {
    const alloc = std.testing.allocator;
    const msg =
        \\ {
        \\   "jsonrpc": "2.0",
        \\   "method": "initialized",
        \\   "params":  {}
        \\ }
    ;

    const parsed_msg = try std.json.parseFromSlice(Message, alloc, msg, .{});
    defer parsed_msg.deinit();
    const value: Message = parsed_msg.value;
    const noti = value.notification;

    try expect(std.mem.eql(u8, noti.jsonrpc, "2.0"));
    try expect(std.mem.eql(u8, noti.method, "initialized"));
    try expect(@TypeOf(noti.params.?) == NotificationParams);
}
test "Stringify" {
    const alloc = std.testing.allocator;

    const noti: Message.Notification = .{
        .jsonrpc = "2.0",
        .method = "initialized",
        .params = .{
            .initialized = .{},
        },
    };

    const msg = try std.json.stringifyAlloc(alloc, noti, .{});
    const expected_msg =
        \\{"jsonrpc":"2.0","method":"initialized","params":{}}
    ;
    try expect(std.mem.eql(u8, msg, expected_msg));
}
