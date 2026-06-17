const std = @import("std");
const printf = std.log.debug;
const Allocator = std.mem.Allocator;

const Scanner = @import("scanner.zig");
const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;
const Chunk = @import("chunk.zig");
const Parser = @import("parser.zig");
const Op = @import("opcodes.zig").Op;

const Compiler = @This();
const Self = *Compiler;

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
    // expression();
    consume(TokenType.Eof, "Expect end of expression.");
    self.end();
    if (self.parser.had_error) return error.CompileError;
    // return ;
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

fn end(self: Self) void {
    self.emitReturn();
}
