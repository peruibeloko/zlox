const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = std.Io.Dir;

pub fn readLine(io: Io) ![]const u8 {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;

    const raw_line = try stdin_reader.takeDelimiter('\n') orelse unreachable;
    const line = std.mem.trim(u8, raw_line, "\r");
    return line;
}

pub fn readFile(io: Io, gpa: Allocator, path: []const u8) ![]const u8 {
    return try Dir.readFileAlloc(Dir.cwd(), io, path, gpa);
}

pub fn write(io: Io, fmt: []const u8, args: anytype) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print(fmt, args);
    try stdout_writer.flush();
}
