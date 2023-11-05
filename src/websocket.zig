const std = @import("std");
const websocket = @import("ws");
const util = @import("util.zig");
const string = util.string;

pub const WebsocketStatus = enum { OPEN, CONNECTING, CLOSING, CLOSED };
pub const WebsocketEvent = enum { OPEN, CLOSE, MESSAGE, ERROR, DEBUG };
pub const ConnectError = error{ ALREADY_OPEN, NOT_CLOSED };

fn parseAddress(address: string) !struct { uri: string = null, secure: bool = null, port: u16 = null } {
    const uri = try std.Uri.parse(address);
    const useHttps = (std.mem.eql(u8, uri.scheme, "https://") or std.mem.eql(u8, uri.scheme, "wss://")) or std.mem.eql(u8, uri.port, "https://");
    const port: u16 = if (uri.port) uri.port else (if (useHttps) 443 else 80);
    const protocol = if (useHttps) "wss" else "ws";
    const ws_uri = try std.fmt.comptimePrint("{s}://{s}:{d}/{s}{s}", .{ protocol, uri.host, uri.port, uri.path, uri.query });

    return .{
        .uri = ws_uri,
        .secure = useHttps,
        .port = port,
    };
}

pub const Handler = struct {
    allocator: std.mem.Allocator,
    socket: websocket.stream.Stream(std.net.Stream.Reader or util.TlsStream.Reader, std.net.Stream.Writer or util.TlsStream.Writer),

    pub fn init(allocator: std.mem.Allocator, address: string) !Handler {
        const addr = try parseAddress(address);

        const tcp = try std.net.tcpConnectToHost(allocator, addr.host, addr.port);
        defer tcp.close();

        if (addr.secure) {
            const tls_bundle = block: {
                var bundle = std.crypto.Certificate.Bundle{};
                try bundle.rescan(allocator);
                break :block bundle;
            };
            defer tls_bundle.deinit(allocator);

            const tls_tcp = try std.crypto.tls.Client.init(tcp, tls_bundle, addr.host);
            const tls_stream = util.TlsStream{ .tls_client = tls_tcp };
            const tls_client = try websocket.client(allocator, tls_stream.reader(), tls_stream.writer(), addr.uri);

            return Handler{
                .allocator = allocator,
                .socket = tls_client,
            };
        }

        const client = try websocket.client(allocator, tcp.reader(), tcp.writer(), addr.uri);

        return Handler{
            .allocator = allocator,
            .socket = client,
        };
    }

    pub fn deinit() !void {}

    pub fn readLoop(self: *Handler) !void {
        while (self.socket.nextMessage()) |msg| {
            defer msg.deinit();
            self.handleMessage(msg);
        }
        if (self.socket.err) |e| {
            self.handleError(e);
        } else {
            self.handleClosed();
        }
    }

    pub fn handleError(_: Handler, e: anyerror) !void {
        _ = e;
    }

    pub fn handleClosed(_: Handler) !void {}

    pub fn handleMessage(_: Handler, message: websocket.Message) !void {
        _ = message;
    }

    pub fn write(self: *Handler, encoding: websocket.Message.Encoding, payload: string, no_compress: bool) !void {
        return self.socket.send(encoding, payload, no_compress);
    }

    pub fn close(self: *Handler) !void {
        return self.socket.deinit();
    }
};

test "Address Parsing" {}

// pub fn Websocket() type {
//     return struct {
//         const Self = @This();
//         pub const status = WebsocketStatus.CLOSED;
//         var ws: websocket.stream.Stream = null;

//         fn connect(self: *Self, address: string) ConnectError!Self {
//             if (self.status == WebsocketStatus.CONNECTING or self.status == WebsocketStatus.OPEN) {
//                 return error.ALREADY_OPEN;
//             }

//             if (self.status == WebsocketStatus.CLOSING) {
//                 return error.NOT_CLOSED;
//             }

//             const addr = try self.parseAddress(address);

//             var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
//             defer std.debug.assert(!gpa.deinit());
//             const allocator = if (std.builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

//             status = WebsocketStatus.CONNECTING;
//             var tcp = try std.net.tcpConnectToHost(allocator, addr.host, addr.port);
//             defer tcp.close();

//             ws = try websocket.client(allocator, tcp.reader(), tcp.writer(), addr.uri);
//             defer ws.deinit();
//             self.status = WebsocketStatus.OPEN;

//             return ws;
//         }

//         fn close(self: *Self, code: u8, reason: ?string) !void {
//             _ = reason;
//             _ = code;
//             if (self.ws == null) {
//                 return;
//             }
//         }
//     };
// }
