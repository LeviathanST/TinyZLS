const std = @import("std");
const base_type = @import("base_type.zig");

const integer = base_type.integer;
const any = base_type.any;

pub fn ParamTypes(comptime method: []const u8) type {
    if (!@hasField(RequestParams, method)) return void;
    return @FieldType(RequestParams, method);
}

pub fn ResultTypes(comptime method: []const u8) type {
    if (!@hasField(Result, method)) return void;
    return @FieldType(Result, method);
}

pub const RequestParams = union(enum) {
    initialize: base_type.InitializeParams,
    other: OtherMethod,
};

pub const Result = union(enum) {
    initialize: base_type.InitializeResult,
    other,

    pub fn jsonStringify(self: Result, stream: anytype) !void {
        const active = std.meta.activeTag(self);
        inline for (std.meta.fields(Result)) |f| {
            if (f.type != void and std.mem.eql(u8, @tagName(active), f.name)) {
                try stream.write(@field(self, f.name));
            } else if (f.type == void and std.mem.eql(u8, @tagName(active), f.name)) {
                try stream.objectField("result");
                try stream.beginObject();
                try stream.endObject();
                return;
            }
        }
    }
};
/// Just a empty struct to avoid `avoid` type
const OtherMethod = struct {};

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
pub const RequestMessage = struct {
    const Self = @This();

    jsonrpc: []const u8,
    id: integer,
    params: RequestParams,

    pub fn parseFromSlice(alloc: std.mem.Allocator, s: []const u8) !Self {
        const parsed = try std.json.parseFromSlice(base_type.RequestJSONMessage, alloc, s, .{});
        defer parsed.deinit();
        const value: base_type.RequestJSONMessage = parsed.value;

        var self = try alloc.create(Self);
        errdefer alloc.destroy(self);
        self.id = value.id;

        const param_fields = std.meta.fields(RequestParams);
        inline for (param_fields) |f| {
            if (std.mem.eql(u8, f.name, value.method) and f.type != void) {
                self.params = @unionInit(
                    RequestParams,
                    f.name,
                    (try std.json.parseFromValue(
                        f.type,
                        alloc,
                        value.params.?,
                        .{},
                    )).value,
                );
            }
        }
        self.*.id = value.id;
        return self.*;
    }
};
