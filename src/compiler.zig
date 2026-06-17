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

pub fn compile(self: Self, source: []u8) !Chunk {
    self.scanner = Scanner.init(source);

    self.parser.had_error = false;
    self.parser.panic_mode = false;

    self.scanner.advance();

    expression();

    consume(TokenType.Eof, "Expect end of expression.");

    self.end();
    if (self.parser.had_error) return error.CompileError;

    return self.currentChunk();
}

fn advance(self: Self) void {
    const parser = self.parser;
    parser.previous = parser.current;

    while (true) {
        parser.current = self.scanner.getToken();
        if (parser.current.type != TokenType.Error) break;
        parser.errorAtCurrent(parser.current.start);
    }
}

fn consume(self: Self, token_type: TokenType, message: []u8) void {
    if (self.parser.current.type == token_type) {
        self.advance();
        return;
    }

    self.parser.errorAtCurrent(message);
}

fn emitByte(self: Self, byte: u8) void {
    self.currentChunk().write(byte, self.parser.previous.line);
}

fn emitBytes(self: Self, byte1: u8, byte2: u8) void {
    self.emitByte(byte1);
    self.emitByte(byte2);
}

fn emitReturn(self: Self) void {
    self.emitByte(Op.Return.U8());
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

fn end(self: Self) void {
    self.emitReturn();
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
        TokenType.Minus => self.emitByte(Op.Negate),
        else => return,
    }
}

fn expression(self: Self) void {
    self.parsePrecedence(Precedence.Assignment);
}

fn parsePrecedence(self: Self, prec: Precedence) void {
    _ = self;
    _ = prec;
}
