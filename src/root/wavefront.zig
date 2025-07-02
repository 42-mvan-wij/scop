const std = @import("std");
const zgl = @import("zgl");
pub const raw = @import("./wavefront/raw.zig");

pub const WavefrontOpengl = struct {
    pub const Vertex = [3]zgl.Float;
    pub const Index = zgl.UInt;

    vertices: []Vertex,
    vertex_indices: []Index,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !WavefrontOpengl {
        const raw_object = try raw.WavefrontObject.parse(reader, allocator);
        defer raw_object.deinit(allocator);
        return try convert(raw_object, allocator);
    }

    pub fn convert(raw_object: raw.WavefrontObject, allocator: std.mem.Allocator) !WavefrontOpengl {
        const vertices = try allocator.alloc(Vertex, raw_object.vertices.len);
        errdefer allocator.free(vertices);
        var vertex_index_count: usize = 0;
        for (raw_object.faces) |face| {
            std.debug.assert(face.len >= 3);
            vertex_index_count += 3 + (face.len - 3) * 3;
        }
        const vertex_indices = try allocator.alloc(Index, vertex_index_count);
        errdefer allocator.free(vertex_indices);

        for (vertices, raw_object.vertices) |*vertex, raw_vertex| {
            vertex.* = .{ raw_vertex[0] / raw_vertex[3], raw_vertex[1] / raw_vertex[3], raw_vertex[2] / raw_vertex[3] };
        }
        var vertex_indices_index: usize = 0;
        for (raw_object.faces) |face| {
            vertex_indices_index += convertFaceToVertexIndices(face, @intCast(vertices.len), vertex_indices[vertex_indices_index..]);
        }

        return WavefrontOpengl{
            .vertices = vertices,
            .vertex_indices = vertex_indices,
        };
    }

    fn vertexIndex(vertex_count: Index, index: i32) Index {
        const bits1 = @typeInfo(Index).int.bits;
        const bits2 = @typeInfo(i32).int.bits;
        const more_bits = if (bits1 > bits2) bits1 else bits2;
        const Fit = std.meta.Int(.signed, more_bits * 2);
        if (index < 0)
            return @intCast(@as(Fit, @intCast(vertex_count)) + index)
        else
            return @intCast(index - 1);
    }

    fn convertFaceToVertexIndices(face: raw.WavefrontObject.Face, vertex_count: Index, vertex_indices: []Index) usize {
        vertex_indices[0] = vertexIndex(vertex_count, face[0][0]);
        vertex_indices[1] = vertexIndex(vertex_count, face[1][0]);
        vertex_indices[2] = vertexIndex(vertex_count, face[2][0]);
        var vertex_indices_index: usize = 3;
        for (face[3..]) |face_vertex| {
            vertex_indices[vertex_indices_index] = vertex_indices[0];
            vertex_indices[vertex_indices_index + 1] = vertex_indices[vertex_indices_index - 1];
            vertex_indices[vertex_indices_index + 2] = vertexIndex(vertex_count, face_vertex[0]);
            vertex_indices_index += 3;
        }
        return vertex_indices_index;
    }

    pub fn deinit(self: WavefrontOpengl, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.vertex_indices);
    }
};
