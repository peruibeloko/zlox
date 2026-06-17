const std = @import("std");

const Chunk = @import("chunk.zig");
const Op = @import("chunk.zig").Op;
const Value = @import("chunk.zig").Value;
const Vm = @import("vm.zig");

const UserIo = @import("read_write.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    var vm = try Vm.init(gpa);

    const args = try init.minimal.args.toSlice(gpa);

    switch (args.len) {
        1 => try repl(init.io, &vm),
        2 => runFile(init.io, gpa, &vm, args[1]),
        else => {
            std.log.err("Usage: zlox [path]\n", .{});
            std.process.exit(64);
        },
    }

    vm.free();
}

fn repl(io: std.Io, vm: *Vm) !void {
    var line: []const u8 = undefined;
    while (true) {
        try UserIo.write(io, "> ", .{});
        line = try UserIo.readLine(io);
        if (line.len == 0) {
            try UserIo.write(io, "\n", .{});
            break;
        }

        vm.interpret(line);
    }
}

fn runFile(io: std.Io, gpa: std.mem.Allocator, vm: *Vm, path: [:0]const u8) !void {
    const source = try UserIo.readFile(io, gpa, path);
    defer gpa.destroy(source);

    const result = vm.interpret(source);

    if (result == Vm.InterpretResult.CompileError) std.process.exit(65);
    if (result == Vm.InterpretResult.RuntimeError) std.process.exit(70);
}
