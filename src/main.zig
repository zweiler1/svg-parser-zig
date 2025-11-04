const std = @import("std");
const svgp = @import("svgp");

pub fn main() !void {
    const svg: svgp.nodes.SVGNode = try svgp.parseFile("./test.svg");
    svg.print();
}

