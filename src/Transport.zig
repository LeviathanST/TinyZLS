//! Transport via stdio
const std = @import("std");
const base_type = @import("base_type.zig");

const Transport = @This();

arena: *std.heap.ArenaAllocator,
opts: TransportOpts,
_allocator: std.mem.Allocator,

pub const TransportOpts = struct {
    reader: std.io.AnyReader,
    writer: std.io.AnyWriter,
};

pub const ReadError = error{
    MessageEmpty,
    HeaderTooLong,
    PrematureEndOfStream, // unxpectedly ends the stream
    InvalidHeader,
};

pub fn init(allocator: std.mem.Allocator, opts: TransportOpts) !Transport {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);

    arena.* = std.heap.ArenaAllocator.init(allocator);

    return .{
        .arena = arena,
        .opts = opts,
        ._allocator = allocator,
    };
}
pub fn deinit(self: *Transport) void {
    self.arena.deinit();
    self._allocator.destroy(self.arena);
}

/// This function use arena in the owner,
/// don't need to call `free()` after finish
pub fn readMessage(self: Transport) ![]u8 {
    const reader = self.opts.reader;
    var buffer: [4 * 1024]u8 = undefined;
    var json_len: ?usize = null;
    // Read header
    while (true) {
        const line = reader.readUntilDelimiterOrEof(buffer[0..], '\r') catch |err| switch (err) {
            error.StreamTooLong => return ReadError.HeaderTooLong,
            else => return err,
        } orelse return ReadError.PrematureEndOfStream;
        try reader.skipUntilDelimiterOrEof('\n');
        if (line.len == 0) { // End header
            break;
        }

        const pos_seperator = std.mem.indexOf(u8, line, ": ") orelse {
            std.log.err("Not found `Content-Length: <length>`", .{});
            return ReadError.InvalidHeader;
        };
        if (std.mem.eql(u8, line[0..pos_seperator], "Content-Length")) {
            json_len = try std.fmt.parseInt(usize, line[pos_seperator + 2 ..], 10);
        }
    }
    if (json_len == null) {
        std.log.err("Not found `Content-Length: <length>`", .{});
        return ReadError.InvalidHeader;
    }
    const json_str = try self.arena.allocator().alloc(u8, json_len.?);
    errdefer self.arena.allocator().free(json_str);
    // Read all the rest
    const bytes_read = try reader.readAll(json_str);
    if (bytes_read != json_len) {
        return ReadError.PrematureEndOfStream;
    }
    return json_str;
}

pub fn sendMessage(self: Transport, res_or_req: anytype) !void {
    const writer = self.opts.writer;
    const alloc = self.arena.allocator();
    const json = try std.json.stringifyAlloc(
        alloc,
        res_or_req,
        .{ .emit_null_optional_fields = true },
    );
    defer alloc.free(json);

    const content_length = try std.fmt.allocPrint(
        alloc,
        "Content-Length: {d}\r\n\r\n",
        .{json.len},
    );
    defer alloc.free(content_length);

    try writer.writeAll(content_length);
    try writer.writeAll(json);
}
