const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const Window = @This();
const Key = @import("./key.zig").Key;
const Action = @import("./key.zig").Action;
const Mods = @import("./key.zig").Mods;
const modsFromInt = @import("./key.zig").modsFromInt;
const Monitor = c.GLFWmonitor;

handle: *c.GLFWwindow,

pub const WindowHints = struct {
    context_version_major: c_int = 1,
    context_version_minor: c_int = 0,
};

fn from(handle: ?*c.GLFWwindow) ?Window {
    if (handle) |h| {
        return .{ .handle = h };
    }
    return null;
}

fn unwrap(self: ?Window) ?*c.GLFWwindow {
    if (self) |s| {
        return s.handle;
    }
    return null;
}

pub fn create(width: usize, height: usize, title: [:0]const u8, monitor: ?*Monitor, share: ?Window, hints: WindowHints) ?Window {
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, hints.context_version_major);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, hints.context_version_minor);

    const handle = c.glfwCreateWindow(@intCast(width), @intCast(height), title, monitor, unwrap(share));
    return from(handle);
}

pub fn destroy(self: Window) void {
    return c.glfwDestroyWindow(self.handle);
}

pub fn makeContextCurrent(self: Window) void {
    return c.glfwMakeContextCurrent(self.handle);
}

pub fn shouldClose(self: Window) bool {
    return c.glfwWindowShouldClose(self.handle) == c.GLFW_TRUE;
}

pub fn setShouldClose(self: Window, value: bool) void {
    return c.glfwSetWindowShouldClose(self.handle, if (value) c.GLFW_TRUE else c.GLFW_FALSE);
}

pub fn setKeyCallback(self: Window, comptime callback: ?fn (window: Window, key: Key, scancode: c_int, action: Action, mods: Mods) void) void {
    if (callback) |cb| {
        const Wrapper = struct {
            pub fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
                return cb(from(window).?, @enumFromInt(key), scancode, @enumFromInt(action), modsFromInt(mods));
            }
        };
        _ = c.glfwSetKeyCallback(self.handle, Wrapper.keyCallback);
    } else {
        _ = c.glfwSetKeyCallback(self.handle, null);
    }
}

pub fn getKey(self: Window, key: Key) Action {
    return @enumFromInt(c.glfwGetKey(self.handle, @intFromEnum(key)));
}

pub fn getFrameBufferSize(self: Window) struct { usize, usize } {
    var width: c_int = 0;
    var height: c_int = 0;
    c.glfwGetFramebufferSize(self.handle, &width, &height);
    return .{ @intCast(width), @intCast(height) };
}

pub fn swapBuffers(self: Window) void {
    return c.glfwSwapBuffers(self.handle);
}

pub fn setUserPointer(self: Window, ptr: ?*anyopaque) void {
    c.glfwSetWindowUserPointer(self.handle, ptr);
}

pub fn getUserPointer(self: Window, comptime P: type) P {
    return @ptrCast(@alignCast(c.glfwGetWindowUserPointer(self.handle)));
}

pub const InputModeEnum = enum(c_int) {
    cursor = c.GLFW_CURSOR,
    sticky_keys = c.GLFW_STICKY_KEYS,
    sticky_mouse_buttons = c.GLFW_STICKY_MOUSE_BUTTONS,
    lock_key_mods = c.GLFW_LOCK_KEY_MODS,
    raw_mouse_motion = c.GLFW_RAW_MOUSE_MOTION,
};

pub const InputMode = union(InputModeEnum) {
    cursor: enum(c_int) {
        normal = c.GLFW_CURSOR_NORMAL,
        hidden = c.GLFW_CURSOR_HIDDEN,
        disabled = c.GLFW_CURSOR_DISABLED,
    },
    sticky_keys: bool,
    sticky_mouse_buttons: bool,
    lock_key_mods: bool,
    raw_mouse_motion: bool,
};

pub fn setInputMode(self: Window, mode: InputMode) void {
    const value = switch (mode) {
        .cursor => |v| @intFromEnum(v),
        .sticky_keys, .sticky_mouse_buttons, .lock_key_mods, .raw_mouse_motion => |v| if (v) c.GLFW_TRUE else c.GLFW_FALSE,
    };
    c.glfwSetInputMode(self.handle, @intFromEnum(mode), value);
}

pub fn getCursorPos(self: Window) [2]f64 {
    var cursor_pos: [2]f64 = undefined;
    c.glfwGetCursorPos(self.handle, &cursor_pos[0], &cursor_pos[1]);
    return cursor_pos;
}

pub fn setCursorPos(self: Window, x: f64, y: f64) void {
    c.glfwSetCursorPos(self.handle, x, y);
}
