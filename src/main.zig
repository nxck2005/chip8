const std = @import("std");
const chip8 = @import("chip8");
const rl = @import("raylib");
const CHIP8 = @import("emu.zig");

const KEY_MAP = [_]rl.KeyboardKey{
    .zero, // 0
    .one, // 1
    .two, // 2
    .three, // 3
    .four, // 4
    .five, // 5
    .six, // 6
    .seven, // 7
    .eight, // 8
    .nine, // 9
    .a, // A
    .b, // B
    .c, // C
    .d, // D
    .e, // E
    .f, // F
};

var cpu: *CHIP8 = undefined;

fn handleInput() void {
    for (0..KEY_MAP.len) |i| {
        if (rl.isKeyDown(KEY_MAP[i])) {
            cpu.keys[i] = 1;
        } else {
            cpu.keys[i] = 0;
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    cpu = try allocator.create(CHIP8);
    cpu.init();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const arglen = args.len;
    if (arglen != 2) {
        std.debug.print("PANIC: ROM load failed; no ROM given\n", .{});
        return;
    }

    const romfile = args[1];
    const rom = try std.fs.cwd().openFile(romfile, .{});
    defer rom.close();

    const size = try rom.getEndPos();

    var read_buf: [2]u8 = undefined;
    var fr = rom.reader(&read_buf);
    const reader = &fr.interface;

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const readbyte = reader.takeByte();
        if (readbyte) |byte| {
            cpu.memory[i + 0x200] = byte;
        } else |err| {
            if (err == error.EndOfStream) {
                std.debug.print("PANIC: seek error while reading\n", .{});
                return;
            } else {
                return;
            }
        }
    }

    const screenWidth = 1280;
    const screenHeight = 640;

    rl.initWindow(screenWidth, screenHeight, "CHIP-8 Emulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // cpu buffer to prep raylib pixel colors
    var pxbuffer: [64 * 32]rl.Color = .{rl.Color.black} ** (64 * 32);

    // gpu texture draw
    const img = rl.genImageColor(64, 32, rl.Color.black);
    const texture = try rl.loadTextureFromImage(img);
    rl.unloadImage(img); // done with the cpu img
    defer rl.unloadTexture(texture);

    while (!rl.windowShouldClose()) {
        cpu.cycle();
        handleInput();
        std.debug.print("{d}\n", .{cpu.pc});
        if (cpu.rdraw) {
            for (0..pxbuffer.len) |idx| {
                if (cpu.graphics[idx] == 1) {
                    pxbuffer[idx] = rl.Color.white;
                } else {
                    pxbuffer[idx] = rl.Color.black;
                }
            }
        }
        rl.updateTexture(texture, pxbuffer[0..]);
        cpu.rdraw = false;
        rl.beginDrawing();

        rl.clearBackground(rl.Color.black);
        rl.drawTexturePro(texture, rl.Rectangle{ .x = 0, .y = 0, .width = 64, .height = 32 }, rl.Rectangle{ .x = 0, .y = 0, .width = screenWidth, .height = screenHeight }, rl.Vector2{ .x = 0, .y = 0 }, 0.0, rl.Color.white);

        rl.drawFPS(10, 10);

        rl.endDrawing();
    }
}
