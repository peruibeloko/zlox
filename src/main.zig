const std = @import("std");

const Chunk = @import("chunk.zig");
const Op = @import("chunk.zig").Op;
const Value = @import("chunk.zig").Value;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const gpa = arena.allocator();

    var chunk = Chunk.init(gpa);

    const constant_offset = try chunk.addConstant(1.2);
    try chunk.write(Op.CONST.toU8(), 123);
    try chunk.write(constant_offset, 123);
    try chunk.write(Op.RETURN.toU8(), 124);

    chunk.disassemble("test chunk");

    chunk.free();
}
