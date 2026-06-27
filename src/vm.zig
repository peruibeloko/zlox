const std = @import("std");
const Allocator = std.mem.Allocator;

pub const DEBUG_MODE = true;

const Chunk = @import("chunk.zig");
const Op = @import("opcodes.zig").Op;
const Value = @import("value.zig").Value;
const Compiler = @import("compiler.zig");

const Vm = @This();

pub const InterpretResult = enum {
    Ok,
    CompileError,
    RuntimeError,
};

allocator: Allocator,
chunk: *Chunk,
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

pub fn interpret(self: *Vm, source: []const u8) InterpretResult {
    var chunk = Chunk.init(self.allocator);
    defer chunk.free();

    var compiler = Compiler.init(source, &chunk) catch {
        return InterpretResult.RuntimeError;
    };

    if (!compiler.compile()) return InterpretResult.CompileError;

    self.chunk = &chunk;
    self.ip = self.chunk.code.items.ptr;

    const result = self.run() catch InterpretResult.RuntimeError;

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

fn add(a: Value, b: Value) Value {
    return a + b;
}

fn sub(a: Value, b: Value) Value {
    return a - b;
}

fn mul(a: Value, b: Value) Value {
    return a * b;
}

fn div(a: Value, b: Value) Value {
    return a / b;
}

const BinOp = *const fn (a: Value, b: Value) Value;

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
            Op.Const => {
                const value = self.readConstant();
                try self.push(value);
                std.debug.print("\n", .{});
            },

            Op.Add => try self.binaryOp(add),
            Op.Sub => try self.binaryOp(sub),
            Op.Mult => try self.binaryOp(mul),
            Op.Div => try self.binaryOp(div),

            Op.Negate => try self.push(-try self.pop()),

            Op.Return => {
                Chunk.printValue(try self.pop());
                std.debug.print("\n", .{});
                return InterpretResult.Ok;
            },
        }
    }
}

fn showTrace(self: *Vm) void {
    std.debug.print("          ", .{});
    std.debug.print("{any}", .{self.stack.items});
    std.debug.print("\n", .{});

    // end address - start address = position offset
    // remember, pointers are just addresses, and addresses are just numbers
    _ = self.chunk.disassembleInst(self.ip - self.chunk.code.items.ptr);
}
