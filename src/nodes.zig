const std = @import("std");

pub const Node = @import("Node.zig");

pub const SVGNode = struct {
    width: f32,
    height: f32,
    nodes: ?[]Node,

    pub fn print(self: *const SVGNode) void {
        std.debug.print("SVGNode: {d}x{d}\n", .{ self.width, self.height });
        if (self.nodes) |nodes| {
            for (nodes, 0..) |node, i| {
                std.debug.print("Node {d}:\n", .{i});
                node.print(1);
                std.debug.print("\n", .{});
            }
        }
    }
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Style = struct {
    color: Color, // the alpha channel is the fill_opacity
    stroke_width: f32,
};

pub const RectNode = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const EllipseNode = struct {
    cx: f32,
    cy: f32,
    rx: f32,
    ry: f32,
};

pub const PathNode = struct {
    start: Point,
    commands: []PathCommand,
};

pub const PathCommand = union(enum) {
    line_to: Point,
    cubic_bezier: CubicBezier,
    close_path: void,
};

pub const Point = struct {
    x: f32,
    y: f32,
};

pub const CubicBezier = struct {
    control_1: Point,
    control_2: Point,
    end: Point,
};
