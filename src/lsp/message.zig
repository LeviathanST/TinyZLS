//! A message handler consist of request, response
//! # Deifinitions
//! * Message:
//!   - Request
//!   - Response
//!   - TODO: Notification
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
const Token = std.json.Token;

const integer = base_type.integer;
const any = base_type.any;

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
        try stream.write(@field(self, @tagName(active_tag)));
    }

    pub fn parse(
        alloc: std.mem.Allocator,
        source: anytype,
        runtime_method: []const u8,
        opts: std.json.ParseOptions,
    ) !?RequestParams {
        inline for (std.meta.fields(RequestParams)) |f| {
            if (std.mem.eql(u8, f.name, runtime_method)) {
                return @unionInit(
                    RequestParams,
                    f.name,
                    try innerParse(
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
            if (std.mem.eql(u8, @tagName(active_tag), f.name)) {
                try stream.write(@field(self, f.name));
            }
        }
    }

    pub fn parse(
        alloc: std.mem.Allocator,
        source: anytype,
        runtime_method: []const u8,
        opts: std.json.ParseOptions,
    ) !?Result {
        inline for (std.meta.fields(Result)) |f| {
            if (std.mem.eql(u8, f.name, runtime_method)) {
                return @unionInit(
                    Result,
                    f.name,
                    try innerParse(
                        Result.typeFromMethod(f.name),
                        alloc,
                        source,
                        opts,
                    ),
                );
            }
        }
        return null;
    }

    pub fn typeFromMethod(comptime method: []const u8) type {
        if (!@hasField(Result, method)) return void;
        return @FieldType(Result, method);
    }
};

pub const MessageFields = struct {
    jsonrpc: []const u8,
    id: ?integer = null,
    method: ?[]const u8 = null,
    params: ?RequestParams = null,
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
        const value = switch (key) {
            .params => try RequestParams.parse(alloc, source, self.method.?, opts),
            .result => try Result.parse(alloc, source, self.method.?, opts),
            else => try innerParse(@FieldType(MessageFields, field_name), alloc, source, opts),
        };
        @field(self, field_name) = value;
    }

    pub fn toMessage(self: MessageFields) Message {
        if (self.method) |method| {
            return Message{
                .request = .{
                    .jsonrpc = self.jsonrpc,
                    .id = self.id.?,
                    .method = method,
                    .params = self.params.?,
                },
            };
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

    pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, opts: std.json.ParseOptions) !Message {
        if (try source.next() != .object_begin) return error.UnexpectedToken;
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();

        var key_map = std.StringHashMap([]const u8).init(arena.allocator());
        defer key_map.deinit();

        // SAFETY: use @field to assign value after parsing needed fields
        var mf: MessageFields = undefined;
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
        return mf.toMessage();
    }
};
pub const ResponseMessage = struct {
    const Self = @This();

    jsonrpc: []const u8 = "2.0",
    id: integer,
    result: ?Result = null,
    @"error": ?ResponseError = null,

    pub const ResponseError = struct {
        code: integer,
        message: []const u8,
        data: ?any = null,
    };

    /// Generate response json with tagged union result
    pub fn withRawResult(comptime method: []const u8, id: integer, result: anytype) ResponseMessage {
        const u = @unionInit(Result, method, result);
        return .{
            .id = id,
            .result = u,
        };
    }
};
