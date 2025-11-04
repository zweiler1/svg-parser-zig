const std = @import("std");
const svgp = @import("svgp");

pub fn main() !void {
    // Tokenize
    const test_file = try std.fs.cwd().openFile("./test.svg", .{});
    const tokens = try svgp.lexer.tokenize(std.heap.page_allocator, test_file);

    for (tokens) |token| {
        std.debug.print("{} : '{s}'\n", .{ token.type, token.value });
    }

    std.debug.print("\n", .{});

    var parser: svgp.Parser = .init(tokens);
    const svg: svgp.nodes.SVGNode = try parser.parse(std.heap.page_allocator);
    svg.print();
}

