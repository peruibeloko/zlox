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

    _ = switch (args.len) {
        1 => try repl(init.io, &vm),
        2 => try runFile(init.io, gpa, &vm, args[1]),
        else => {
            std.log.err("Usage: zlox [path]\n", .{});
            std.process.exit(64);
        },
    };

    vm.free();
}

fn repl(io: std.Io, vm: *Vm) !void {
    while (true) {
        try UserIo.write(io, "> ", .{});

        var stdin_buffer: [1024]u8 = undefined;
        var stdin_file_reader: std.Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
        const stdin_reader = &stdin_file_reader.interface;

        const maybe_line = stdin_reader.takeDelimiter('\n') catch "";

        const raw_line = if (maybe_line) |s| s else "";

        // isso só retorna um slice que não contém o \r
        // não necessariamente remove ele da memória
        const line = std.mem.trimEnd(u8, raw_line, "\r");

        if (line.len == 0) {
            try UserIo.write(io, "\n", .{});
            continue;
        }

        _ = vm.interpret(line);
    }
}

fn runFile(io: std.Io, gpa: std.mem.Allocator, vm: *Vm, path: [:0]const u8) !void {
    const source = try UserIo.readFile(io, gpa, path);
    defer gpa.free(source);

    const result = vm.interpret(source);

    if (result == Vm.InterpretResult.CompileError) std.process.exit(65);
    if (result == Vm.InterpretResult.RuntimeError) std.process.exit(70);
}
