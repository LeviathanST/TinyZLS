const std = @import("std");

const LspError = error{
    HeaderTooLong,
    PrematureEndOfStream, // unxpectedly ends the stream
    InvalidHeader,
};

/// return a message which is managed by `allocator`,
/// need to use `free()` after finish
pub fn readMessage(reader: anytype, allocator: std.mem.Allocator) ![]u8 {
    var buffer: [4 * 1024]u8 = undefined;
    var json_len: ?usize = null;
    // Read header
    while (true) {
        const line = reader.readUntilDelimiterOrEof(buffer[0..], '\r') catch |err| switch (err) {
            error.StreamTooLong => return LspError.HeaderTooLong,
            else => return err,
        } orelse return LspError.PrematureEndOfStream;
        try reader.skipUntilDelimiterOrEof('\n');
        if (line.len == 0) { // End header
            break;
        }

        const pos_seperator = std.mem.indexOf(u8, line, ": ").?;
        if (std.mem.eql(u8, line[0..pos_seperator], "Content-Length")) {
            json_len = try std.fmt.parseInt(usize, line[pos_seperator + 2 ..], 10);
        }
    }
    if (json_len == null) {
        return LspError.InvalidHeader;
    }
    const json_str = try allocator.alloc(u8, json_len.?);
    errdefer allocator.free(json_str);
    // Read all the rest
    const bytes_read = try reader.readAll(json_str);
    if (bytes_read != json_len) {
        return LspError.PrematureEndOfStream;
    }
    return json_str;
}

test "Read success" {
    const expect = std.testing.expect;
    const buffer = "Content-Length: 3\r\n\r\n{e}";
    var fbs = std.io.fixedBufferStream(buffer);

    const allocator = std.testing.allocator;
    const message = try readMessage(fbs.reader(), allocator);
    defer allocator.free(message);
    try expect(std.mem.eql(u8, message[0..], "{e}"));
}
