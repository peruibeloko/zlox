const std = @import("std");

const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;
const Scanner = @import("scanner.zig");

const Parser = @This();

scanner: Scanner,
current: Token,
previous: Token,
had_error: bool,
panic_mode: bool,

pub fn init(source: []const u8) Parser {
    return .{
        .scanner = Scanner.init(source),
        .current = .empty,
        .previous = .empty,
        .had_error = false,
        .panic_mode = false,
    };
}

pub fn errorAtCurrent(self: *Parser, message: []const u8) void {
    self.errorAt(self.current, message);
}

pub fn err(self: *Parser, message: []const u8) void {
    self.errorAt(self.previous, message);
}

fn errorAt(self: *Parser, token: Token, message: []const u8) void {
    if (self.panic_mode) return;
    self.panic_mode = true;
    std.log.err("[line {d}] Error", .{token.line});

    if (token.type == TokenType.Eof) {
        std.log.err(" at end", .{});
    } else if (token.type == TokenType.Error) {} else {
        std.log.err(" at '{s}'", .{token.getString()});
    }

    std.log.err(": {s}\n", .{message});
    self.had_error = true;
}

pub fn advance(self: *Parser) void {
    self.previous = self.current;

    while (true) {
        self.current = self.scanner.scanToken();
        if (self.current.type != TokenType.Error) break;

        self.errorAtCurrent(self.current.getString());
    }
}

pub fn consume(self: *Parser, tk_type: TokenType, message: []const u8) void {
    if (self.current.type == tk_type) {
        self.advance();
        return;
    }

    self.errorAtCurrent(message);
}
