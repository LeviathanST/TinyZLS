const std = @import("std");
const builtin = @import("builtin");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const total_tests = builtin.test_functions.len;

    for (builtin.test_functions, 0..) |t, idx| {
        t.func() catch |err| {
            try out.print("\x1b[31mTest failed: {s} - {} [{d}/{d}]\x1b[0m\n", .{ t.name, err, idx + 1, total_tests });
            continue;
        };
        try out.print("\x1b[32mTest success: {s} [{d}/{d}]\x1b[0m\n", .{ t.name, idx + 1, total_tests });
    }
}
