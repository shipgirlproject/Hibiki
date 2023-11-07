const std = @import("std");
const builtin = @import("builtin");
const util = @import("./util.zig");
const runServer = @import("./server.zig").runServer;
const log = std.log.scoped(.server);

pub fn main() !void {
    const env = util.getEnv() catch |err| {
        std.log.scoped(.fatal).err("couldn't read env: {}\n", .{err});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.os.exit(1);
    };
    const server_addr = env.host orelse "0.0.0.0";
    const server_port = env.port orelse 4242;
    const server_options = util.getServerOptions(env);

    // allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = if (builtin.mode == std.builtin.OptimizeMode.Debug) gpa.allocator() else std.heap.c_allocator;

    // init server
    var server = std.http.Server.init(allocator, server_options);
    defer server.deinit();

    // log address and port
    log.info("running at {s}:{d}", .{ server_addr, server_port });

    // parse address
    const address = std.net.Address.parseIp(server_addr, server_port) catch unreachable;
    try server.listen(address);

    // coerce public key
    const public_key: [32]u8 = env.public_key[0..32].*;

    // run main server loop
    runServer(&server, allocator, public_key) catch |err| {
        // handle error by crashing
        log.err("server error: {}\n", .{err});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.os.exit(1);
    };
}
