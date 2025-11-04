const std = @import("std");
const lexer = @import("lexer.zig");
const nodes = @import("nodes.zig");

const TokenType = lexer.TokenType;
const Token = lexer.Token;

const Self = @This();

// Whitelist of tags we care about
const SHAPE_TAGS = [_][]const u8{ "rect", "ellipse", "path", "circle", "line", "polyline", "polygon" };

tokens: []Token,
pos: usize,
viewbox_width: f32,
viewbox_height: f32,

pub fn init(svg_tokens: []Token) Self {
    return Self{ .tokens = svg_tokens, .pos = 0, .viewbox_width = 0, .viewbox_height = 0 };
}

pub fn parse(self: *Self, allocator: std.mem.Allocator) !nodes.SVGNode {
    // Skip until we find <svg
    while (self.advance()) |token| {
        if (token.type == .lt) {
            if (self.advance()) |next| {
                if (next.type == .identifier and std.mem.eql(u8, next.value, "svg")) {
                    _ = self.advance();
                    break;
                }
            }
        }
    }

    var main_node: nodes.SVGNode = .{ .width = 0, .height = 0, .nodes = null };

    // Parse the attributes of the SVG
    var attrs = std.StringHashMap([]const u8).init(allocator);
    defer attrs.deinit();
    while (self.peek()) |token| {
        // Check for end of tag
        if (token.type == .gt or token.type == .slash) {
            break;
        }

        // Parse attribute name
        if (token.type == .identifier or token.type == .colon) {
            const name_token = self.advance().?;

            // Skip any namespaced attributes like "xmlns:svg"
            if (self.peek()) |next| {
                if (next.type == .colon) {
                    // skip ':'
                    _ = self.advance();
                    try self.expect(.identifier);
                    // Skip namespaced attributes for now
                    try self.expect(.eq);
                    try self.expect(.string);
                    continue;
                }
            }

            if (token.type == .identifier) {
                try self.expect(.eq);
                const value = self.peek().?;
                try self.expect(.string);
                try attrs.put(name_token.value, value.value);
            }
        } else {
            _ = self.advance();
        }
    }

    // Get the viewBox attribute to get the size of the SVG
    if (attrs.get("viewBox")) |viewbox_str| {
        // viewBox="0 0 210 297" -> extract width and height
        var iter = std.mem.splitScalar(u8, viewbox_str, ' ');
        _ = iter.next(); // skip min_x
        _ = iter.next(); // skip min_y

        if (iter.next()) |width_str| {
            main_node.width = try std.fmt.parseFloat(f32, width_str);
            self.viewbox_width = main_node.width;
        }
        if (iter.next()) |height_str| {
            main_node.height = try std.fmt.parseFloat(f32, height_str);
            self.viewbox_height = main_node.height;
        }
    } else {
        return error.MissingViewBox;
    }

    // Parse child elements (shapes)
    var shape_nodes: std.ArrayList(nodes.Node) = .empty;
    var depth: usize = 1;

    while (self.peek()) |token| {
        // Check for /> closing tags
        if (token.type == .slash and self.peekNext().?.type == .gt) {
            depth -= 1;
            try self.expect(.slash);
            try self.expect(.gt);
            continue;
        }
        if (token.type == .gt) {
            depth -= 1;
            try self.expect(.gt);
            continue;
        }
        if (token.type != .lt) {
            _ = self.advance();
            continue;
        }
        depth += 1;
        _ = self.advance() orelse break;
        const next = self.peek().?;

        // Check for closing tag </svg>
        if (next.type == .slash) {
            const identifier = self.advance() orelse break;
            if (std.mem.eql(u8, identifier.value, "svg")) {
                break;
            } else {
                // Skip everything to including the >
                while (self.peek().?.type != .gt) {
                    _ = self.advance();
                }
                try self.expect(.gt);
                // -1 because it's the end tag and -1 because we incremented at the top of the loop
                depth -= 2;
                continue;
            }
        }

        // Check if it's a whitelisted tag
        if (next.type == .identifier) {
            const tag_name = next.value;

            if (isWhitelisted(tag_name)) {
                // Parse the shape
                if (try self.parseShape(allocator, tag_name)) |node| {
                    try shape_nodes.append(allocator, node);
                }
            } else {
                // Skip unknown/unwanted tags entirely
                try self.skipElement();
            }
        }
    }

    main_node.nodes = try shape_nodes.toOwnedSlice(allocator);
    return main_node;
}

fn isWhitelisted(tag_name: []const u8) bool {
    inline for (SHAPE_TAGS) |allowed| {
        if (std.mem.eql(u8, tag_name, allowed)) {
            return true;
        }
    }
    return false;
}

fn skipElement(self: *Self) !void {
    // Get tag name
    const tag = self.peek().?;
    try self.expect(.identifier);

    // Skip attributes until we find >, /> or </name...>
    var depth: usize = 1;
    while (self.peek()) |token| {
        if (token.type == .lt and self.peekNext().?.type == .slash) {
            try self.expect(.lt);
            try self.expect(.slash);
            const possible_tag = self.peek() orelse return error.EndTagWithoutTagName;
            // Check if the tag is the same as this element's tag
            std.debug.assert(possible_tag.type == .identifier);
            const is_tag: bool = std.mem.eql(u8, possible_tag.value, tag.value);
            while (self.peek().?.type != .gt) {
                _ = self.advance();
            }
            try self.expect(.gt);
            if (is_tag) {
                // This is the end tag for the element so we need to return after the >
                return;
            } else {
                // This is an in-between tag for the element so we need to continue after the >
                continue;
            }
        } else if (token.type == .lt) {
            depth += 1;
        } else if (token.type == .gt) {
            _ = self.advance();
            depth -= 1;
            if (depth == 0) {
                return;
            }
        }
        _ = self.advance();
    }
}

fn parseShape(self: *Self, allocator: std.mem.Allocator, tag_name: []const u8) !?nodes.Node {
    _ = self.advance(); // consume tag name

    // Parse attributes
    var attrs = std.StringHashMap([]const u8).init(allocator);
    defer attrs.deinit();

    while (self.peek()) |token| {
        if (token.type == .gt or token.type == .slash) {
            break;
        }

        if (token.type == .identifier) {
            const name_token = self.advance().?;

            // Skip namespaced attributes
            if (self.peek()) |next| {
                if (next.type == .colon) {
                    _ = self.advance(); // skip ':'
                    _ = self.advance(); // skip identifier
                    try self.expect(.eq);
                    _ = self.advance(); // skip value
                    continue;
                }
            }

            try self.expect(.eq);
            const value = self.peek().?;
            try self.expect(.string);
            try attrs.put(name_token.value, value.value);
        } else {
            _ = self.advance();
        }
    }

    // Skip /> or >
    if (self.peek()) |token| {
        if (token.type == .slash) {
            _ = self.advance();
        }
    }
    try self.expect(.gt);

    // Parse style to get color and stroke-width
    const style = try self.parseStyle(attrs.get("style"));

    // Create the appropriate node based on tag type
    if (std.mem.eql(u8, tag_name, "rect")) {
        const x = try std.fmt.parseFloat(f32, attrs.get("x") orelse "0");
        const y = try std.fmt.parseFloat(f32, attrs.get("y") orelse "0");
        const width = try std.fmt.parseFloat(f32, attrs.get("width") orelse "0");
        const height = try std.fmt.parseFloat(f32, attrs.get("height") orelse "0");

        return nodes.Node{
            .u = .{ .rect = nodes.RectNode{
                .x = x / self.viewbox_width,
                .y = y / self.viewbox_height,
                .width = width / self.viewbox_width,
                .height = height / self.viewbox_height,
            } },
            .style = style,
        };
    } else if (std.mem.eql(u8, tag_name, "ellipse")) {
        const cx = try std.fmt.parseFloat(f32, attrs.get("cx") orelse "0");
        const cy = try std.fmt.parseFloat(f32, attrs.get("cy") orelse "0");
        const rx = try std.fmt.parseFloat(f32, attrs.get("rx") orelse "0");
        const ry = try std.fmt.parseFloat(f32, attrs.get("ry") orelse "0");

        return nodes.Node{
            .u = .{ .ellipse = nodes.EllipseNode{
                .cx = cx / self.viewbox_width,
                .cy = cy / self.viewbox_height,
                .rx = rx / self.viewbox_width,
                .ry = ry / self.viewbox_height,
            } },
            .style = style,
        };
    } else if (std.mem.eql(u8, tag_name, "path")) {
        // Path parsing is complex, return empty paths for now
        return nodes.Node{
            .u = .{ .path = nodes.PathNode{
                .start = .{ .x = 0, .y = 0 },
                .commands = &[_]nodes.PathCommand{},
            } },
            .style = style,
        };
    }

    return null;
}

fn parseStyle(self: *Self, style_str: ?[]const u8) !nodes.Style {
    _ = self;
    var color = nodes.Color{ .r = 0, .g = 0, .b = 0, .a = 1.0 };
    var stroke_width: f32 = 0.0;

    if (style_str) |style| {
        // Parse "fill:#161923;stroke-width:0.264583;fill-opacity:1"
        var iter = std.mem.splitScalar(u8, style, ';');
        while (iter.next()) |property| {
            if (property.len == 0) continue;

            var prop_iter = std.mem.splitScalar(u8, property, ':');
            const key = std.mem.trim(u8, prop_iter.next() orelse continue, " \t");
            const value = std.mem.trim(u8, prop_iter.next() orelse continue, " \t");

            if (std.mem.eql(u8, key, "fill")) {
                const rgb = try parseColor(value);
                color.r = rgb.r;
                color.g = rgb.g;
                color.b = rgb.b;
                // Skip a since the 'fill' does not contain the alpha value
            } else if (std.mem.eql(u8, key, "fill-opacity")) {
                color.a = try std.fmt.parseFloat(f32, value);
            } else if (std.mem.eql(u8, key, "stroke-width")) {
                stroke_width = try std.fmt.parseFloat(f32, value);
            }
        }
    }

    return nodes.Style{
        .color = color,
        .stroke_width = stroke_width,
    };
}

fn parseColor(hex_str: []const u8) !nodes.Color {
    // Parse "#161923" -> RGB
    if (hex_str.len < 7 or hex_str[0] != '#') {
        return error.InvalidColor;
    }

    const r = try std.fmt.parseInt(u8, hex_str[1..3], 16);
    const g = try std.fmt.parseInt(u8, hex_str[3..5], 16);
    const b = try std.fmt.parseInt(u8, hex_str[5..7], 16);

    return nodes.Color{
        .r = @as(f32, @floatFromInt(r)) / 255.0,
        .g = @as(f32, @floatFromInt(g)) / 255.0,
        .b = @as(f32, @floatFromInt(b)) / 255.0,
        .a = 1.0,
    };
}

fn peek(self: *Self) ?Token {
    if (self.pos >= self.tokens.len) return null;
    return self.tokens[self.pos];
}

fn peekNext(self: *Self) ?Token {
    if (self.pos + 1 >= self.tokens.len) return null;
    return self.tokens[self.pos + 1];
}

fn advance(self: *Self) ?Token {
    const token = self.peek();
    self.pos += 1;
    return token;
}

fn expect(self: *Self, token_type: TokenType) !void {
    const token = self.advance() orelse return error.UnexpectedEOF;
    if (token.type != token_type) {
        return error.UnexpectedToken;
    }
}
