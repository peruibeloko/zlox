const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Value = f32;

pub const Op = enum(u8) { CONSTANT, RETURN };

const Chunk = @This();

// todo: roll our own dynamic array
code: std.ArrayList(u8),
constants: std.ArrayList(Value),

pub fn init() Chunk {
    return .{ .code = .empty, .constants = .empty };
}

pub fn writeOp(self: *Chunk, gpa: Allocator, op: Op) !void {
    try self.code.append(gpa, @intFromEnum(op));
}

pub fn writeRaw(self: *Chunk, gpa: Allocator, byte: u8) !void {
    try self.code.append(gpa, byte);
}

pub fn addConstant(self: *Chunk, gpa: Allocator, value: Value) !u8 {
    try self.constants.append(gpa, value);
    return self.constants.items.len - 1;
}

pub fn free(self: *Chunk, gpa: Allocator) void {
    self.code.deinit(gpa);
    self.constants.deinit(gpa);
}
