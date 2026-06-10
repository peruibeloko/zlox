const std = @import("std");

const Chunk = @import("chunk.zig").Chunk;
const Op = @import("chunk.zig").Op;
const Dbg = @import("debug.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const gpa = arena.allocator();

    var chunk = Chunk.init();
    try chunk.write(gpa, Op.RETURN);
    Dbg.disassembleChunk(chunk, "test chunk");

    chunk.free(gpa);
}
