const std = @import("std");
const svgp = @import("svgp");

pub fn main() !void {
    const test_file = try std.fs.cwd().openFile("./test.svg", .{});
    const tokens = try svgp.lexer.tokenize(std.heap.page_allocator, test_file);

    for (tokens) |token| {
        std.debug.print("{} : '{s}'\n", .{ token.type, token.value });
    }
}
