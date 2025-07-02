const std = @import("std");

const Instruction = union(enum) {
    pub const FaceVertex = struct { i32, ?i32, ?i32 };

    // Vertex data
    v: WavefrontObject.Vertex, // Geometric vertices
    vt, // Texture vertices
    vn, // Vertex normals
    vp, // Parameter space vertices

    // Free-form curve/surface attributes
    deg, // Degree
    bmat, // Basis matrix
    step, // Step size
    cstype, // Curve or surface type

    // Elements
    p, // Point
    l, // Line
    f: WavefrontObject.Face, // Face
    curv, // Curve
    curv2, // 2D curve
    surf, // Surface

    // Free-form curve/surface body statements
    parm, // Parameter values
    trim, // Outer trimming loop
    hole, // Inner trimming loop
    scrv, // Special curve
    sp, // Special point
    end, // End statement

    // Connectivity between free-form surfaces
    conConnect,

    // Grouping
    g, // Group name
    s, // Smoothing group
    mg, // Merging group
    o, // Object name

    // Display/render attributes
    bevel, // Bevel interpolation
    c_interp, // Color interpolation
    d_interp, // Dissolve interpolation
    lod, // Level of detail
    usemtl, // Material name
    mtllib, // Material library
    shadow_obj, // Shadow casting
    trace_obj, // Ray tracing
    ctech, // Curve approximation technique
    stech, // Surface approximation technique

    pub fn ignore(self: @This()) bool {
        switch (self) {
            .v, .f => return false,

            .vt, .vn, .vp, .deg, .bmat, .step, .cstype, .p, .l, .curv, .curv2, .surf, .parm, .trim, .hole, .scrv, .sp, .end, .conConnect, .g, .s, .mg, .o, .bevel, .c_interp, .d_interp, .lod, .usemtl, .mtllib, .shadow_obj, .trace_obj, .ctech, .stech => return true,
        }
    }

    pub fn partialFrom(str: []const u8) ?@This() {
        const field_names = comptime std.meta.fieldNames(@This());
        inline for (field_names) |field_name| {
            if (std.mem.eql(u8, str, field_name)) {
                return @unionInit(@This(), field_name, undefined);
            }
        }
        return null;
    }

    pub fn deinit(self: Instruction, allocator: std.mem.Allocator) void {
        switch (self) {
            .v => {},
            .f => |f| allocator.free(f),

            inline else => |_, tag| comptime {
                const tag_instance = @unionInit(@This(), @tagName(tag), undefined);
                const data = @field(tag_instance, @tagName(tag));
                const TagType = @TypeOf(data);
                if (!tag_instance.ignore() or TagType != void) {
                    @compileError("Unhandled instruction " ++ @tagName(tag));
                }
            },
        }
    }
};

pub const WavefrontObject = struct {
    pub const Vertex = [4]f32;
    pub const Face = []FaceVertex;
    pub const FaceVertex = struct { i32, ?i32, ?i32 };

    vertices: []Vertex,
    faces: []Face,

    fn parseLine(line: []const u8, allocator: std.mem.Allocator) !?Instruction {
        var line_part_iter = std.mem.tokenizeScalar(u8, line, ' ');
        const instruction_str = line_part_iter.next() orelse return null;
        if (instruction_str[0] == '#') return null;
        var instruction = Instruction.partialFrom(instruction_str) orelse return error.UnknownInstruction;
        if (instruction.ignore()) return null;
        switch (instruction) {
            .v => |*vertex_data| {
                vertex_data[3] = 1.0; // default value for w
                var index: usize = 0;
                while (line_part_iter.next()) |field| : (index += 1) {
                    if (index >= vertex_data.len) return error.InvalidInstruction;
                    vertex_data[index] = std.fmt.parseFloat(f32, field) catch return error.InvalidInstruction;
                }
                if (index < 3) return error.InvalidInstruction;
            },
            .f => |*face_data| {
                var vertices = std.ArrayList(FaceVertex).init(allocator);
                errdefer vertices.deinit();
                while (line_part_iter.next()) |field| {
                    var vertex_parts = std.mem.splitScalar(u8, field, '/');
                    const vertex_index_str = vertex_parts.next() orelse return error.InvalidInstruction;
                    const vertex_texture_str = vertex_parts.next();
                    const vertex_normal_str = vertex_parts.next();
                    if (vertex_parts.next() != null) return error.InvalidInstruction;

                    const vertex_normal = if (vertex_normal_str) |str| std.fmt.parseInt(i32, str, 10) catch return error.InvalidInstruction else null;
                    const vertex_texture =
                        if (vertex_texture_str) |str|
                            if (vertex_normal != null and str.len == 0)
                                null
                            else
                                std.fmt.parseInt(i32, str, 10) catch return error.InvalidInstruction
                        else
                            null;
                    const vertex_index = std.fmt.parseInt(i32, vertex_index_str, 10) catch return error.InvalidInstruction;

                    try vertices.append(.{ vertex_index, vertex_texture, vertex_normal });
                }
                if (vertices.items.len < 3) return error.InvalidInstruction;
                face_data.* = try vertices.toOwnedSlice();
            },
            inline else => |_, tag| comptime if (!@unionInit(Instruction, @tagName(tag), undefined).ignore()) @compileError("Unhandled instruction " ++ @tagName(tag)),
        }
        return instruction;
    }

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !WavefrontObject {
        var vertices = std.ArrayList(Vertex).init(allocator);
        errdefer vertices.deinit();
        var faces = std.ArrayList(Face).init(allocator);
        errdefer faces.deinit();

        while (true) {
            var line_buffer: [256]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&line_buffer);
            reader.streamUntilDelimiter(fbs.writer(), '\n', null) catch |e| {
                switch (e) {
                    error.NoSpaceLeft => return error.LineTooLong,
                    error.EndOfStream => if (fbs.getWritten().len == 0) break,
                    else => return error.ReadingError,
                }
            };
            const line = fbs.getWritten();
            const instruction = try parseLine(line, allocator) orelse continue;
            switch (instruction) {
                .v => |vertex_data| try vertices.append(vertex_data),
                .f => |face_data| try faces.append(face_data),
                inline else => |_, tag| comptime if (!@unionInit(Instruction, @tagName(tag), undefined).ignore()) @compileError("Unhandled instruction " ++ @tagName(tag)),
            }
        }

        return WavefrontObject{
            .vertices = try vertices.toOwnedSlice(),
            .faces = try faces.toOwnedSlice(),
        };
    }

    pub fn deinit(self: WavefrontObject, allocator: std.mem.Allocator) void {
        allocator.free(self.faces);
        allocator.free(self.vertices);
    }

    test "parseLine" {
        const vertex_line = try WavefrontObject.parseLine("v 0.223704 -0.129772 0.901477", std.testing.allocator);
        defer if (vertex_line) |v| v.deinit(std.testing.allocator);
        try std.testing.expectEqualDeep(Instruction{ .v = .{ 0.223704, -0.129772, 0.901477, 1.0 } }, vertex_line);

        const face_line = try WavefrontObject.parseLine("f 38 42 21 20", std.testing.allocator);
        defer if (face_line) |f| f.deinit(std.testing.allocator);
        var f: [4]WavefrontObject.FaceVertex = .{ .{ 38, null, null }, .{ 42, null, null }, .{ 21, null, null }, .{ 20, null, null } };
        try std.testing.expectEqualDeep(Instruction{ .f = &f }, face_line);
    }
};
