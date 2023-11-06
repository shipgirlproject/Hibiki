const std = @import("std");
const util = @import("./util.zig");
const runServer = @import("./server.zig").runServer;
const log = std.log.scoped(.server);

pub fn main() !void {
    const env = try util.getEnv();
    const server_addr = env.host orelse "0.0.0.0";
    const server_port = env.port orelse 3000;
    const server_options = util.getServerOptions(env);
    const allocator = util.getAllocator();

    // init server
    var server = std.http.Server.init(allocator, server_options);
    defer server.deinit();

    // log address and port
    log.info("running at {s}:{d}", .{ server_addr, server_port });

    // parse address
    const address = std.net.Address.parseIp(server_addr, server_port) catch unreachable;
    try server.listen(address);

    // run main server loop
    runServer(&server, allocator, env.public_key) catch |err| {
        // handle error by crashing
        log.err("server error: {}\n", .{err});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.os.exit(1);
    };
}
