const std = @import("std");
const types = @import("type.zig");
const Server = @import("../Server.zig");

const LspError = error{
    HeaderTooLong,
    PrematureEndOfStream, // unxpectedly ends the stream
    InvalidHeader,
};

pub const TransportOverStdio = struct {
    const Self = @This();
    in: std.fs.File.Reader,
    out: std.fs.File.Writer,

    pub fn init(in: std.fs.File.Reader, out: std.fs.File.Writer) Self {
        return Self{ .in = in, .out = out };
    }

    /// return a message managed by `allocator`,
    /// need to use `free()` after finish
    pub fn readMessage(self: Self, allocator: std.mem.Allocator) ![]u8 {
        const reader = self.in;
        const json_len: ?usize = try self.readMessageHeader();
        if (json_len == null) {
            return LspError.InvalidHeader;
        }
        const json_str = try allocator.alloc(u8, json_len.?); // truncate occur here if message is longer json_len
        errdefer allocator.free(json_str);
        // Read all the rest
        const bytes_read = try reader.readAll(json_str);
        if (bytes_read != json_len) {
            return LspError.PrematureEndOfStream;
        }
        return json_str;
    }

    /// return amount of bytes in body content
    fn readMessageHeader(self: Self) !?usize {
        const reader = self.in;
        var buffer: [4 * 1024]u8 = undefined;
        var len: ?usize = null;
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
                len = try std.fmt.parseInt(usize, line[pos_seperator + 2 ..], 10);
            }
        }
        return len;
    }

    pub fn writeMessage(self: Self, res_or_req: anytype) !void {
        const writer = self.out;
        var json_buf: [1024 * 128]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&json_buf);
        try std.json.stringify(res_or_req, .{}, fbs.writer());
        const message = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "Content-Length: {d}\r\n\r\n{s}",
            .{ fbs.getWritten().len, fbs.getWritten() },
        );
        defer std.heap.page_allocator.free(message);
        try writer.writeAll(message);
    }
};
