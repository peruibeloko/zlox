const std = @import("std");

const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;

const Parser = @This();

current: Token,
previous: Token,
had_error: bool,
panic_mode: bool,

pub const empty: Parser = .{
    .current = null,
    .previous = null,
    .had_error = false,
    .panic_mode = false,
};

pub fn errorAtCurrent(self: *Parser, message: []u8) void {
    self.errorAt(self.current, message);
}

pub fn err(self: *Parser, message: []u8) void {
    self.errorAt(self.previous, message);
}

fn errorAt(self: *Parser, token: Token, message: []u8) void {
    if (self.panic_mode) return;
    self.panic_mode = true;
    std.log.err("[line {d}] Error", .{token.line});

    if (token.type == TokenType.Eof) {
        std.log.err(" at end", .{token.line});
    } else if (token.type == TokenType.Error) {} else {
        std.log.err(" at '{s}'", .{token.getString()});
    }

    std.log.err(": {s}\n", .{message});
    self.had_error = true;
}
