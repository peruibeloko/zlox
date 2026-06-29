const std = @import("std");

const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;

const Scanner = @This();

source: []const u8,
start: usize,
current: usize,
line: usize,

pub fn init(source: []const u8) Scanner {
    return .{
        .source = source,
        .start = 0,
        .current = 0,
        .line = 1,
    };
}

fn isAtEnd(self: *Scanner) bool {
    return self.current >= self.source.len;
}

fn advance(self: *Scanner) u8 {
    self.current += 1;
    return self.source[self.current - 1];
}

fn peek(self: *Scanner) u8 {
    if (self.isAtEnd()) return 0;
    return self.source[self.current];
}

fn peekNext(self: *Scanner) u8 {
    if (self.current >= self.source.len + 1) return 0;
    return self.source[self.current + 1];
}

fn match(self: *Scanner, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.peek() != expected) return false;
    self.current += 1;
    return true;
}

fn produce(self: *Scanner, token_type: TokenType) Token {
    return .{
        .type = token_type,
        .slice = self.source[self.start..self.current],
        .line = self.line,
    };
}

fn errorToken(self: *Scanner, message: []const u8) Token {
    return .{
        .type = TokenType.Error,
        .slice = message,
        .line = self.line,
    };
}

fn isDigit(c: u8) bool {
    return std.ascii.isDigit(c);
}

fn isAlpha(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn skipWhitespace(self: *Scanner) void {
    if (self.isAtEnd()) return;
    while (true) {
        switch (self.peek()) {
            ' ', '\r', '\t' => _ = self.advance(),
            '/' => if (!self.skipComment()) return,
            '\n' => {
                self.line += 1;
                _ = self.advance();
            },
            else => return,
        }
    }
}

fn skipComment(self: *Scanner) bool {
    if (self.peekNext() != '/') return false;
    while (self.peek() != '\n' and !self.isAtEnd()) {
        _ = self.advance();
    }
    return true;
}

fn string(self: *Scanner) Token {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') self.line += 1;
        _ = self.advance();
    }

    if (self.isAtEnd()) return self.errorToken("Unterminated string.");

    _ = self.advance();
    return self.produce(TokenType.String);
}

fn number(self: *Scanner) Token {
    while (isDigit(self.peek()) and !self.isAtEnd()) _ = self.advance();

    if (self.peek() == '.' and isDigit(self.peekNext())) {
        _ = self.advance();
        while (isDigit(self.peek()) and !self.isAtEnd()) _ = self.advance();
    }

    return self.produce(TokenType.Number);
}

fn identifier(self: *Scanner) Token {
    const next = self.peek();
    while (isAlpha(next) or isDigit(next)) _ = self.advance();
    return self.produce(self.identifierType());
}

fn identifierType(self: *Scanner) TokenType {
    return switch (self.source[self.start]) {
        'a' => self.checkKeyword(1, 2, "nd", TokenType.And),
        'c' => self.checkKeyword(1, 4, "lass", TokenType.Class),
        'e' => self.checkKeyword(1, 3, "lse", TokenType.Else),

        'f' => switch (self.source[self.start + 1]) {
            'a' => self.checkKeyword(2, 3, "lse", TokenType.False),
            'o' => self.checkKeyword(2, 1, "r", TokenType.For),
            'u' => self.checkKeyword(2, 1, "n", TokenType.Fun),
            else => TokenType.Identifier,
        },

        'i' => self.checkKeyword(1, 1, "f", TokenType.If),
        'n' => self.checkKeyword(1, 2, "il", TokenType.Nil),
        'o' => self.checkKeyword(1, 1, "r", TokenType.Or),
        'p' => self.checkKeyword(1, 4, "rint", TokenType.Print),
        'r' => self.checkKeyword(1, 5, "eturn", TokenType.Return),
        's' => self.checkKeyword(1, 4, "uper", TokenType.Super),

        't' => switch (self.source[self.start + 1]) {
            'h' => self.checkKeyword(2, 2, "is", TokenType.This),
            'r' => self.checkKeyword(2, 2, "ue", TokenType.True),
            else => TokenType.Identifier,
        },

        'v' => self.checkKeyword(1, 2, "ar", TokenType.Var),
        'w' => self.checkKeyword(1, 4, "hile", TokenType.While),
        else => TokenType.Identifier,
    };
}

fn checkKeyword(
    self: *Scanner,
    start: usize,
    length: usize,
    rest: []const u8,
    token_type: TokenType,
) TokenType {
    if (std.mem.eql(u8, self.source[start .. start + length], rest)) return token_type;
    return TokenType.Identifier;
}

pub fn getToken(self: *Scanner) Token {
    self.skipWhitespace();

    std.log.debug("scanner before reset {any}", .{self});
    self.start = self.current;
    std.log.debug("scanner after reset {any}", .{self});

    if (self.isAtEnd()) return self.produce(TokenType.Eof);

    const c = self.advance();

    if (isAlpha(c)) return self.identifier();
    if (isDigit(c)) return self.number();

    return switch (c) {
        '(' => self.produce(TokenType.LeftParen),
        ')' => self.produce(TokenType.RightParen),
        '{' => self.produce(TokenType.LeftBrace),
        '}' => self.produce(TokenType.RightBrace),
        ';' => self.produce(TokenType.Semicolon),
        ',' => self.produce(TokenType.Comma),
        '.' => self.produce(TokenType.Dot),
        '-' => self.produce(TokenType.Minus),
        '+' => self.produce(TokenType.Plus),
        '/' => self.produce(TokenType.Slash),
        '*' => self.produce(TokenType.Star),

        '!' => self.produce(if (self.match('=')) TokenType.BangEqual else TokenType.Bang),
        '=' => self.produce(if (self.match('=')) TokenType.EqualEqual else TokenType.Equal),
        '<' => self.produce(if (self.match('=')) TokenType.LessEqual else TokenType.Less),
        '>' => self.produce(if (self.match('=')) TokenType.GreaterEqual else TokenType.Greater),

        '"' => self.string(),

        else => self.errorToken("Unexpected character."),
    };
}
