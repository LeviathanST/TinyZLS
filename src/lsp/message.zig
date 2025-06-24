//! A message handler consist of request, response
//! # Deifinitions
//! * Message:
//!   - Request
//!   - Response
//!   - Notification
//!
//! * Response result:
//!   - Get `type` from method name.
//!   - Json string from tagged union.
//! * Request parameters:
//!   - Get `type` from method name.
//!   - Parse from json string to tagged union.
const std = @import("std");
const base_type = @import("base_type.zig");

const innerParse = std.json.innerParse;
const innerParseFromValue = std.json.innerParseFromValue;
const Token = std.json.Token;

const integer = base_type.integer;
const any = base_type.any;

/// A tagged union contains all notification parameters
/// definition in LSP specifiication
pub const NotificationParams = union(enum) {
    initialized: base_type.InitializedParams,

    pub fn typeFromMethod(comptime method: []const u8) type {
        if (!@hasField(NotificationParams, method)) return void;
        return @FieldType(NotificationParams, method);
    }

    pub fn jsonStringify(self: NotificationParams, stream: anytype) !void {
        const active_tag = std.meta.activeTag(self);
        try stream.write(@field(self, @tagName(active_tag)));
    }

    pub fn parse(
        alloc: std.mem.Allocator,
        source: any,
        runtime_method: []const u8,
        opts: std.json.ParseOptions,
    ) !?NotificationParams {
        inline for (std.meta.fields(NotificationParams)) |f| {
            if (std.mem.eql(u8, f.name, runtime_method)) {
                return @unionInit(
                    NotificationParams,
                    f.name,
                    try innerParseFromValue(
                        NotificationParams.typeFromMethod(f.name),
                        alloc,
                        source,
                        opts,
                    ),
                );
            }
        }
        return null;
    }
};

/// A tagged union contains all request parameters
/// definition in LSP specifiication
pub const RequestParams = union(enum) {
    initialize: base_type.InitializeParams,

    pub fn typeFromMethod(comptime method: []const u8) type {
        if (!@hasField(RequestParams, method)) return void;
        return @FieldType(RequestParams, method);
    }

    pub fn jsonStringify(self: RequestParams, stream: anytype) !void {
        const active_tag = std.meta.activeTag(self);
        inline for (std.meta.fields(RequestParams)) |f| {
            if (std.mem.eql(u8, f.name, @tagName(active_tag))) {
                if (f.type == void) {
                    try stream.write(null);
                    return;
                }
                try stream.write(@field(self, f.name));
            }
        }
    }

    pub fn parse(
        alloc: std.mem.Allocator,
        source: any,
        runtime_method: []const u8,
        opts: std.json.ParseOptions,
    ) !?RequestParams {
        inline for (std.meta.fields(RequestParams)) |f| {
            if (std.mem.eql(u8, f.name, runtime_method)) {
                if (f.type == void) {
                    return @unionInit(RequestParams, f.name, {});
                }
                return @unionInit(
                    RequestParams,
                    f.name,
                    try innerParseFromValue(
                        RequestParams.typeFromMethod(f.name),
                        alloc,
                        source,
                        opts,
                    ),
                );
            }
        }
        return null;
    }
};

/// A tagged union contains all response result
/// definitions in LSP specifiication
pub const Result = union(enum) {
    initialize: base_type.InitializeResult,

    pub fn jsonStringify(self: Result, stream: anytype) !void {
        const active_tag = std.meta.activeTag(self);
        inline for (std.meta.fields(Result)) |f| {
            if (std.mem.eql(u8, f.name, @tagName(active_tag))) {
                if (f.type == void) {
                    try stream.write(null);
                    return;
                }
                try stream.write(@field(self, f.name));
            }
        }
    }
    pub fn typeFromMethod(comptime method: []const u8) type {
        if (!@hasField(Result, method)) return void;
        return @FieldType(Result, method);
    }
};

pub const MessageFields = struct {
    jsonrpc: []const u8 = "",
    id: ?integer = null,
    method: ?[]const u8 = null,
    // NOTE: use std.json.Value here for json dynamic parse,
    //       then use custom jsonParseFromValue() in NotificationParams
    //       or RequestParams.
    params: ?any = null,
    result: ?Result = null,
    @"error": ?Message.Response.ErrorResponse = null,

    pub fn jsonParseField(
        self: *MessageFields,
        alloc: std.mem.Allocator,
        source: anytype,
        opts: std.json.ParseOptions,
        comptime field_name: []const u8,
    ) !void {
        const E = std.meta.FieldEnum(MessageFields);
        const key = @field(E, field_name);
        if (key == .result) return; // ignore to parse response
        const value = switch (key) {
            .params => try innerParse(any, alloc, source, opts),
            inline else => try innerParse(@FieldType(MessageFields, field_name), alloc, source, opts),
        };
        @field(self, field_name) = value;
    }

    pub fn toMessage(
        self: MessageFields,
        alloc: std.mem.Allocator,
        opts: std.json.ParseOptions,
    ) !Message {
        if (self.method) |method| {
            if (self.id) |id| {
                return Message{
                    .request = .{
                        .jsonrpc = self.jsonrpc,
                        .id = id,
                        .method = method,
                        .params = try RequestParams.parse(
                            alloc,
                            self.params.?,
                            self.method.?,
                            opts,
                        ),
                    },
                };
            } else {
                return Message{
                    .notification = .{
                        .jsonrpc = self.jsonrpc,
                        .method = method,
                        .params = try NotificationParams.parse(
                            alloc,
                            self.params.?,
                            self.method.?,
                            opts,
                        ),
                    },
                };
            }
        } else {
            return Message{
                .response = .{
                    .jsonrpc = self.jsonrpc,
                    .id = self.id.?,
                    .result = self.result.?,
                    .@"error" = self.@"error".?,
                },
            };
        }
    }
};

pub const Message = union(enum) {
    notification: Notification,
    response: Response,
    request: Request,

    pub const Response = struct {
        jsonrpc: []const u8,
        id: integer,
        result: ?Result = null,
        @"error": ?ErrorResponse = null,

        pub const ErrorResponse = struct {
            code: integer,
            message: []const u8,
            data: ?any = null,
        };
    };
    pub const Request = struct {
        jsonrpc: []const u8,
        id: integer,
        method: []const u8,
        params: ?RequestParams = null,
    };
    pub const Notification = struct {
        jsonrpc: []const u8,
        method: []const u8,
        params: ?NotificationParams = null,
    };

    pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, opts: std.json.ParseOptions) !Message {
        if (try source.next() != .object_begin) return error.UnexpectedToken;
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();

        var key_map = std.StringHashMap([]const u8).init(arena.allocator());
        defer key_map.deinit();

        var mf: MessageFields = .{};
        const Fields = std.meta.FieldEnum(MessageFields);

        while (true) {
            const token: ?Token = try source.nextAllocMax(alloc, .alloc_if_needed, opts.max_value_len.?);
            const field_name = blk: {
                const name = switch (token.?) {
                    inline .string, .allocated_string => |slice| slice,
                    .object_end => break,
                    else => return error.UnexpectedToken,
                };
                switch (token.?) {
                    .allocated_string => |slice| alloc.free(slice),
                    else => {},
                }
                break :blk std.meta.stringToEnum(Fields, name) orelse continue; // skip unknown fields
            };

            switch (field_name) {
                inline else => |comptime_field| try mf.jsonParseField(
                    alloc,
                    source,
                    opts,
                    @tagName(comptime_field),
                ),
            }
        }
        return try mf.toMessage(alloc, opts);
    }
};
