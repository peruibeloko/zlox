const std = @import("std");
const Allocator = std.mem.Allocator;
const printf = std.log.debug;

const DEBUG_MODE = true;

const Chunk = @import("chunk.zig");
const Op = @import("chunk.zig").Op;
const Value = @import("chunk.zig").Value;
const Compiler = @import("compiler.zig");

const Vm = @This();

pub const InterpretResult = enum {
    Ok,
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

pub fn interpret(self: *Vm, source: []u8) InterpretResult {
    const chunk = Compiler.compile(source);

    self.chunk = chunk;
    self.ip = self.chunk.code.items.ptr;

    const result = self.run() catch {
        return InterpretResult.RuntimeError;
    };

    self.free();
    return result;
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

inline fn add(a: Value, b: Value) Value {
    return a + b;
}

inline fn sub(a: Value, b: Value) Value {
    return a - b;
}

inline fn mul(a: Value, b: Value) Value {
    return a * b;
}

inline fn div(a: Value, b: Value) Value {
    return a / b;
}

const BinOp = fn (a: Value, b: Value) Value;

fn binaryOp(self: *Vm, op: BinOp) !void {
    const b: Value = try self.pop();
    const a: Value = try self.pop();
    try self.push(op(a, b));
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

            Op.ADD => try self.binaryOp(add),
            Op.SUB => try self.binaryOp(sub),
            Op.MULT => try self.binaryOp(mul),
            Op.DIV => try self.binaryOp(div),

            Op.NEGATE => try self.push(-try self.pop()),

            Op.RETURN => {
                Chunk.printValue(try self.pop());
                printf("\n", .{});
                return InterpretResult.Ok;
            },
        }
    }
}

fn showTrace(self: *Vm) void {
    printf("          ", .{});
    printf("{any}", .{self.stack.items});
    printf("\n", .{});

    // end address - start address = position offset
    // remember, pointers are just addresses, and addresses are just numbers
    _ = self.chunk.disassembleInst(self.ip - self.chunk.code.items.ptr);
}
