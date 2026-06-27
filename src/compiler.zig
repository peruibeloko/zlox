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

    pub fn U8(self: Precedence) u8 {
        return @intFromEnum(self);
    }
};

const ParseFn = *const fn (self: Self) void;

const ParseRule = struct {
    prefix: ParseFn,
    infix: ParseFn,
    precedence: Precedence,

    pub fn make(pfx: ParseFn, ifx: ParseFn, prec: Precedence) ParseRule {
        return .{
            .prefix = pfx,
            .infix = ifx,
            .precedence = prec,
        };
    }
};

parser: Parser,
scanner: Scanner,
compilingChunk: *Chunk,

fn currentChunk(self: Self) *Chunk {
    return self.compilingChunk;
}

pub fn init(source: []const u8, chunk: *Chunk) !Compiler {
    return .{
        .parser = Parser.init(),
        .scanner = Scanner.init(source),
        .compilingChunk = chunk,
    };
}

pub fn compile(self: Self) bool {
    self.parser.had_error = false;
    self.parser.panic_mode = false;

    _ = self.advance();

    self.expression();

    self.consume(TokenType.Eof, "Expect end of expression.");

    self.end();

    return !self.parser.had_error;
}

fn advance(self: Self) void {
    self.parser.previous = self.parser.current;

    while (true) {
        self.parser.current = self.scanner.getToken();
        if (self.parser.current.type != TokenType.Error) break;
        self.parser.errorAtCurrent(self.parser.current.getString());
    }
}

fn consume(self: Self, token_type: TokenType, message: []const u8) void {
    if (self.parser.current.type == token_type) {
        self.advance();
        return;
    }

    self.parser.errorAtCurrent(message);
}

fn emitByte(self: Self, byte: u8) void {
    var chunk = self.currentChunk();
    chunk.write(byte, self.parser.previous.line) catch {
        return;
    };
}

fn emitBytes(self: Self, byte1: u8, byte2: u8) void {
    self.emitByte(byte1);
    self.emitByte(byte2);
}

fn emitReturn(self: Self) void {
    self.emitByte(Op.Return.U8());
}

fn makeConstant(self: Self, value: Value) u8 {
    var chunk = self.currentChunk();

    if (chunk.constants.items.len == 256) {
        self.parser.err("Too many constants in one chunk.");
        return 0;
    }

    const constant_index = chunk.addConstant(value) catch {
        self.parser.err("Out of memory.");
        return 0;
    };

    return constant_index;
}

fn emitConstant(self: Self, value: Value) void {
    self.emitBytes(Op.Const.U8(), self.makeConstant(value));
}

fn end(self: Self) void {
    self.emitReturn();

    if (DEBUG_MODE and !self.parser.had_error) {
        var chunk = self.currentChunk();
        chunk.disassemble("code");
    }
}

fn binary(self: Self) void {
    const opType = self.parser.previous.type;
    const rule = getRule(opType);
    self.parsePrecedence(@enumFromInt(rule.precedence.U8() + 1));

    switch (opType) {
        TokenType.Plus => self.emitByte(Op.Add.U8()),
        TokenType.Minus => self.emitByte(Op.Sub.U8()),
        TokenType.Star => self.emitByte(Op.Mult.U8()),
        TokenType.Slash => self.emitByte(Op.Div.U8()),
        else => return,
    }
}

fn grouping(self: Self) void {
    self.expression();
    self.consume(TokenType.RightParen, "Expect ')' after expression.");
}

fn number(self: Self) void {
    const double = std.fmt.parseFloat(f64, self.parser.previous.getString()) catch {
        return;
    };

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

fn noOp(self: Self) void {
    _ = self;
}

fn parsePrecedence(self: Self, precedence: Precedence) void {
    self.advance();

    std.log.debug("parser state {any}", .{self.parser});

    const prefix_rule = getRule(self.parser.previous.type).prefix;

    if (prefix_rule == &noOp) {
        self.parser.err("Expect expression.");
        return;
    }

    prefix_rule(self);

    const next_prec = precedence.U8();
    const rule_prec = getRule(self.parser.current.type).precedence.U8();

    while (next_prec <= rule_prec) {
        self.advance();
        const infixRule = getRule(self.parser.previous.type).infix;
        infixRule(self);
    }
}

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
