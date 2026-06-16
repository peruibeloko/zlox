const std = @import("std");

const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;

const Scanner = @This();

start: [*]u8,
current: [*]u8,
line: usize,

pub const empty: Scanner = .{
    .start = null,
    .current = null,
    .line = 0,
};

pub fn init(source: []u8) Scanner {
    return .{
        .start = source.ptr,
        .current = source.ptr,
        .line = 1,
    };
}

fn isAtEnd(self: *Scanner) bool {
    return self.current[0] == 0;
}

pub fn advance(self: *Scanner) u8 {
    self.current += 1;
    return self.current[-1];
}

fn match(self: *Scanner, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.current[0] != expected) return false;
    self.current += 1;
    return true;
}

fn peek(self: *Scanner) u8 {
    return self.current[0];
}

fn peekNext(self: *Scanner) u8 {
    if (self.isAtEnd()) return 0;
    return self.current[1];
}

fn produce(self: *Scanner, token_type: TokenType) Token {
    return .{
        .type = token_type,
        .start = self.start,
        .length = self.current - self.start,
        .line = self.line,
    };
}

fn errorToken(self: *Scanner, message: []const u8) Token {
    return .{
        .type = TokenType.Error,
        .start = message.ptr,
        .length = message.len,
        .line = self.line,
    };
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

fn skipWhitespace(self: *Scanner) void {
    while (true) {
        switch (self.peek()) {
            ' ', '\r', '\t' => self.advance(),
            '/' => self.skipComment(),
            else => return,
        }
    }
}

fn skipComment(self: *Scanner) void {
    if (self.peekNext() != '/') return;
    while (self.peek() != '\n' and !self.isAtEnd()) {
        self.advance();
    }
}

fn string(self: *Scanner) Token {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') self.line += 1;
        self.advance();
    }

    if (self.isAtEnd()) return self.errorToken("Unterminated string.");

    self.advance();
    return self.produce(TokenType.String);
}

fn number(self: *Scanner) Token {
    while (isDigit(self.peek())) self.advance();

    if (self.peek() == '.' and isDigit(self.peekNext())) {
        self.advance();
        while (isDigit(self.peek())) self.advance();
    }

    return self.produce(TokenType.Number);
}

fn identifier(self: *Scanner) Token {
    const next = self.peek();
    while (isAlpha(next) or isDigit(next)) self.advance();
    return self.produce(self.identifierType());
}

fn identifierType(self: *Scanner) TokenType {
    switch (self.start[0]) {
        'a' => return self.checkKeyword(1, 2, "nd", TokenType.And),
        'c' => return self.checkKeyword(1, 4, "lass", TokenType.Class),
        'e' => return self.checkKeyword(1, 3, "lse", TokenType.Else),

        'f' => if (self.current - self.start > 1) {
            switch (self.start[1]) {
                'a' => return self.checkKeyword(2, 3, "lse", TokenType.False),
                'o' => return self.checkKeyword(2, 1, "r", TokenType.For),
                'u' => return self.checkKeyword(2, 1, "n", TokenType.Fun),
            }
        },

        'i' => return self.checkKeyword(1, 1, "f", TokenType.If),
        'n' => return self.checkKeyword(1, 2, "il", TokenType.Nil),
        'o' => return self.checkKeyword(1, 1, "r", TokenType.Or),
        'p' => return self.checkKeyword(1, 4, "rint", TokenType.Print),
        'r' => return self.checkKeyword(1, 5, "eturn", TokenType.Return),
        's' => return self.checkKeyword(1, 4, "uper", TokenType.Super),

        't' => if (self.current - self.start > 1) {
            switch (self.start[1]) {
                'h' => return self.checkKeyword(2, 2, "is", TokenType.This),
                'r' => return self.checkKeyword(2, 2, "ue", TokenType.True),
            }
        },

        'v' => return self.checkKeyword(1, 2, "ar", TokenType.Var),
        'w' => return self.checkKeyword(1, 4, "hile", TokenType.While),
    }

    return TokenType.Identifier;
}

fn checkKeyword(
    self: *Scanner,
    start: usize,
    length: usize,
    rest: []u8,
    token_type: TokenType,
) TokenType {
    const right_size = self.current - self.start == start + length;

    const right_content = for (start..start + length) |i| {
        if (self.start[i] != rest[i]) return false;
    } else true;

    if (right_size and right_content) return token_type;
    return TokenType.Identifier;
}

pub fn getToken(self: *Scanner) Token {
    self.skipWhitespace();
    self.start = self.current;

    if (!self.isAtEnd()) return self.produce(TokenType.Eof);

    const c = self.advance();

    if (isAlpha(c)) return self.identifier();
    if (isDigit(c)) return self.number();

    switch (c) {
        '(' => return self.produce(TokenType.LeftParen),
        ')' => return self.produce(TokenType.RightParen),
        '{' => return self.produce(TokenType.LeftBrace),
        '}' => return self.produce(TokenType.RightBrace),
        ';' => return self.produce(TokenType.Semicolon),
        ',' => return self.produce(TokenType.Comma),
        '.' => return self.produce(TokenType.Dot),
        '-' => return self.produce(TokenType.Minus),
        '+' => return self.produce(TokenType.Plus),
        '/' => return self.produce(TokenType.Slash),
        '*' => return self.produce(TokenType.Star),

        '!' => return self.produce(if (self.match('=')) TokenType.BangEqual else TokenType.Bang),
        '=' => return self.produce(if (self.match('=')) TokenType.EqualEqual else TokenType.Equal),
        '<' => return self.produce(if (self.match('=')) TokenType.LessEqual else TokenType.Less),
        '>' => return self.produce(if (self.match('=')) TokenType.GreaterEqual else TokenType.Greater),

        '"' => return self.string(),

        '\n' => {
            self.line += 1;
            self.advance();
        },

        else => return,
    }

    return self.errorToken("Unexpected character.");
}
