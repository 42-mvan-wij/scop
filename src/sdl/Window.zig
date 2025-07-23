const Window = @This();

const c = @import("./c.zig");
const utils = @import("./utils.zig");

handle: *c.SDL_Window,

const WindowFlags = utils.Mask(enum(c.SDL_WindowFlags) {
    fullscreen          = c.SDL_WINDOW_FULLSCREEN,
    opengl              = c.SDL_WINDOW_OPENGL,
    occluded            = c.SDL_WINDOW_OCCLUDED,
    hidden              = c.SDL_WINDOW_HIDDEN,
    borderless          = c.SDL_WINDOW_BORDERLESS,
    resizable           = c.SDL_WINDOW_RESIZABLE,
    minimized           = c.SDL_WINDOW_MINIMIZED,
    maximized           = c.SDL_WINDOW_MAXIMIZED,
    mouse_grabbed       = c.SDL_WINDOW_MOUSE_GRABBED,
    input_focus         = c.SDL_WINDOW_INPUT_FOCUS,
    mouse_focus         = c.SDL_WINDOW_MOUSE_FOCUS,
    external            = c.SDL_WINDOW_EXTERNAL,
    modal               = c.SDL_WINDOW_MODAL,
    high_pixel_density  = c.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    mouse_capture       = c.SDL_WINDOW_MOUSE_CAPTURE,
    mouse_relative_mode = c.SDL_WINDOW_MOUSE_RELATIVE_MODE,
    always_on_top       = c.SDL_WINDOW_ALWAYS_ON_TOP,
    utility             = c.SDL_WINDOW_UTILITY,
    tooltip             = c.SDL_WINDOW_TOOLTIP,
    popup_menu          = c.SDL_WINDOW_POPUP_MENU,
    keyboard_grabbed    = c.SDL_WINDOW_KEYBOARD_GRABBED,
    vulkan              = c.SDL_WINDOW_VULKAN,
    metal               = c.SDL_WINDOW_METAL,
    transparent         = c.SDL_WINDOW_TRANSPARENT,
    not_focusable       = c.SDL_WINDOW_NOT_FOCUSABLE,
});

pub fn init(title: [:0]const u8, width: usize, height: usize, flags: WindowFlags.Flags) ?Window {
    const handle = c.SDL_CreateWindow(title, @intCast(width), @intCast(height), WindowFlags.convert(flags)) orelse return null;
    return Window{
        .handle = handle,
    };
}

pub fn deinit(self: Window) void {
    c.SDL_DestroyWindow(self.handle);
}
