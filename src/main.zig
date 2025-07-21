//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

// quick reference
const _ = .{
    main,
    scop,
    keyCallback,
    movement,

    Arguments,
    ScopShader,
    Transform,
    Scopject,
    ScopImageThing,
    ScopData,

    smoothstep,
    resetDeltaTime,
    getResetDeltaTime,
    resetCursorPos,
    getResetDeltaCursor,
    uploadImgFromPath,
    uploadImg,
};

// imports
const std = @import("std");
const lib = @import("scop_lib");
const zgl = @import("zgl");
const glfw = @import("glfw");
const zigimg = @import("zigimg");

// imported types
const Matrix4 = @import("./Matrix4.zig");
const Versor = @import("./Quaternion.zig").Versor;

// settings
const title = "scop";
const initial_width = 640 * 2;
const initial_height = 480 * 2;
const walk_speed = 1.5;
const rotate_speed = 0.002;
const object_rotate_speed = 0.3;
const object_move_speed = 2;
const bg_color = .{ 0.2, 0.2, 0.25 };
const fov = 70.0;
const near_plane = 0.1;
const far_plane = 100.0;

const vertex_shader = @embedFile("./default_vertex_shader.glsl");
const fragment_shader = @embedFile("./default_fragment_shader.glsl");

// utility functions
fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const xx = std.math.clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return xx * xx * (3.0 - 2.0 * xx);
}

fn resetDeltaTime() void {
    glfw.setTime(0);
}

fn getResetDeltaTime() f64 {
    const delta_time = glfw.getTime();
    resetDeltaTime();
    return delta_time;
}

const cursor_reset_pos_pct = .{ 0.5, 0.5 };

fn resetCursorPos(window: glfw.Window) [2]f64 {
    const width, const height = window.getFrameBufferSize();
    const width_f: f64 = @floatFromInt(width);
    const height_f: f64 = @floatFromInt(height);
    const reset_pos = .{ width_f * cursor_reset_pos_pct[0], height_f * cursor_reset_pos_pct[1] };
    window.setCursorPos(reset_pos[0], reset_pos[1]);
    return reset_pos;
}

fn getResetDeltaCursor(window: glfw.Window) [2]f64 {
    const cursor_pos = window.getCursorPos();
    const reset_pos = resetCursorPos(window);
    return .{ cursor_pos[0] - reset_pos[0], cursor_pos[1] - reset_pos[1] };
}

fn uploadImgFromPath(path: []const u8, allocator: std.mem.Allocator) !zgl.Texture {
    var image = zigimg.Image.fromFilePath(allocator, path) catch return error.ImageLoadError;
    defer image.deinit();
    return try uploadImg(&image);
}

fn uploadImg(img: *const zigimg.Image) !zgl.Texture {
    const pixel_format: zgl.PixelFormat, const pixel_type: zgl.PixelType = switch (img.pixelFormat()) {
        .invalid => unreachable,
        .grayscale8 => .{ .depth_component, .unsigned_byte },
        .grayscale16 => .{ .depth_component, .unsigned_short },
        .grayscale8Alpha => .{ .depth_stencil, .unsigned_byte },
        .grayscale16Alpha => .{ .depth_stencil, .unsigned_short },
        .rgb24 => .{ .rgb, .unsigned_byte },
        .rgba32 => .{ .rgba, .unsigned_byte },
        .bgr24 => .{ .bgr, .unsigned_byte },
        .bgra32 => .{ .bgra, .unsigned_byte },
        .float32 => .{ .rgba, .float },
        else => return error.UnsupportedPixelFormat,
    };
    const texture = zgl.genTexture();
    errdefer texture.delete();
    zgl.bindTexture(texture, .@"2d");
    zgl.texParameter(.@"2d", .wrap_s, .repeat);
    zgl.texParameter(.@"2d", .wrap_t, .repeat);
    zgl.texParameter(.@"2d", .min_filter, .linear);
    zgl.texParameter(.@"2d", .mag_filter, .linear);
    zgl.textureImage2D(.@"2d", 0, .rgb, img.width, img.height, pixel_format, pixel_type, img.rawBytes().ptr);
    zgl.generateMipmap(.@"2d");
    return texture;
}

// local types
const Arguments = struct {
    obj_path: []const u8,
    img_path: []const u8,

    pub fn init(args: *std.process.ArgIterator) !Arguments {
        _ = args.skip(); // The first argument is the program name
        const obj_path = args.next() orelse return error.TooFewArgs;
        const img_path = args.next() orelse return error.TooFewArgs;
        if (args.skip()) return error.TooManyArgs;

        return Arguments{
            .obj_path = obj_path,
            .img_path = img_path,
        };
    }
};

const ScopShader = struct {
    program: zgl.Program,

    uniforms: Uniforms,
    attribs: Attribs,

    const Uniforms = struct {
        mvp: ?u32,
        model_to_world: ?u32,
        texture: ?u32,
        image_up: ?u32,
        image_right: ?u32,
        image_origin: ?u32,
        t: ?u32,
    };
    const Attribs = struct {
        vpos: ?u32,
    };

    fn compile() !zgl.Program {
        const vertex = zgl.createShader(.vertex);
        defer vertex.delete();

        zgl.shaderSource(vertex, 1, &.{vertex_shader});
        vertex.compile();
        if (zgl.getShader(vertex, .compile_status) == zgl.binding.FALSE) {
            // const info_log_length = zgl.getShader(vertex, .info_log_length);
            const log = zgl.getShaderInfoLog(vertex, std.heap.page_allocator) catch unreachable;
            defer std.heap.page_allocator.free(log);
            std.log.err("Error compiling vertex shader: {s}", .{log});
            return error.VertexShaderError;
        }

        const fragment = zgl.createShader(.fragment);
        defer fragment.delete();

        zgl.shaderSource(fragment, 1, &.{fragment_shader});
        fragment.compile();
        if (zgl.getShader(fragment, .compile_status) == zgl.binding.FALSE) {
            // const info_log_length = zgl.getShader(fragment, .info_log_length);
            const log = zgl.getShaderInfoLog(fragment, std.heap.page_allocator) catch unreachable;
            defer std.heap.page_allocator.free(log);
            std.log.err("Error compiling fragment shader: {s}", .{log});
            return error.FragmentShaderError;
        }

        const program = zgl.createProgram();
        errdefer program.delete();
        zgl.attachShader(program, vertex);
        zgl.attachShader(program, fragment);
        zgl.linkProgram(program);

        if (zgl.getProgram(program, .link_status) == zgl.binding.FALSE) {
            // const info_log_length = zgl.getProgram(program, .info_log_length);
            const log = zgl.getProgramInfoLog(program, std.heap.page_allocator) catch unreachable;
            defer std.heap.page_allocator.free(log);
            std.log.err("Error compiling shader program: {s}", .{log});
            return error.ShaderProgramError;
        }

        return program;
    }

    pub fn init() !ScopShader {
        const program = try compile();
        errdefer program.delete();

        return ScopShader{
            .program = program,
            .uniforms = .{
                .mvp = zgl.getUniformLocation(program, "MVP"),
                .model_to_world = zgl.getUniformLocation(program, "ModelToWorld"),
                .texture = zgl.getUniformLocation(program, "myTextureSampler"),
                .image_up = zgl.getUniformLocation(program, "image_up"),
                .image_right = zgl.getUniformLocation(program, "image_right"),
                .image_origin = zgl.getUniformLocation(program, "image_origin"),
                .t = zgl.getUniformLocation(program, "t"),
            },

            .attribs = .{
                .vpos = zgl.getAttribLocation(program, "vPos"),
            },
        };
    }

    pub fn use(self: ScopShader) void {
        self.program.use();
    }

    pub fn deinit(self: ScopShader) void {
        self.program.delete();
    }
};

const Transform = struct {
    position: [3]f32 = .{ 0, 0, 0 },
    orientation: Versor = Versor.fromYawPitchRoll(0, 0, 0),

    pub fn asMatrix(self: Transform) Matrix4 {
        return Matrix4.chain(&.{
            &self.orientation.asRotationMatrix(),
            &Matrix4.translation(&self.position),
        });
    }

    pub fn inverseAsMatrix(self: Transform) Matrix4 {
        return Matrix4.chain(&.{
            &Matrix4.inverseTranslation(&self.position),
            &self.orientation.inverse().asRotationMatrix(),
        });
    }

    pub fn rotateLocal(self: *Transform, rotation: Versor) void {
        self.orientation = self.orientation.multiply(rotation);
    }

    pub fn rotateGlobal(self: *Transform, rotation: Versor) void {
        self.orientation = rotation.multiply(self.orientation);
    }

    pub fn translateLocal(self: *Transform, x: f32, y: f32, z: f32) void {
        const right = self.orientation.rotateVector(&.{ 1, 0, 0 });
        const up = self.orientation.rotateVector(&.{ 0, 1, 0 });
        const forward = self.orientation.rotateVector(&.{ 0, 0, -1 });

        self.position[0] += right[0] * x + up[0] * y + forward[0] * z;
        self.position[1] += right[1] * x + up[1] * y + forward[1] * z;
        self.position[2] += right[2] * x + up[2] * y + forward[2] * z;
    }

    pub fn translateGlobal(self: *Transform, x: f32, y: f32, z: f32) void {
        self.position[0] += x;
        self.position[1] += y;
        self.position[2] += z;
    }
};

const Scopject = struct {
    transform: Transform,

    vertex_buffer: zgl.Buffer,
    face_buffer: zgl.Buffer,
    vertex_array: zgl.VertexArray,

    vertex_count: usize,
    triangle_count: usize,

    pub const RecenterStrategy = enum {
        none,
        bounding_box,
        surface_area,
    };

    fn loadWavefrontFromFile(path: []const u8, allocator: std.mem.Allocator, recenter: RecenterStrategy) !lib.wavefront.WavefrontOpengl {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        var buffered_reader = std.io.bufferedReader(file.reader());
        const mesh = try lib.wavefront.WavefrontOpengl.parse(buffered_reader.reader(), allocator);
        recenter: switch (recenter) {
            .none => {},
            .bounding_box => {
                if (mesh.vertices.len == 0) break :recenter;

                var x_least = mesh.vertices[0][0];
                var x_most = mesh.vertices[0][0];
                var y_least = mesh.vertices[0][1];
                var y_most = mesh.vertices[0][1];
                var z_least = mesh.vertices[0][2];
                var z_most = mesh.vertices[0][2];

                for (mesh.vertices) |vertex| {
                    if (vertex[0] < x_least) x_least = vertex[0];
                    if (vertex[0] > x_most) x_most = vertex[0];
                    if (vertex[1] < y_least) y_least = vertex[1];
                    if (vertex[1] > y_most) y_most = vertex[1];
                    if (vertex[2] < z_least) z_least = vertex[2];
                    if (vertex[2] > z_most) z_most = vertex[2];
                }

                const x_center = (x_least + x_most) / 2;
                const y_center = (y_least + y_most) / 2;
                const z_center = (z_least + z_most) / 2;

                for (mesh.vertices) |*vertex| {
                    vertex[0] -= x_center;
                    vertex[1] -= y_center;
                    vertex[2] -= z_center;
                }
            },
            .surface_area => {
                if (mesh.vertex_indices.len == 0) break :recenter;

                var total_double_weight: f32 = 0;
                var x_center: f32 = 0;
                var y_center: f32 = 0;
                var z_center: f32 = 0;

                for (0..mesh.vertex_indices.len / 3) |vi| {
                    const v0 = mesh.vertices[mesh.vertex_indices[vi + 0]];
                    const v1 = mesh.vertices[mesh.vertex_indices[vi + 1]];
                    const v2 = mesh.vertices[mesh.vertex_indices[vi + 2]];

                    const v_center = .{
                        (v0[0] + v1[0] + v2[0]) / 3.0,
                        (v0[1] + v1[1] + v2[1]) / 3.0,
                        (v0[2] + v1[2] + v2[2]) / 3.0,
                    };

                    const d1 = .{ v1[0] - v0[0], v1[1] - v0[1], v1[2] - v0[2] };
                    const d2 = .{ v2[0] - v0[0], v2[1] - v0[1], v2[2] - v0[2] };

                    const x = d1[1] * d2[2] - d2[1] * d1[2];
                    const y = d1[2] * d2[0] - d2[2] * d1[0];
                    const z = d1[0] * d2[1] - d2[0] * d1[1];

                    const double_weight = std.math.sqrt(x * x + y * y + z * z);

                    const new_total_double_weight = total_double_weight + double_weight;

                    const old_part_fraction = total_double_weight / new_total_double_weight;
                    const new_part_fraction = double_weight / new_total_double_weight;

                    total_double_weight = new_total_double_weight;

                    x_center = x_center * old_part_fraction + v_center[0] * new_part_fraction;
                    y_center = y_center * old_part_fraction + v_center[1] * new_part_fraction;
                    z_center = z_center * old_part_fraction + v_center[2] * new_part_fraction;
                }

                for (mesh.vertices) |*vertex| {
                    vertex[0] -= x_center;
                    vertex[1] -= y_center;
                    vertex[2] -= z_center;
                }
            },
        }
        return mesh;
    }

    pub fn initFromPath(path: []const u8, allocator: std.mem.Allocator, recenter: RecenterStrategy) !Scopject {
        const mesh = loadWavefrontFromFile(path, allocator, recenter) catch return error.MeshLoadError;
        defer mesh.deinit(allocator);
        return init(mesh);
    }

    pub fn init(mesh: lib.wavefront.WavefrontOpengl) Scopject {
        const vertex_buffer = zgl.genBuffer();
        errdefer vertex_buffer.delete();
        zgl.bindBuffer(vertex_buffer, .array_buffer);
        zgl.bufferData(.array_buffer, lib.wavefront.WavefrontOpengl.Vertex, mesh.vertices, .static_draw);

        const face_buffer = zgl.genBuffer();
        errdefer face_buffer.delete();
        zgl.bindBuffer(face_buffer, .element_array_buffer);
        zgl.bufferData(.element_array_buffer, lib.wavefront.WavefrontOpengl.Index, mesh.vertex_indices, .static_draw);

        const vertex_array = zgl.genVertexArray();
        errdefer vertex_array.delete();

        return Scopject{
            .transform = .{},
            .vertex_buffer = vertex_buffer,
            .face_buffer = face_buffer,
            .vertex_array = vertex_array,

            .vertex_count = mesh.vertices.len,
            .triangle_count = mesh.vertex_indices.len,
        };
    }

    pub fn deinit(self: Scopject) void {
        self.vertex_array.delete();
        self.face_buffer.delete();
        self.vertex_buffer.delete();
    }

    pub fn load(self: Scopject, shader: *const ScopShader) void {
        self.vertex_array.bind();
        zgl.bindBuffer(self.face_buffer, .element_array_buffer);
        if (shader.attribs.vpos) |vpos| {
            zgl.bindBuffer(self.vertex_buffer, .array_buffer);
            zgl.vertexAttribPointer(vpos, 3, .float, false, @sizeOf(lib.wavefront.WavefrontOpengl.Vertex), 0);
            zgl.enableVertexAttribArray(vpos);
        }
        switch (@import("builtin").mode) {
            .ReleaseFast, .ReleaseSmall => {},
            .Debug, .ReleaseSafe => {
                zgl.bindVertexArray(.invalid); // NOTE: Unbind curent vertex array as to not accidentally overwrite settings
            },
        }
    }

    pub fn draw(self: Scopject, data: *ScopData, shader: *const ScopShader) void {
        // zgl.polygonMode(.front, .fill);
        // zgl.polygonMode(.back, .line);
        const world_to_screen = data.worldToScreenMatrix();
        const model_to_world = self.transform.asMatrix();
        // std.debug.print("transform: {any}\n", .{self.transform});
        // const model_to_world = Matrix4.chain(&.{
        //     // self.transform.position,
        //     &Matrix4.translation(&.{0.0, 0.0, -3.0}),
        //     &self.transform.orientation.asRotationMatrix(),
        // });
        const mvp = Matrix4.chain(&.{ &model_to_world, &world_to_screen });

        zgl.uniformMatrix4fv(shader.uniforms.mvp, true, &.{mvp.data});
        zgl.uniformMatrix4fv(shader.uniforms.model_to_world, true, &.{model_to_world.data});

        self.vertex_array.bind();
        zgl.drawElements(.triangles, self.triangle_count, .unsigned_int, 0);
        switch (@import("builtin").mode) {
            .ReleaseFast, .ReleaseSmall => {},
            .Debug, .ReleaseSafe => {
                zgl.bindVertexArray(.invalid); // NOTE: Unbind curent vertex array as to not accidentally overwrite settings
            },
        }
    }
};

const ScopImageThing = struct {
    start: Transform = .{},
    current: Transform = .{},
    end: Transform = .{},
    transform_t: f32,
    fade_target_t: f32,
    fade_t: f32,

    pub fn update(self: *ScopImageThing, delta_time: f64, shader: *const ScopShader) void {
        if (self.fade_t < self.fade_target_t) {
            self.fade_t = @floatCast(std.math.clamp(self.fade_t + delta_time, 0.0, 1.0));
        } else {
            self.fade_t = @floatCast(std.math.clamp(self.fade_t - delta_time, 0.0, 1.0));
        }
        zgl.uniform1f(shader.uniforms.t, self.fade_t);

        if (self.transform_t < 1.0) {
            self.transform_t = @floatCast(std.math.clamp(self.transform_t + delta_time, 0.0, 1.0));
            const smooth_t = smoothstep(0.0, 1.0, self.transform_t);
            self.current.orientation = self.start.orientation.slerp(self.end.orientation, smooth_t);
            self.current.position = .{
                self.start.position[0] * (1.0 - smooth_t) + self.end.position[0] * smooth_t,
                self.start.position[1] * (1.0 - smooth_t) + self.end.position[1] * smooth_t,
                self.start.position[2] * (1.0 - smooth_t) + self.end.position[2] * smooth_t,
            };
            const up = self.current.orientation.rotateVector(&.{ 0, 1, 0 });
            const right = self.current.orientation.rotateVector(&.{ 1, 0, 0 });
            zgl.uniform3f(shader.uniforms.image_up, up[0], up[1], up[2]);
            zgl.uniform3f(shader.uniforms.image_right, right[0], right[1], right[2]);
            zgl.uniform3f(shader.uniforms.image_origin, self.current.position[0], self.current.position[1], self.current.position[2]);
        }
    }
};

const ScopData = struct {
    paused: bool,

    shader: ScopShader,
    object: Scopject,
    window: glfw.Window,

    culling: bool,

    camera: Transform,
    image: ScopImageThing,

    pub fn worldToScreenMatrix(self: *ScopData) Matrix4 {
        const world_to_camera = self.camera.inverseAsMatrix();
        const width, const height = self.window.getFrameBufferSize();
        const width_f: f32 = @floatFromInt(width);
        const height_f: f32 = @floatFromInt(height);
        const perspective = Matrix4.perspective(fov, width_f / height_f, near_plane, far_plane);
        const camera_to_screen = perspective;
        return Matrix4.chain(&.{ &world_to_camera, &camera_to_screen });
    }
};

// functions
pub fn main() !u8 {
    var argIterator = std.process.args();
    defer argIterator.deinit();
    const args = Arguments.init(&argIterator) catch {
        std.log.err("usage: scop <obj file>", .{});
        return 1;
    };

    const S = struct {
        pub fn glfwErrorCallback(err: glfw.Error, description: [:0]const u8) void {
            std.debug.panic("GLFW Error [{}]: {s}", .{ err, description });
        }

        pub fn getProcAddress(_: void, proc_name: [:0]const u8) *const anyopaque {
            return @ptrCast(@alignCast(glfw.getProcAddress(proc_name)));
        }
    };

    glfw.setErrorCallback(S.glfwErrorCallback);
    if (!glfw.init()) {
        std.log.err("Failed to initialize GLFW", .{});
        return 1;
    }
    defer glfw.terminate();

    var window = glfw.Window.create(initial_width, initial_height, title, null, null, .{}) orelse {
        std.log.err("Failed to create window", .{});
        return 1;
    };
    defer window.destroy();
    window.makeContextCurrent();

    try zgl.loadExtensions(void{}, S.getProcAddress);

    try scop(args, window);
    return 0;
}

fn scop(args: Arguments, window: glfw.Window) !void {
    zgl.enable(.depth_test);
    zgl.cullFace(.back);
    zgl.frontFace(.ccw);
    zgl.clearColor(bg_color[0], bg_color[1], bg_color[2], 1.0);

    window.setInputMode(.{ .cursor = .disabled });
    if (glfw.rawMouseMotionSupported()) {
        window.setInputMode(.{ .raw_mouse_motion = true });
    }

    const shader = try ScopShader.init();
    defer shader.deinit();

    const object = try Scopject.initFromPath(args.obj_path, std.heap.smp_allocator, .bounding_box);
    defer object.deinit();

    var data = ScopData{
        .paused = false,
        .shader = shader,
        .object = object,
        .window = window,
        .culling = false,
        .camera = .{},
        .image = .{
            .transform_t = 0,
            .fade_target_t = 0,
            .fade_t = 0,
        },
    };
    data.shader.use();
    data.object.transform.position = .{ 0, 0, -3 };
    if (data.culling) zgl.enable(.cull_face);
    window.setUserPointer(&data);
    window.setKeyCallback(keyCallback);

    data.object.load(&data.shader);

    const texture_index = 0;
    zgl.activeTexture(zgl.TextureUnit.unit(texture_index));
    const texture = try uploadImgFromPath(args.img_path, std.heap.smp_allocator);
    defer texture.delete();

    zgl.uniform1i(data.shader.uniforms.texture, texture_index);

    resetDeltaTime();
    _ = resetCursorPos(window);
    var frame: usize = 0;
    while (!window.shouldClose()) : (frame += 1) { // NOTE: Theoretically `frame` could overflow
        const delta_time = getResetDeltaTime();
        if (frame == 1) _ = resetCursorPos(window); // NOTE: This is a workaround to the cursor suddenly getting moved back on the second frame to where it was before the first frame
        const delta_cursor: [2]f64 = if (data.paused) .{ 0, 0 } else getResetDeltaCursor(window);

        if (!data.paused) {
            movement(window, &data, &delta_cursor, delta_time);

            data.object.transform.rotateGlobal(Versor.fromYawPitchRoll(@floatCast(delta_time * object_rotate_speed), 0, 0));
        }

        data.image.update(delta_time, &data.shader);

        const width, const height = window.getFrameBufferSize();
        zgl.viewport(0, 0, width, height);
        zgl.clear(.{ .color = true, .depth = true, .stencil = false });

        data.object.draw(&data, &shader);

        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn keyCallback(window: glfw.Window, key: glfw.Key, scancode: c_int, action: glfw.Action, mods: glfw.Mods) void {
    // _ = scancode;
    _ = mods;

    if (action == .press) {
        const data = window.getUserPointer(*ScopData);
        if (key == .escape) {
            data.paused = !data.paused;
            if (data.paused) {
                window.setInputMode(.{ .cursor = .normal });
            } else {
                _ = resetCursorPos(window);
                window.setInputMode(.{ .cursor = .disabled });
            }
        }
        const name = glfw.getKeyName(key, scancode);
        if (key == .q or (name != null and std.mem.eql(u8, name.?, "q"))) {
            window.setShouldClose(true);
        }

        if (data.paused) return; // Don't process other inputs when paused
        if (key == .c or (name != null and std.mem.eql(u8, name.?, "c"))) {
            data.culling = !data.culling;
            if (data.culling) {
                zgl.enable(.cull_face);
            } else {
                zgl.disable(.cull_face);
            }
        }

        if (key == .t or (name != null and std.mem.eql(u8, name.?, "t"))) {
            data.image.start = data.image.current;
            data.image.end = data.camera;
            data.image.end.orientation = data.image.end.orientation;
            data.image.transform_t = 0.0;
        }

        if (key == .f or (name != null and std.mem.eql(u8, name.?, "f"))) {
            data.image.fade_target_t = 1.0 - data.image.fade_target_t;
        }
    }
}

fn movement(window: glfw.Window, data: *ScopData, delta_cursor: *const [2]f64, delta_time: f64) void {
    if (delta_cursor[0] != 0) {
        data.camera.rotateGlobal(Versor.fromYawPitchRoll(@floatCast(delta_cursor[0] * -rotate_speed), 0, 0));
    }
    if (delta_cursor[1] != 0) {
        data.camera.rotateLocal(Versor.fromYawPitchRoll(0, @floatCast(delta_cursor[1] * -rotate_speed), 0));
    }
    var forward: f32 = 0;
    if (window.getKey(.w) == .press) {
        forward += @floatCast(walk_speed * delta_time);
    }
    if (window.getKey(.s) == .press) {
        forward -= @floatCast(walk_speed * delta_time);
    }
    if (forward != 0) {
        var forward_v = data.camera.orientation.rotateVector(&.{ 0, 0, -1 });
        forward_v[1] = 0; // No y movement
        const mag2 = forward_v[0] * forward_v[0] + forward_v[1] * forward_v[1] + forward_v[2] * forward_v[2];
        const mag = if (mag2 == 0) 1 else std.math.sqrt(mag2);
        forward_v[0] /= mag;
        forward_v[1] /= mag;
        forward_v[2] /= mag;
        data.camera.translateGlobal(forward_v[0] * forward, forward_v[1] * forward, forward_v[2] * forward);
    }
    var right: f32 = 0;
    if (window.getKey(.a) == .press) {
        right -= @floatCast(walk_speed * delta_time);
    }
    if (window.getKey(.d) == .press) {
        right += @floatCast(walk_speed * delta_time);
    }
    if (right != 0) {
        var right_v = data.camera.orientation.rotateVector(&.{ 1, 0, 0 });
        right_v[1] = 0; // No y movement
        const mag2 = right_v[0] * right_v[0] + right_v[1] * right_v[1] + right_v[2] * right_v[2];
        const mag = if (mag2 == 0) 1 else std.math.sqrt(mag2);
        right_v[0] /= mag;
        right_v[1] /= mag;
        right_v[2] /= mag;
        data.camera.translateGlobal(right_v[0] * right, right_v[1] * right, right_v[2] * right);
    }
    if (window.getKey(.space) == .press) {
        data.camera.translateGlobal(0, @floatCast(walk_speed * delta_time), 0);
    }
    if (window.getKey(.left_shift) == .press or window.getKey(.right_shift) == .press) {
        data.camera.translateGlobal(0, @floatCast(-walk_speed * delta_time), 0);
    }

    if (window.getKey(.up) == .press) {
        data.object.transform.translateGlobal(0, 0, @floatCast(-object_move_speed * delta_time));
    }
    if (window.getKey(.down) == .press) {
        data.object.transform.translateGlobal(0, 0, @floatCast(object_move_speed * delta_time));
    }
    if (window.getKey(.left) == .press) {
        data.object.transform.translateGlobal(@floatCast(-object_move_speed * delta_time), 0, 0);
    }
    if (window.getKey(.right) == .press) {
        data.object.transform.translateGlobal(@floatCast(object_move_speed * delta_time), 0, 0);
    }
    if (window.getKey(.page_up) == .press) {
        data.object.transform.translateGlobal(0, @floatCast(object_move_speed * delta_time), 0);
    }
    if (window.getKey(.page_down) == .press) {
        data.object.transform.translateGlobal(0, @floatCast(-object_move_speed * delta_time), 0);
    }
}

// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
