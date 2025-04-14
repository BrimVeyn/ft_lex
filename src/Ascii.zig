const std = @import("std");

pub fn isBlank(c: u8) bool {
    return c == ' ' or c == '\t';
}

pub fn isPunct(c: u8) bool {
    return !std.ascii.isAlphanumeric(c) and std.ascii.isPrint(c);
}

pub fn isGraph(c: u8) bool {
    return std.ascii.isPrint(c) and c != ' ';
}

pub fn notZero(c: u8) bool {
    return c != 0x00;
}

pub fn isOctal(c: u8) bool {
    return c >= '0' and c <= '7';
}
