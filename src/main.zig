const sdl = @import("sdl");

pub fn main() u8 {
    if (!sdl.init(.{})) {
        return 1;
    }
    defer sdl.quit();

    const window = sdl.Window.init("SDL Test", 480, 480, .{}) orelse return 1;
    defer window.deinit();

    return 0;
}
