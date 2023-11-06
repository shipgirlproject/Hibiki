const std = @import("std");
const builtin = @import("builtin");
const struct_env = @import("struct-env");

pub const string = []const u8;

pub fn getAllocator() std.mem.Allocator {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = if (builtin.mode == std.builtin.OptimizeMode.Debug) gpa.allocator() else std.heap.c_allocator;
    return allocator;
}

pub const AppEnv = struct {
    host: ?string,
    port: ?u16,
    server_max_connections: ?u31,
    public_key: string,
};

pub fn getEnv() !AppEnv {
    const allocator = getAllocator();
    const env = try struct_env.fromPrefixedEnv(allocator, AppEnv, "HIBIKI_");
    defer struct_env.free(allocator, env);
    return env;
}

pub fn getServerOptions(env: AppEnv) std.net.StreamServer.Options {
    return std.net.StreamServer.Options{
        .reuse_address = true,
        .kernel_backlog = env.server_max_connections orelse 128,
    };
}
