const std = @import("std");
const http = std.http;
const mem = std.mem;
const json = std.json;
const Ed25519 = std.crypto.sign.Ed25519;
const log = std.log.scoped(.server);
const string = @import("./util.zig").string;

pub fn runServer(server: *http.Server, allocator: mem.Allocator, app_public_key: [32]u8) !void {
    outer: while (true) {
        // accept connection
        var response = try server.accept(.{ .allocator = allocator });
        defer response.deinit();

        while (response.reset() != .closing) {
            // handle errors during request processing
            response.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            // process the request
            handleRequest(&response, allocator, app_public_key) catch |err| {
                // recover from handle error
                log.err("error handling request: {}\n", .{err});

                response.status = .internal_server_error;
                try response.send();
            };
        }
    }
}

fn handleRequest(response: *http.Server.Response, allocator: mem.Allocator, app_public_key: [32]u8) !void {
    const request = response.request;

    // log request info
    log.debug("{s} {s} {s}", .{ @tagName(request.method), @tagName(request.version), request.target });

    // read body
    const body = try response.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    // set connection header to keep-alive if present in request headers
    if (request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    // only match root route and post request
    if (mem.startsWith(u8, request.target, "/")) {
        // reject methods other than POST
        if (request.method != .POST) {
            response.status = .method_not_allowed;
            return response.send();
        }

        // content-type header must be present
        // x-signature-ed25519 header must be present
        // x-signature-timestamp header must be present
        const content_type = request.headers.getFirstValue("content-type");
        const signature_header = request.headers.getFirstValue("x-signature-ed25519");
        const timestamp_header = request.headers.getFirstValue("x-signature-timestamp");
        if (content_type == null or signature_header == null or timestamp_header == null) {
            response.status = .bad_request;
            return response.send();
        }

        // ensure valid length signature
        if (signature_header.?.len != 64) {
            // assume it is an invalid signature
            response.status = .unauthorized;
            return response.send();
        }

        // reject content-types other than application/json
        if (!mem.eql(u8, content_type.?, "application/json")) {
            response.status = .unsupported_media_type;
            return response.send();
        }

        // coerce string
        const sig: [64]u8 = signature_header.?[0..64].*;

        const signature = Ed25519.Signature.fromBytes(sig);
        const message = try mem.concat(allocator, u8, &.{ timestamp_header.?, body });
        const public_key = try Ed25519.PublicKey.fromBytes(app_public_key);

        // verify signature
        if (signature.verify(message, public_key)) {
            // only parse interaction type
            const InteractionType = struct {
                type: u8,
            };

            // deserialize json body while ignoring fields not specified in struct
            const interaction = try json.parseFromSlice(InteractionType, allocator, body, .{ .ignore_unknown_fields = true });
            defer interaction.deinit();

            // handle interaction, 1 is ping
            if (interaction.value.type == 1) {
                // set content-type to application/json
                try response.headers.append("content-type", "application/json");

                // serialize json body, 1 is pong
                const ping_response_body = try json.stringifyAlloc(allocator, InteractionType{ .type = 1 }, .{});

                // set content length
                response.transfer_encoding = .{ .content_length = ping_response_body.len };

                // respond with headers
                try response.send();

                // respond with body
                try response.writeAll(ping_response_body);
                try response.finish();
            } else {
                // TODO: pass on to consumer (actual app)
            }
        } else |err| switch (err) {
            // send 401 when verification failed according to discord spec
            error.SignatureVerificationFailed => {
                response.status = .unauthorized;
                return response.send();
            },
            // bubble up other errors
            else => |leftover_err| return leftover_err,
        }
    } else {
        response.status = .not_found;
        return response.send();
    }
}

test "Request flow" {}
