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
    cpu.init();

    const screenWidth = 640;
    const screenHeight = 320;

    rl.initWindow(screenWidth, screenHeight, "CHIP-8 Emulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        cpu.cycle();
        rl.beginDrawing();

        rl.clearBackground(rl.Color.black);

        rl.drawFPS(10, 10);

        rl.endDrawing();
    }
}
