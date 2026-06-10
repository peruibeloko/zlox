const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Op = enum(u8) { RETURN };

pub const Chunk = struct {
    code: std.ArrayList(Op),

    pub fn init() Chunk {
        return .{ .code = .empty };
    }

    pub fn write(self: *Chunk, gpa: Allocator, op: Op) !void {
        try self.code.append(gpa, op);
    }

    pub fn free(self: *Chunk, gpa: Allocator) void {
        self.code.deinit(gpa);
    }
};
