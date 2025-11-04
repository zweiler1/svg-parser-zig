const std = @import("std");

pub const lexer = @import("lexer.zig");
pub const nodes = @import("nodes.zig");
pub const Parser = @import("Parser.zig");

pub fn parse(data: []const u8) !nodes.SVGNode {
    const tokens = try lexer.tokenize(std.heap.page_allocator, data);
    var parser: Parser = .init(tokens);
    const svg: nodes.SVGNode = try parser.parse(std.heap.page_allocator);
    return svg;
}

pub fn parseFile(relative_path: []const u8) !nodes.SVGNode {
    const file = try std.fs.cwd().openFile(relative_path, .{});
    const input = try file.readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize));
    return try parse(input);
}
