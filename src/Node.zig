const std = @import("std");
const nodes = @import("nodes.zig");

const Self = @This();

pub const BoundingBox = struct {
    min: nodes.Point,
    max: nodes.Point,
};

u: union(enum) {
    rect: nodes.RectNode,
    ellipse: nodes.EllipseNode,
    path: nodes.PathNode,
},
style: nodes.Style,

pub fn print(self: *const Self, level: usize) void {
    indent(level);
    std.debug.print("shape: ", .{});
    switch (self.u) {
        .rect => |rect| {
            std.debug.print("rect {{\n", .{});
            indent(level + 1);
            std.debug.print("x: {d},\n", .{rect.x});
            indent(level + 1);
            std.debug.print("y: {d},\n", .{rect.y});
            indent(level + 1);
            std.debug.print("width: {d},\n", .{rect.width});
            indent(level + 1);
            std.debug.print("height: {d}\n", .{rect.height});
            indent(level);
            std.debug.print("}}\n", .{});
        },
        .ellipse => |ellipse| {
            std.debug.print("ellipse {{\n", .{});
            indent(level + 1);
            std.debug.print("cx: {d},\n", .{ellipse.cx});
            indent(level + 1);
            std.debug.print("cy: {d},\n", .{ellipse.cy});
            indent(level + 1);
            std.debug.print("rx: {d},\n", .{ellipse.rx});
            indent(level + 1);
            std.debug.print("ry: {d}\n", .{ellipse.ry});
            indent(level);
            std.debug.print("}}\n", .{});
        },
        .path => |path| {
            std.debug.print("path {{\n", .{});
            indent(level + 1);
            std.debug.print("paths: [{d} paths]\n", .{path.paths.len});
            indent(level);
            std.debug.print("}}\n", .{});
        },
    }

    indent(level);
    std.debug.print("style: {{\n", .{});
    indent(level + 1);
    std.debug.print("color: {{ r: {d}, g: {d}, b: {d}, a: {d} }},\n", self.style.color);
    indent(level + 1);
    std.debug.print("stroke_width: {d}\n", .{self.style.stroke_width});
    indent(level);
    std.debug.print("}}\n", .{});
}

pub fn getBoundingBox(self: *const Self) !BoundingBox {
    switch (self.u) {
        .rect => |rect| {
            return .{
                .min = .{ .x = rect.x, .y = rect.y },
                .max = .{ .x = rect.x + rect.width, .y = rect.y + rect.height },
            };
        },
        .ellipse => |ellipse| {
            return .{
                .min = .{ .x = ellipse.cx - ellipse.rx, .y = ellipse.cy - ellipse.ry },
                .max = .{ .x = ellipse.cx + ellipse.rx, .y = ellipse.cy + ellipse.ry },
            };
        },
        .path => |_| {
            return error.NotImplementedYet;
            // Calculate from start point and all commands
            // This one is more complex
            // return calculatePathBoundingBox(path);
        },
    }
}

fn indent(level: usize) void {
    for (0..level * 4) |_| {
        std.debug.print(" ", .{});
    }
}
