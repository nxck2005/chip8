const std = @import("std");
const chip8 = @import("chip8");
const rl = @import("raylib");

pub fn main() !void {
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
