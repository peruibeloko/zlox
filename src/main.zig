const std = @import("std");

const Chunk = @import("chunk.zig");
const Op = @import("chunk.zig").Op;
const Value = @import("chunk.zig").Value;
const Vm = @import("vm.zig");

const UserIo = @import("read_write.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    var vm = try Vm.init(gpa);
    defer vm.free();

    const args = try init.minimal.args.toSlice(gpa);

    switch (args.len) {
        1 => repl(),
        2 => runFile(init.io, gpa, args[1]),
        else => {
            std.log.err("Usage: zlox [path]\n", .{});
            std.process.exit(64);
        },
    }
}

fn repl() void {
    var line: []u8 = undefined;
    while (true) {
        UserIo.write("> ", .{});
        line = UserIo.readLine();
        if (line.len == 0) {
            UserIo.write("\n", .{});
            break;
        }

        Vm.interpret(line);
    }
}

fn runFile(io: std.Io, gpa: std.mem.Allocator, path: []u8) void {
    const source = UserIo.readFile(io, gpa, path);
    defer gpa.destroy(source);

    const result = Vm.interpret(source);
    if (result == Vm.InterpretResult.CompileError) std.process.exit(65);
    if (result == Vm.InterpretResult.RuntimeError) std.process.exit(70);
}
