const std = @import("std");
const printf = @import("std").debug.print;
const Allocator = std.mem.Allocator;
const String = []const u8;

const Chunk = @This();

pub const Value = f32;

pub const Op = enum(u8) {
    CONST,
    RETURN,

    pub fn toU8(self: Op) u8 {
        return @intFromEnum(self);
    }
};

allocator: Allocator,
code: std.ArrayList(u8),
constants: std.ArrayList(Value),
lines: std.array_hash_map.Auto(usize, usize),

pub fn init(gpa: Allocator) Chunk {
    return .{
        .allocator = gpa,
        .code = .empty,
        .constants = .empty,
        .lines = .empty,
    };
}

pub fn write(self: *Chunk, byte: u8, line: usize) !void {
    try self.code.append(self.allocator, byte);
    try self.writeLine(line);
}

pub fn addConstant(self: *Chunk, value: Value) !u8 {
    if (self.constants.items.len == 256) return error.TooManyConstants;
    try self.constants.append(self.allocator, value);
    return @intCast(self.constants.items.len - 1);
}

pub fn free(self: *Chunk) void {
    self.code.deinit(self.allocator);
    self.constants.deinit(self.allocator);
    self.lines.deinit(self.allocator);
}

// debugging

fn writeLine(self: *Chunk, line: usize) !void {
    if (self.lines.get(line)) |count| {
        try self.lines.put(self.allocator, line, count + 1);
    } else {
        try self.lines.put(self.allocator, line, 1);
    }
}

// todo tá errado
fn getLine(self: *Chunk, inst_index: usize) usize {
    var iter = self.lines.iterator();
    var offset: usize = 0;
    var line: usize = 0;
    var count: usize = 0;
    while (iter.next()) |entry| {
        line = entry.key_ptr.*;
        count = entry.value_ptr.*;
        offset += count;
        if (offset >= inst_index) return line;
    } else return line;
}

pub fn disassemble(self: *Chunk, name: String) void {
    printf("== {s} ==\n", .{name});

    var inst_offset: usize = 0;
    while (inst_offset < self.code.items.len) {
        inst_offset = disassembleInst(self, inst_offset);
    }
}

fn disassembleInst(self: *Chunk, inst_offset: usize) usize {
    printf("{d:04} ", .{inst_offset});

    const line = self.getLine(inst_offset);
    if (inst_offset > 0 and line == self.getLine(inst_offset - 1)) {
        printf("   | ", .{});
    } else {
        printf("{d:04} ", .{line});
    }

    const inst: Op = @enumFromInt(self.code.items[inst_offset]);

    switch (inst) {
        Op.CONST => return self.constantInst("OP_CONST", inst_offset),
        Op.RETURN => return Chunk.simpleInst("OP_RETURN", inst_offset),
    }
}

fn constantInst(self: *Chunk, name: String, inst_offset: usize) usize {
    const const_offset = self.code.items[inst_offset + 1];
    printf("{s:<16} {d:04} '", .{ name, const_offset });
    printValue(self.constants.items[const_offset]);
    printf("'\n", .{});
    return inst_offset + 2;
}

fn simpleInst(name: String, inst_offset: usize) usize {
    printf("{s}\n", .{name});
    return inst_offset + 1;
}

fn printValue(value: Value) void {
    printf("{any}", .{value});
}
