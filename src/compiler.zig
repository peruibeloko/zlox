const std = @import("std");
const printf = std.log.debug;

const Scanner = @import("scanner.zig");
const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;

const Compiler = @This();

pub fn compile(source: []u8) void {
    const scanner = Scanner.init(source);

    var line = -1;

    while (true) {
        const token = scanner.getToken();

        if (token.line != line) {
            printf("{d:04} ", .{token.line});
            line = token.line;
        } else {
            printf("{any} '{s}'\n", .{
                token.type,
                source[token.start .. token.start + token.length],
            });
        }

        if (token.type == TokenType.Eof) {
            break;
        }
    }
}
