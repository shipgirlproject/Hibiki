const std = @import("std");
const builtin = @import("builtin");
const struct_env = @import("struct-env");
const env_log = std.log.scoped(.env);

pub const string = []const u8;

// preventing segfaults when envs aren't present/are wrong type
const StructEnv = struct {
    host: ?string,
    port: ?string,
    server_max_connections: ?string,
    public_key: ?string,
    app_host: ?string,
    app_port: ?string,
};

pub const AppEnv = struct {
    host: ?string,
    port: ?u16,
    server_max_connections: ?u31,
    public_key: string,
    app_host: string,
    app_port: u16,
};

pub fn getEnv() !AppEnv {
    // allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = if (builtin.mode == std.builtin.OptimizeMode.Debug) gpa.allocator() else std.heap.c_allocator;

    // get env
    const env: StructEnv = try struct_env.fromPrefixedEnv(allocator, StructEnv, "HIBIKI_");
    defer struct_env.free(allocator, env);

    // find all unset envs before exit
    var unset_envs: bool = false;

    // ensure non-optional env vars set
    if (env.public_key == null) {
        env_log.err("required env HIBIKI_PUBLIC_KEY not set", .{});
        unset_envs = true;
    }

    if (env.app_host == null) {
        env_log.err("required env HIBIKI_APP_HOST not set", .{});
        unset_envs = true;
    }

    if (env.app_port == null) {
        env_log.err("required env HIBIKI_APP_PORT not set", .{});
        unset_envs = true;
    }

    // exit after detecting all unset mandatory env
    if (unset_envs) {
        std.os.exit(1);
    }

    // find all invalid envs before exit
    var invalid_envs: bool = false;

    var env_port: ?u16 = null;
    if (env.port != null) {
        env_port = std.fmt.parseInt(u16, env.port.?, 10) catch blk: {
            env_log.err("env HIBIKI_PORT must be an unsigned 16-bit integer", .{});
            invalid_envs = true;
            break :blk null;
        };
    }

    var env_server_max_connections: ?u31 = null;
    if (env.server_max_connections != null) {
        env_server_max_connections = std.fmt.parseInt(u31, env.server_max_connections.?, 10) catch blk: {
            env_log.err("env HIBIKI_SERVER_MAX_CONNECTIONS must be an unsigned 31-bit integer", .{});
            invalid_envs = true;
            break :blk null;
        };
    }

    var env_app_port: ?u16 = null;
    env_app_port = std.fmt.parseInt(u16, env.app_port.?, 10) catch blk: {
        env_log.err("env HIBIKI_APP_PORT must be an unsigned 16-bit integer", .{});
        invalid_envs = true;
        break :blk null;
    };

    // validate public key length
    if (env.public_key.?.len != 32) {
        env_log.err("env HIBIKI_PUBLIC_KEY must be 32 characters long", .{});
        invalid_envs = true;
    }

    if (invalid_envs) {
        std.os.exit(1);
    }

    return AppEnv{
        .host = env.host,
        .port = env_port,
        .server_max_connections = env_server_max_connections,
        .public_key = env.public_key.?,
        .app_host = env.app_host.?,
        .app_port = env_app_port.?,
    };
}

pub fn getServerOptions(env: AppEnv) std.net.StreamServer.Options {
    return std.net.StreamServer.Options{
        .reuse_address = true,
        .kernel_backlog = env.server_max_connections orelse 128,
    };
}
