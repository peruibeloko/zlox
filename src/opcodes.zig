pub const Op = enum(u8) {
    Const,
    Add,
    Sub,
    Mult,
    Div,
    Negate,
    Return,

    pub fn U8(self: Op) u8 {
        return @intFromEnum(self);
    }
};
