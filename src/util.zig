const std = @import("std");
const tls = std.crypto.tls;
const os = std.os;
const io = std.io;

pub const string = []const u8;

pub const TlsStream = struct {
    tls_client: tls.Client,

    pub const ReadError = os.ReadError;
    pub const WriteError = os.WriteError;

    pub const Reader = io.Reader(tls.Client, ReadError, tls.Client.read);
    pub const Writer = io.Writer(tls.Client, WriteError, tls.Client.write);

    pub fn reader(self: TlsStream) Reader {
        return .{ .context = self.tls_client };
    }

    pub fn writer(self: TlsStream) Writer {
        return .{ .context = self.tls_client };
    }
};
