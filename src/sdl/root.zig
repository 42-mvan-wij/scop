const c = @import("./c.zig");
const utils = @import("./utils.zig");

pub const InitFlags = utils.Mask(enum(c.SDL_InitFlags) {
    audio    = c.SDL_INIT_AUDIO,
    camera   = c.SDL_INIT_CAMERA,
    events   = c.SDL_INIT_EVENTS,
    gamepad  = c.SDL_INIT_GAMEPAD,
    haptic   = c.SDL_INIT_HAPTIC,
    joystick = c.SDL_INIT_JOYSTICK,
    sensor   = c.SDL_INIT_SENSOR,
    video    = c.SDL_INIT_VIDEO,
});

pub fn init(flags: InitFlags.Flags) bool {
    return c.SDL_Init(InitFlags.convert(flags));
}

pub fn quit() void {
    c.SDL_Quit();
}

pub const Window = @import("./Window.zig");
