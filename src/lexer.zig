const std = @import("std");

pub const TokenType = enum {
    eof,
    lt,
    gt,
    eq,
    slash,
    identifier,
    string,
    number,
    colon,
    question,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

pub fn tokenize(allocator: std.mem.Allocator, file: std.fs.File) ![]Token {
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    var tokens: std.ArrayList(Token) = .empty;
    var i: usize = 0;

    sw: switch (input[i]) {
        '0'...'9' => {
            const start = i;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                i += 1;
            }
            try tokens.append(allocator, Token{ .type = .number, .value = input[start..i] });
            std.debug.assert(i < input.len);
            continue :sw input[i];
        },
        '"' => {
            i += 1;
            if (input[i] == '"') {
                try tokens.append(allocator, Token{ .type = .string, .value = "" });
                i += 1;
                continue :sw input[i];
            }
            const start = i;
            while (i < input.len and input[i] != '"') {
                i += 1;
            }
            try tokens.append(allocator, Token{ .type = .string, .value = input[start..i] });
            i += 1;
            std.debug.assert(i < input.len);
            continue :sw input[i];
        },
        'a'...'z', 'A'...'Z' => {
            const start = i;
            while (i < input.len and ((input[i] >= 'a' and input[i] <= 'z') or (input[i] >= 'A' and input[i] <= 'Z') or input[i] == '_')) {
                i += 1;
            }
            try tokens.append(allocator, Token{ .type = .identifier, .value = input[start..i] });
            std.debug.assert(i < input.len);
            continue :sw input[i];
        },
        '=' => {
            try tokens.append(allocator, Token{ .type = .eq, .value = input[i..(i + 1)] });
            i += 1;
            continue :sw input[i];
        },
        '<' => {
            if (i + 3 < input.len and input[i + 1] == '!' and input[i + 2] == '-' and input[i + 3] == '-') {
                i += 4;
                while (i + 2 < input.len and input[i] != '-' and input[i + 1] != '-' and input[i + 2] != '>') {
                    i += 1;
                }
                i += 2;
                if (i >= input.len) {
                    return error.UnterminatedComment;
                }
                continue :sw input[i];
            }
            try tokens.append(allocator, Token{ .type = .lt, .value = input[i..(i + 1)] });
            i += 1;
            continue :sw input[i];
        },
        '>' => {
            try tokens.append(allocator, Token{ .type = .gt, .value = input[i..(i + 1)] });
            i += 1;
            continue :sw input[i];
        },
        '/' => {
            try tokens.append(allocator, Token{ .type = .slash, .value = input[i..(i + 1)] });
            i += 1;
            continue :sw input[i];
        },
        ':' => {
            try tokens.append(allocator, Token{ .type = .colon, .value = input[i..(i + 1)] });
            i += 1;
            continue :sw input[i];
        },
        '?' => {
            try tokens.append(allocator, Token{ .type = .question, .value = input[i..(i + 1)] });
            i += 1;
            continue :sw input[i];
        },
        else => {
            i += 1;
            if (i == input.len) {
                break :sw;
            }
            continue :sw input[i];
        },
    }
    return tokens.toOwnedSlice(allocator);
}
