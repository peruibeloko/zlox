const std = @import("std");
const printf = std.log.debug;
const Allocator = std.mem.Allocator;

const Scanner = @import("scanner.zig");
const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;
const Chunk = @import("chunk.zig");
const Parser = @import("parser.zig");
const Op = @import("opcodes.zig").Op;
const Value = @import("value.zig").Value;
const DEBUG_MODE = @import("vm.zig").DEBUG_MODE;

const Compiler = @This();
const Self = *Compiler;

const Precedence = enum(u8) {
    None,
    Assignment, // =
    Or, // or
    And, // and
    Equality, // == !=
    Comparison, // < > <= >=
    Term, // + -
    Factor, // * /
    Unary, // ! -
    Call, // . ()
    Primary,
};

const ParseRule = struct {
    prefix: ParseFn,
    infix: ParseFn,
    precedence: Precedence,
};

const ParseFn = *const fn (self: Self) void;

parser: Parser,
scanner: Scanner,
compilingChunk: Chunk,

fn currentChunk(self: Self) Chunk {
    return self.compilingChunk;
}

pub fn init(gpa: Allocator) Compiler {
    return .{
        .parser = .empty,
        .scanner = .empty,
        .compilingChunk = Chunk.init(gpa),
    };
}

pub fn compile(self: Self, source: []const u8) !Chunk {
    self.scanner = Scanner.init(source);

    self.parser.had_error = false;
    self.parser.panic_mode = false;

    _ = self.scanner.advance();

    self.expression();

    self.consume(TokenType.Eof, "Expect end of expression.");

    try self.end();
    if (self.parser.had_error) return error.CompileError;

    return self.currentChunk();
}

fn advance(self: Self) void {
    var parser = self.parser;
    parser.previous = parser.current;

    while (true) {
        parser.current = self.scanner.getToken();
        if (parser.current.type != TokenType.Error) break;
        parser.errorAtCurrent(parser.current.getString());
    }
}

fn consume(self: Self, token_type: TokenType, message: []const u8) void {
    if (self.parser.current.type == token_type) {
        self.advance();
        return;
    }

    self.parser.errorAtCurrent(message);
}

fn emitByte(self: Self, byte: u8) !void {
    var chunk = self.currentChunk();
    try chunk.write(byte, self.parser.previous.line);
}

fn emitBytes(self: Self, byte1: u8, byte2: u8) void {
    self.emitByte(byte1);
    self.emitByte(byte2);
}

fn emitReturn(self: Self) !void {
    try self.emitByte(Op.Return.U8());
}

fn makeConstant(self: Self, value: Value) u8 {
    const constant_index = self.currentChunk().addConstant(value);

    if (constant_index > 255) {
        self.parser.err("Too many constants in one chunk.");
        return 0;
    }

    return constant_index;
}

fn emitConstant(self: Self, value: Value) void {
    self.emitBytes(Op.Const.U8(), self.makeConstant(value));
}

fn end(self: Self) !void {
    try self.emitReturn();

    if (DEBUG_MODE and !self.parser.had_error) {
        var chunk = self.currentChunk();
        chunk.disassemble("code");
    }
}

fn binary(self: Self) void {
    const opType = self.parser.previous.type;
    const rule = self.getRule(opType);
    self.parsePrecedence(rule.precedence + 1);

    switch (opType) {
        TokenType.Plus => self.emitByte(Op.Add),
        TokenType.Minus => self.emitByte(Op.Sub),
        TokenType.Star => self.emitByte(Op.Mult),
        TokenType.Slash => self.emitByte(Op.Div),
        else => return,
    }
}

fn grouping(self: Self) void {
    self.expression();
    self.consume(TokenType.RightParen, "Expect ')' after expression.");
}

fn number(self: Self) void {
    const double = try std.fmt.parseFloat(f64, self.parser.previous.getString());
    self.emitConstant(double);
}

fn unary(self: Self) void {
    const opType = self.parser.previous.type;

    self.parsePrecedence(Precedence.Unary);

    switch (opType) {
        TokenType.Minus => self.emitByte(Op.Negate.U8()),
        else => return,
    }
}

fn expression(self: Self) void {
    self.parsePrecedence(Precedence.Assignment);
}

fn parsePrecedence(self: Self, precedence: Precedence) void {
    self.advance();
    const prefixRule = getRule(self.parser.previous.type).prefix.*;

    if (prefixRule == null) {
        self.parser.err("Expect expression.");
        return;
    }

    prefixRule(self);

    while (precedence <= getRule(self.parser.current.type).precedence) {
        self.advance();
        const infixRule = getRule(self.parser.previous.type).infix.*;
        infixRule(self);
    }
}

fn getRule(token_type: TokenType) ParseRule {
    return switch (token_type) {
        // zig fmt: off
        .LeftParen    => .{ grouping, null,   .None },
        .RightParen   => .{ null,     null,   .None },
        .LeftBrace    => .{ null,     null,   .None },
        .RightBrace   => .{ null,     null,   .None },
        .Comma        => .{ null,     null,   .None },
        .Dot          => .{ null,     null,   .None },
        .Minus        => .{ unary,    binary, .Term },
        .Plus         => .{ null,     binary, .Term },
        .Semicolon    => .{ null,     null,   .None },
        .Slash        => .{ null,     binary, .Factor },
        .Star         => .{ null,     binary, .Factor },
        .Bang         => .{ null,     null,   .None },
        .BangEqual    => .{ null,     null,   .None },
        .Equal        => .{ null,     null,   .None },
        .EqualEqual   => .{ null,     null,   .None },
        .Greater      => .{ null,     null,   .None },
        .GreaterEqual => .{ null,     null,   .None },
        .Less         => .{ null,     null,   .None },
        .LessEqual    => .{ null,     null,   .None },
        .Identifier   => .{ null,     null,   .None },
        .String       => .{ null,     null,   .None },
        .Number       => .{ number,   null,   .None },
        .And          => .{ null,     null,   .None },
        .Class        => .{ null,     null,   .None },
        .Else         => .{ null,     null,   .None },
        .False        => .{ null,     null,   .None },
        .For          => .{ null,     null,   .None },
        .Fun          => .{ null,     null,   .None },
        .If           => .{ null,     null,   .None },
        .Nil          => .{ null,     null,   .None },
        .Or           => .{ null,     null,   .None },
        .Print        => .{ null,     null,   .None },
        .Return       => .{ null,     null,   .None },
        .Super        => .{ null,     null,   .None },
        .This         => .{ null,     null,   .None },
        .True         => .{ null,     null,   .None },
        .Var          => .{ null,     null,   .None },
        .While        => .{ null,     null,   .None },
        .Error        => .{ null,     null,   .None },
        .Eof          => .{ null,     null,   .None },
        // zig fmt: on
    };
}
