const std = @import("std");
const chip8 = @import("chip8");
const rl = @import("raylib");
const CHIP8 = @import("emu.zig");

var cpu: *CHIP8 = undefined;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    cpu = try allocator.create(CHIP8);

    const screenWidth = 640;
    const screenHeight = 320;

    rl.initWindow(screenWidth, screenHeight, "CHIP-8 Emulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();

        rl.clearBackground(rl.Color.black);

        rl.drawText("Hello, world!", 10, 40, 20, rl.Color.white);
        rl.drawFPS(10, 10);

        rl.endDrawing();
    }
}
