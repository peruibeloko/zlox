const std = @import("std");

const Chunk = @import("chunk.zig");
const Op = @import("chunk.zig").Op;
const Value = @import("chunk.zig").Value;
const Dbg = @import("debug.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const gpa = arena.allocator();

    var chunk = Chunk.init();

    try chunk.writeOp(gpa, Op.RETURN);
    const constant = try chunk.addConstant(gpa, 1.2);
    try chunk.writeOp(gpa, Op.CONSTANT);
    try chunk.writeRaw(gpa, constant);

    Dbg.disassembleChunk(chunk, "test chunk");

    chunk.free(gpa);
}
