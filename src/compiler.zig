const std = @import("std");
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
    // zig fmt: off
    None,
    Assignment, // =
    Or,         // or
    And,        // and
    Equality,   // == !=
    Comparison, // < > <= >=
    Term,       // + -
    Factor,     // / *
    Unary,      // - !
    Call,       // . ()
    Primary,
    // zig fmt: on

    pub fn U8(self: Precedence) u8 {
        return @intFromEnum(self);
    }
};

const ParseFn = *const fn (self: Self) void;

const ParseRule = struct {
    prefix: ParseFn,
    infix: ParseFn,
    precedence: u8,

    pub fn make(pfx: ParseFn, ifx: ParseFn, prec: Precedence) ParseRule {
        return .{
            .prefix = pfx,
            .infix = ifx,
            .precedence = prec.U8(),
        };
    }
};

parser: Parser,
compilingChunk: *Chunk,

fn currentChunk(self: Self) *Chunk {
    return self.compilingChunk;
}

pub fn init(source: []const u8, chunk: *Chunk) Compiler {
    return .{
        .parser = Parser.init(source),
        .compilingChunk = chunk,
    };
}

pub fn compile(self: Self) bool {
    self.parser.advance();
    self.expression();
    self.parser.consume(TokenType.Eof, "Expect end of expression.");
    self.end();
    return !self.parser.had_error;
}

fn emitByte(self: *Compiler, byte: u8) void {
    var chunk = self.currentChunk();
    chunk.write(byte, self.parser.previous.line);
}

fn emitBytes(self: *Compiler, byte1: u8, byte2: u8) void {
    var chunk = self.currentChunk();
    chunk.write(byte1, self.parser.previous.line);
    chunk.write(byte2, self.parser.previous.line);
}

fn emitReturn(self: *Compiler) void {
    self.emitByte(Op.Return.U8());
}

fn makeConstant(self: *Compiler, value: Value) u8 {
    var chunk = self.currentChunk();
    const offset = chunk.addConstant(value);
    if (offset > 255) {
        self.parser.err("Too many constants in one chunk.");
        return 0;
    }

    return offset;
}

fn emitConstant(self: *Compiler, value: Value) void {
    self.emitBytes(Op.Const.U8(), self.makeConstant(value));
}

fn end(self: *Compiler) void {
    self.emitReturn();

    if (DEBUG_MODE) {
        const chunk = self.currentChunk();
        chunk.disassemble("code");
    }
}

fn binary(self: *Compiler) void {
    const op_type = self.parser.previous.type;
    const rule = getRule(op_type);
    self.parsePrecedence(@enumFromInt(rule.precedence + 1));

    switch (op_type) {
        TokenType.Plus => self.emitByte(Op.Add.U8()),
        TokenType.Minus => self.emitByte(Op.Sub.U8()),
        TokenType.Star => self.emitByte(Op.Mult.U8()),
        TokenType.Slash => self.emitByte(Op.Div.U8()),
        else => return,
    }
}

fn grouping(self: *Compiler) void {
    self.expression();
    self.parser.consume(TokenType.RightParen, "Expect ')' after expression.");
}

fn number(self: *Compiler) void {
    const double = std.fmt.parseFloat(f64, self.parser.previous.getString()) catch {
        return;
    };

    self.emitConstant(double);
}

fn unary(self: *Compiler) void {
    const op_type = self.parser.previous.type;

    self.parsePrecedence(Precedence.Unary);

    switch (op_type) {
        TokenType.Minus => self.emitByte(Op.Negate.U8()),
        else => return,
    }
}

fn noOp(_: *Compiler) void {}

fn getRule(token_type: TokenType) ParseRule {
    return switch (token_type) {
        // zig fmt: off
        .LeftParen    => .make(grouping, noOp,   .None),
        .RightParen   => .make(noOp,     noOp,   .None),
        .LeftBrace    => .make(noOp,     noOp,   .None),
        .RightBrace   => .make(noOp,     noOp,   .None),
        .Comma        => .make(noOp,     noOp,   .None),
        .Dot          => .make(noOp,     noOp,   .None),
        .Minus        => .make(unary,    binary, .Term),
        .Plus         => .make(noOp,     binary, .Term),
        .Semicolon    => .make(noOp,     noOp,   .None),
        .Slash        => .make(noOp,     binary, .Factor),
        .Star         => .make(noOp,     binary, .Factor),
        .Bang         => .make(noOp,     noOp,   .None),
        .BangEqual    => .make(noOp,     noOp,   .None),
        .Equal        => .make(noOp,     noOp,   .None),
        .EqualEqual   => .make(noOp,     noOp,   .None),
        .Greater      => .make(noOp,     noOp,   .None),
        .GreaterEqual => .make(noOp,     noOp,   .None),
        .Less         => .make(noOp,     noOp,   .None),
        .LessEqual    => .make(noOp,     noOp,   .None),
        .Identifier   => .make(noOp,     noOp,   .None),
        .String       => .make(noOp,     noOp,   .None),
        .Number       => .make(number,   noOp,   .None),
        .And          => .make(noOp,     noOp,   .None),
        .Class        => .make(noOp,     noOp,   .None),
        .Else         => .make(noOp,     noOp,   .None),
        .False        => .make(noOp,     noOp,   .None),
        .For          => .make(noOp,     noOp,   .None),
        .Fun          => .make(noOp,     noOp,   .None),
        .If           => .make(noOp,     noOp,   .None),
        .Nil          => .make(noOp,     noOp,   .None),
        .Or           => .make(noOp,     noOp,   .None),
        .Print        => .make(noOp,     noOp,   .None),
        .Return       => .make(noOp,     noOp,   .None),
        .Super        => .make(noOp,     noOp,   .None),
        .This         => .make(noOp,     noOp,   .None),
        .True         => .make(noOp,     noOp,   .None),
        .Var          => .make(noOp,     noOp,   .None),
        .While        => .make(noOp,     noOp,   .None),
        .Error        => .make(noOp,     noOp,   .None),
        .Eof          => .make(noOp,     noOp,   .None),
        // zig fmt: on
    };
}

fn parsePrecedence(self: *Compiler, prec: Precedence) void {
    self.parser.advance();
    const prefixFn: ParseFn = getRule(self.parser.previous.type).prefix;
    if (prefixFn == noOp) {
        self.parser.err("Expect expression.");
        return;
    }

    prefixFn(self);

    while (prec.U8() <= getRule(self.parser.current.type).precedence) {
        self.parser.advance();
        const infixFn = getRule(self.parser.previous.type).infix;
        infixFn(self);
    }
}

fn expression(self: *Compiler) void {
    self.parsePrecedence(Precedence.Assignment);
}
