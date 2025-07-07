const std = @import("std");
const Quaternion = @This();
const Matrix4 = @import("./Matrix4.zig");

h: f32,
i: f32,
j: f32,
k: f32,

pub fn fromYawPitchRoll(yaw: f32, pitch: f32, roll: f32) Quaternion {
    const yaw_q = fromAxisAngle(0.0, 1.0, 0.0, yaw);
    const pitch_q = fromAxisAngle(1.0, 0.0, 0.0, pitch);
    const roll_q = fromAxisAngle(0.0, 0.0, -1.0, roll);

    return yaw_q.multiply(pitch_q).multiply(roll_q);
}

pub fn fromAxisAngle(x: f32, y: f32, z: f32, angle: f32) Quaternion {
    std.debug.assert(x * x + y * y + z * z == 1.0);
    const sin_angle = std.math.sin(angle / 2);
    return Quaternion{
        .h = std.math.cos(angle / 2),
        .i = sin_angle * x,
        .j = sin_angle * y,
        .k = sin_angle * z,
    };
}

pub fn toAxisAngle(self: Quaternion) struct { [3]f32, f32 } {
    const phi = std.math.acos(self.h);
    const sin_phi = std.math.sin(phi);
    return .{ .{ self.i / sin_phi, self.j / sin_phi, self.k / sin_phi }, phi * 2 };
}

pub fn normalized(self: Quaternion) Quaternion {
    return self.scaled(1.0 / std.math.sqrt(self.mag2()));
}

pub fn scaled(self: Quaternion, scale: f32) Quaternion {
    return Quaternion{
        .h = self.h * scale,
        .i = self.i * scale,
        .j = self.j * scale,
        .k = self.k * scale,
    };
}

pub fn conjugate(self: Quaternion) Quaternion {
    return Quaternion{
        .h = self.h,
        .i = -self.i,
        .j = -self.j,
        .k = -self.k,
    };
}

pub fn inverse(self: Quaternion) Quaternion {
    return self.conjugate().scaled(1.0 / self.mag2());
}

pub fn multiply(left: Quaternion, right: Quaternion) Quaternion {
    return Quaternion{
        .h = left.h * right.h - left.i * right.i - left.j * right.j - left.k * right.k,
        .i = left.h * right.i + left.i * right.h + left.j * right.k - left.k * right.j,
        .j = left.h * right.j - left.i * right.k + left.j * right.h + left.k * right.i,
        .k = left.h * right.k + left.i * right.j - left.j * right.i + left.k * right.h,
    };
}

pub fn dot(a: Quaternion, b: Quaternion) f32 {
    return a.h * b.h + a.i * b.i + a.j * b.j + a.k * b.k;
}

/// https://en.wikipedia.org/wiki/Quaternion#Exponential,_logarithm,_and_power_functions
pub fn power(self: Quaternion, t: f32) Quaternion {
    const mag = std.math.sqrt(self.mag2());
    const phi = std.math.acos(self.h / mag);
    const sin_phi = std.math.sin(phi);
    const sin_t_phi = std.math.sin(t * phi);
    const v_ratio = sin_t_phi / (sin_phi * mag);
    const mag_scale = std.math.pow(f32, self.mag2(), t / 2.0);
    return Quaternion{
        .h = mag_scale * std.math.cos(t * phi),
        .i = mag_scale * self.i * v_ratio,
        .j = mag_scale * self.j * v_ratio,
        .k = mag_scale * self.k * v_ratio,
    };
}

pub fn mag2(self: Quaternion) f32 {
    return self.h * self.h + self.i * self.i + self.j * self.j + self.k * self.k;
}

pub fn eq(self: Quaternion, other: Quaternion) bool {
    return self.h == other.h and self.i == other.i and self.j == other.j and self.k == other.k;
}

pub fn asVersor(self: Quaternion) !Versor {
    return try Versor.fromQuaternion(self);
}

pub fn fromVersor(versor: Versor) Quaternion {
    return versor.asQuaternion();
}

pub const Versor = struct {
    quaternion: Quaternion,

    pub fn fromQuaternion(quaternion: Quaternion) !Versor {
        if (!std.math.approxEqAbs(f32, quaternion.mag2(), 1.0, std.math.floatEps(f32) * 10)) {
            std.debug.print("mag: {d:.5}\n", .{std.math.sqrt(quaternion.mag2())});
            return error.NotUnitQuaternion;
        }
        if (!std.math.approxEqAbs(f32, quaternion.mag2(), 1.0, std.math.floatEps(f32) * 3)) {
            return Versor{
                .quaternion = quaternion.scaled(1.0 / std.math.sqrt(quaternion.mag2())),
            };
        }
        return Versor{
            .quaternion = quaternion,
        };
    }

    pub fn asQuaternion(self: Versor) Quaternion {
        return self.quaternion;
    }

    pub fn fromYawPitchRoll(yaw: f32, pitch: f32, roll: f32) Versor {
        return Quaternion.fromYawPitchRoll(yaw, pitch, roll).asVersor() catch unreachable;
    }

    pub fn fromAxisAngle(x: f32, y: f32, z: f32, angle: f32) !Versor {
        return try Quaternion.fromAxisAngle(x, y, z, angle).asVersor();
    }

    pub fn toAxisAngle(self: Versor) struct { [3]f32, f32 } {
        return self.quaternion.toAxisAngle();
    }

    pub fn conjugate(self: Versor) Versor {
        return self.quaternion.conjugate().asVersor() catch unreachable;
    }

    pub fn inverse(self: Versor) Versor {
        return self.conjugate();
    }

    pub fn multiply(left: Versor, right: Versor) Versor {
        return left.quaternion.multiply(right.quaternion).asVersor() catch unreachable;
    }

    pub fn dot(a: Versor, b: Versor) f32 {
        return std.math.clamp(a.quaternion.dot(b.quaternion), -1, 1);
    }

    /// https://en.wikipedia.org/wiki/Quaternion#Exponential,_logarithm,_and_power_functions
    pub fn power(self: Versor, t: f32) Versor {
        const phi = std.math.acos(self.quaternion.h);
        const sin_phi = std.math.sin(phi);
        const sin_t_phi = std.math.sin(t * phi);
        const v_ratio = if (sin_phi == 0) 0 else sin_t_phi / sin_phi;
        return Versor.fromQuaternion(Quaternion{
            .h = std.math.cos(t * phi),
            .i = self.quaternion.i * v_ratio,
            .j = self.quaternion.j * v_ratio,
            .k = self.quaternion.k * v_ratio,
        }) catch unreachable;
    }

    fn slerp_internal(a: Versor, b: Versor, t: f32) Versor {
        const cos_theta = a.dot(b);
        const theta = std.math.acos(cos_theta);
        const sin_theta = std.math.sin(theta);
        if (sin_theta == 0) {
            return a;
        }
        const a_scaled = a.quaternion.scaled(std.math.sin((1 - t) * theta) / sin_theta);
        const b_scaled = b.quaternion.scaled(std.math.sin(t * theta) / sin_theta);
        return Versor.fromQuaternion(Quaternion{
            .h = a_scaled.h + b_scaled.h,
            .i = a_scaled.i + b_scaled.i,
            .j = a_scaled.j + b_scaled.j,
            .k = a_scaled.k + b_scaled.k,
        }) catch {
            std.debug.print("a: {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ a.quaternion.h, a.quaternion.i, a.quaternion.j, a.quaternion.k });
            std.debug.print("b: {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ b.quaternion.h, b.quaternion.i, b.quaternion.j, b.quaternion.k });
            std.debug.print("a_scaled: {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ a_scaled.h, a_scaled.i, a_scaled.j, a_scaled.k });
            std.debug.print("b_scaled: {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ b_scaled.h, b_scaled.i, b_scaled.j, b_scaled.k });
            std.debug.print("cos_theta: {d}; theta: {d}; sin_theta: {d}\n", .{ cos_theta, theta, sin_theta });
            unreachable;
        };
    }

    pub fn slerp(a: Versor, b: Versor, t: f32) Versor {
        if (a.dot(b) < 0) {
            return slerp_internal(a, b.quaternion.scaled(-1).asVersor() catch unreachable, t);
        }
        return slerp_internal(a, b, t);
    }

    pub fn eq(self: Versor, other: Versor) bool {
        return self.quaternion.eq(other.quaternion);
    }

    pub fn asRotationMatrix(self: Versor) Matrix4 {
        const x_versor = Versor.fromQuaternion(Quaternion{ .h = 0, .i = 1, .j = 0, .k = 0 }) catch unreachable;
        const y_versor = Versor.fromQuaternion(Quaternion{ .h = 0, .i = 0, .j = 1, .k = 0 }) catch unreachable;
        const z_versor = Versor.fromQuaternion(Quaternion{ .h = 0, .i = 0, .j = 0, .k = 1 }) catch unreachable;

        const x_mapped = self.multiply(x_versor).multiply(self.inverse());
        const y_mapped = self.multiply(y_versor).multiply(self.inverse());
        const z_mapped = self.multiply(z_versor).multiply(self.inverse());

        return Matrix4.init(&.{
            .{ x_mapped.quaternion.i, y_mapped.quaternion.i, z_mapped.quaternion.i, 0.0 },
            .{ x_mapped.quaternion.j, y_mapped.quaternion.j, z_mapped.quaternion.j, 0.0 },
            .{ x_mapped.quaternion.k, y_mapped.quaternion.k, z_mapped.quaternion.k, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        });
    }

    pub fn rotateVector(self: Versor, v: *const [3]f32) [3]f32 {
        const v_as_quaternion = Quaternion{ .h = 0, .i = v[0], .j = v[1], .k = v[2] };
        const rotated = self.quaternion.multiply(v_as_quaternion).multiply(self.inverse().quaternion);
        return .{ rotated.i, rotated.j, rotated.k };
    }
};
