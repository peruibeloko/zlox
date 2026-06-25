const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = std.Io.Dir;

pub fn readLine(io: Io, buffer: *[]const u8) void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;

    const maybe_line = stdin_reader.takeDelimiter('\n') catch "";

    const raw_line = if (maybe_line) |line| line else "";

    if (raw_line.len == 0) {
        buffer.* = "";
        return;
    }

    buffer.* = if (raw_line[raw_line.len - 1] == '\r')
        raw_line[0 .. raw_line.len - 1]
    else
        raw_line;

    return;
}

pub fn readFile(io: Io, gpa: Allocator, path: []const u8) ![]const u8 {
    const file = try Dir.openFile(Dir.cwd(), io, path, .{ .mode = .read_only });
    const size = try file.length(io);

    const buf = try gpa.alloc(u8, size);
    var file_reader: Io.File.Reader = .init(file, io, buf);
    const reader = &file_reader.interface;

    try reader.readSliceAll(buf);
    return buf;
}

pub fn write(io: Io, comptime fmt: []const u8, args: anytype) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print(fmt, args);
    try stdout_writer.flush();
}
