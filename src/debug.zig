const std = @import("std");

const Chunk = @import("chunk.zig").Chunk;
const Op = @import("chunk.zig").Op;
const String = []const u8;

pub fn disassembleChunk(chunk: Chunk, name: String) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.code.items.len) {
        offset = disassembleInst(chunk, offset);
    }
}

pub fn disassembleInst(chunk: Chunk, offset: usize) usize {
    std.debug.print("{d:04} ", .{offset});
    const inst = chunk.code.items[offset];

    switch (inst) {
        Op.RETURN => return simpleInst("OP_RETURN", offset),
        // TODO else branch returns error, disassemble returns error union
        // else => {
        //     std.debug.print("Unknown opcode {d}\n", .{inst});
        //     return offset + 1;
        // },
    }
}

fn simpleInst(name: String, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
