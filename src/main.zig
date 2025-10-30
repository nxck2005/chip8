const std = @import("std");
const chip8 = @import("root");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});
const process = std.process;

pub fn init() !void {}

pub fn deinit() void {}

pub fn main() !void {
    c.SDL_SetMainReady();
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != true) {
        std.log.err("panic : SDL init failed: {s}\n", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_Quit();

    // create window
    const window = c.SDL_CreateWindow(
        "CHIP-8 Emulator",
        640,
        320,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.log.err("panic : failed to create window: {s}\n", .{c.SDL_GetError()});
        return;
    };
    defer c.SDL_DestroyWindow(window);

    std.log.info("emulator window running; close to exit\n", .{});

    // boilerplate loop
    var running = true;
    var event: c.SDL_Event = undefined;

    while (running) {
        _ = c.SDL_WaitEvent(&event);
        switch (event.type) {
            c.SDL_EVENT_QUIT => {
                running = false;
            },
            else => {},
        }
    }
}
