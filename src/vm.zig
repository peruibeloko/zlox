const std = @import("std");
const Allocator = std.mem.Allocator;
const printf = @import("std").debug.print;

const DEBUG_MODE = true;

const Chunk = @import("chunk.zig");
const Op = @import("chunk.zig").Op;
const Value = @import("chunk.zig").Value;

const Vm = @This();

const InterpretResult = enum {
    OK,
    CompileError,
    RuntimeError,
};

allocator: Allocator,
chunk: Chunk,
ip: [*]u8,
stack: std.ArrayList(Value),

pub fn init(gpa: Allocator) !Vm {
    return .{
        .allocator = gpa,
        .chunk = undefined,
        .ip = undefined,
        .stack = .empty,
    };
}

pub fn free(self: *Vm) void {
    self.stack.deinit(self.allocator);
}

pub fn interpret(self: *Vm, chunk: Chunk) InterpretResult {
    self.chunk = chunk;
    self.ip = self.chunk.code.items.ptr;
    return self.run() catch InterpretResult.RuntimeError;
}

fn readByte(self: *Vm) u8 {
    const ip = self.ip[0];
    self.ip += 1;
    return ip;
}

fn readConstant(self: *Vm) Value {
    return self.chunk.constants.items[self.readByte()];
}

fn push(self: *Vm, value: Value) !void {
    try self.stack.append(self.allocator, value);
}

fn pop(self: *Vm) !Value {
    return self.stack.pop() orelse error.EmptyStack;
}

fn peek(self: *Vm) !Value {
    return self.stack.getLastOrNull() orelse error.EmptyStack;
}

pub fn run(self: *Vm) !InterpretResult {
    while (true) {
        if (DEBUG_MODE) self.showTrace();

        const inst: Op = @enumFromInt(self.readByte());

        switch (inst) {
            Op.CONST => {
                const value = self.readConstant();
                try self.push(value);
                printf("\n", .{});
            },

            Op.NEGATE => try self.push(-try self.pop()),

            Op.RETURN => {
                Chunk.printValue(try self.pop());
                printf("\n", .{});
                return InterpretResult.OK;
            },
        }
    }
}

fn showTrace(self: *Vm) void {
    printf("          ", .{});
    printf("{any}", .{self.stack.items});
    printf("\n", .{});
    _ = self.chunk.disassembleInst(self.ip - self.chunk.code.items.ptr);
}
