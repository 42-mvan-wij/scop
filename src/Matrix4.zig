const std = @import("std");

const Matrix4 = @This();

// NOTE: Stored in row-major order (a.k.a. matrix.data[row][column])
data: [4][4]f32,

pub fn init(data: *const [4][4]f32) Matrix4 {
    return .{
        .data = data.*,
    };
}

pub fn zero() Matrix4 {
    return .{
        .data = @splat(@splat(0.0)),
    };
}

pub fn unit() Matrix4 {
    return init(&.{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    });
}

pub fn perspective(fov: f32, ratio: f32, near: f32, far: f32) Matrix4 {
    const fov_rad = std.math.degreesToRadians(fov);
    const right = std.math.tan(fov_rad / 2.0) * near;
    const top = right / ratio;

    return init(&.{
        .{ near / right, 0.0, 0.0, 0.0 },
        .{ 0.0, near / top, 0.0, 0.0 },
        .{ 0.0, 0.0, (far + near) / (near - far), 2.0 * far * near / (near - far) },
        .{ 0.0, 0.0, -1.0, 0.0 },
    });
}

// (z * scale + constant) / -z = depth
// -scale + constant / -z = depth
// scale = constant / -z - depth
//
// scale = constant / near - near_depth = constant / far - far_depth
// constant / near - near_depth = constant / far - far_depth
// constant - near_depth * near = constant / far * near - far_depth * near
// constant * far - near_depth * near * far = constant * near - far_depth * near * far
// constant * far - constant * near = near_depth * near * far - far_depth * near * far
// constant * (far - near) = near_depth * near * far - far_depth * near * far
// constant = (near_depth - far_depth) * near * far / (far - near)
//
// scale = constant / near - near_depth
// scale = (near_depth - far_depth) * near * far / (far - near) / near - near_depth
// scale = (near_depth - far_depth) * far / (far - near) - near_depth * (far - near) / (far - near)
// scale = (near_depth - far_depth) * far / (far - near) - (near_depth * far - near_depth * near) / (far - near)
// scale = ((near_depth - far_depth) * far - (near_depth * far - near_depth * near)) / (far - near)
// scale = (near_depth * far - far_depth * far - near_depth * far + near_depth * near) / (far - near)
// scale = (near_depth * near - far_depth * far) / (far - near)
//
// [-1, 1]
// constant = (-1 - 1) * near * far / (far - near) = -2 * near * far / (far - near) = 2 * near * far / (near - far)
// scale = (-1 * near - 1 * far) / (far - near) = (-near - far) / (far - near) = (near + far) / (near - far)
//
// [0, 1]
// constant = (0 - 1) * near * far / (far - near) = -1 * near * far / (far - near) = near * far / (near - far)
// scale = (0 * near - 1 * far) / (far - near) = -far / (far - near) = far / (near - far)

pub fn multiply(left: *const Matrix4, right: *const Matrix4) Matrix4 {
    var result = Matrix4.zero();
    for (0..4) |row| {
        for (0..4) |column| {
            for (0..4) |index| {
                result.data[row][column] += left.data[row][index] * right.data[index][column];
            }
        }
    }
    return result;
}

pub fn chain(matrices: []const *const Matrix4) Matrix4 {
    var result = Matrix4.unit();
    for (matrices) |matrix| {
        result = matrix.multiply(&result);
    }
    return result;
}

pub fn translation(translate: *const [3]f32) Matrix4 {
    return Matrix4.init(&.{
        .{ 1.0, 0.0, 0.0, translate[0] },
        .{ 0.0, 1.0, 0.0, translate[1] },
        .{ 0.0, 0.0, 1.0, translate[2] },
        .{ 0.0, 0.0, 0.0, 1.0 },
    });
}

pub fn inverseTranslation(translate: *const [3]f32) Matrix4 {
    return Matrix4.init(&.{
        .{ 1.0, 0.0, 0.0, -translate[0] },
        .{ 0.0, 1.0, 0.0, -translate[1] },
        .{ 0.0, 0.0, 1.0, -translate[2] },
        .{ 0.0, 0.0, 0.0, 1.0 },
    });
}
