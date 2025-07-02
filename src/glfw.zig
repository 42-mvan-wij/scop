const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const std = @import("std");

const key = @import("./glfw/key.zig");

pub const binding = c;
pub const Window = @import("./glfw/Window.zig");
pub const Key = key.Key;
pub const Action = key.Action;
pub const Mods = key.Mods;
pub const getKeyName = key.getKeyName;
pub const Monitor = c.GLFWmonitor;
pub const GlProc = c.GLFWglproc;

pub fn init() bool {
    return c.glfwInit() == c.GLFW_TRUE;
}

pub fn terminate() void {
    return c.glfwTerminate();
}

pub const ErrorCallback = fn (c_int, [*c]const u8) callconv(.c) void;

pub const Error = enum(c_int) {
    no_error = c.GLFW_NO_ERROR,
    not_initialized = c.GLFW_NOT_INITIALIZED,
    no_current_context = c.GLFW_NO_CURRENT_CONTEXT,
    invalid_enum = c.GLFW_INVALID_ENUM,
    invalid_value = c.GLFW_INVALID_VALUE,
    out_of_memory = c.GLFW_OUT_OF_MEMORY,
    api_unavailable = c.GLFW_API_UNAVAILABLE,
    version_unavailable = c.GLFW_VERSION_UNAVAILABLE,
    platform_error = c.GLFW_PLATFORM_ERROR,
    format_unavailable = c.GLFW_FORMAT_UNAVAILABLE,
    no_window_context = c.GLFW_NO_WINDOW_CONTEXT,
    // cursor_unavailable = c.GLFW_CURSOR_UNAVAILABLE,
    // feature_unavailable = c.GLFW_FEATURE_UNAVAILABLE,
    // feature_unimplemented = c.GLFW_FEATURE_UNIMPLEMENTED,
    // platform_unavailable = c.GLFW_PLATFORM_UNAVAILABLE,
    _,
};

pub fn setErrorCallback(comptime callback: fn (Error, [:0]const u8) void) void {
    const Wrapper = struct {
        fn cb(error_code: c_int, description: [*c]const u8) callconv(.c) void {
            callback(@enumFromInt(error_code), std.mem.span(description));
        }
    };
    _ = c.glfwSetErrorCallback(Wrapper.cb);
}

pub fn getProcAddress(procname: [:0]const u8) GlProc {
    return c.glfwGetProcAddress(procname);
}

pub fn pollEvents() void {
    return c.glfwPollEvents();
}

pub fn getTime() f64 {
    return c.glfwGetTime();
}

pub fn setTime(time: f64) void {
    c.glfwSetTime(time);
}

pub fn rawMouseMotionSupported() bool {
    return c.glfwRawMouseMotionSupported() == c.GLFW_TRUE;
}
