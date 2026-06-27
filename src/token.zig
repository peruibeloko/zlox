pub const TokenType = enum(u8) {
    // Single-character tokens.
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,

    // One or two character tokens.
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,

    // Literals.
    Identifier,
    String,
    Number,

    // Keywords.
    And,
    Class,
    Else,
    False,
    For,
    Fun,
    If,
    Nil,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,

    Error,
    Eof,
};

const Token = @This();

type: TokenType,
slice: []const u8,
line: usize,

pub const empty: Token = .{
    .type = .Eof,
    .slice = undefined,
    .line = 0,
};

pub fn getString(self: *Token) []const u8 {
    return self.slice[0..];
}
