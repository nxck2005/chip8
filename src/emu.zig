const std = @import("std");
const cstd = @cImport(@cInclude("stdlib.h"));
const time = @cImport(@cInclude("time.h"));
const c = @import("std").c;

// from hardware reference: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM

opcode: u16,
memory: [4096]u8,
graphics: [64 * 32]u8,
registers: [16]u8,
index: u16,
pc: u16,
delayTimer: u8,
soundTimer: u8,
stack: [16]u16,
sp: u16,
keys: [16]u8,

// CHIP-8 sprite fontset. lives in interpreter memspace
// shamelessly copied from https://multigesture.net/articles/how-to-write-an-emulator-chip-8-interpreter/
// the length turns out to be the height.
const chip8_fontset = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

const Self = @This();

pub fn init(self: *Self) void {
    // seed the rng
    cstd.srand(@intCast(time.time(0)));

    // also from the reference
    self.pc = 0x200;
    self.opcode = 0;
    self.index = 0;
    self.sp = 0;
    self.delayTimer = 0;
    self.soundTimer = 0;

    // zero out bitfields
    for (&self.graphics) |*x| {
        x.* = 0;
    }
    for (&self.memory) |*x| {
        x.* = 0;
    }
    for (&self.stack) |*x| {
        x.* = 0;
    }
    for (&self.registers) |*x| {
        x.* = 0;
    }
    for (&self.keys) |*x| {
        x.* = 0;
    }
    // load fontset from 0x0 to 0x4F
    for (chip8_fontset, 0..) |spr, idx| {
        self.memory[idx] = spr;
    }
}

fn incPc(self: *Self) void {
    // every instruction is 2 bytes. we can access one byte at a time.
    // so go up two bytes
    self.pc += 2;
}

pub fn cycle(self: *Self) void {
    if (self.pc > 0xFFF) @panic("PANIC: illegal program counter");
    // we address 1 byte at a time. opcode is stored as two seperate bytes contiguously.
    // shift first byte (higher), slot into the higher word, and add the lower byte
    self.opcode = @as(u16, @intCast(self.memory[self.pc])) << 8 | self.memory[self.pc + 1];

    // first significant nibble
    // THIS 0000 0000 0000
    const msn = self.opcode >> 12;
    switch (msn) {
        0x0 => {
            if (self.opcode == 0x00E0) {
                // clrscr
                for (&self.graphics) |*g| {
                    g.* = 0;
                }
            } else if (self.opcode == 0x00EE) {
                // ret instruction
                self.sp -= 1;
                self.pc = self.stack[self.sp];
            }
            self.incPc();
        },

        // jmp
        // just set pc to last 3 nibbles
        // we only use 12 bits for the addr
        0x1 => self.pc = self.opcode & 0x0FFF,

        // call instruction
        0x2 => {
            // save return address on current top of stack
            self.stack[self.sp] = self.pc;
            self.sp += 1;
            self.pc = self.opcode & 0x0FFF;
        },

        0x3 => {
            // skip next instruction if Vx = kk
            const x = (self.opcode & 0x0F00) >> 8;
            if (self.registers[x] == self.opcode & 0x00FF) {
                self.incPc();
            }
            self.incPc();
        },

        0x4 => {
            // skip next instruction if Vx != kk
            const x = (self.opcode & 0x0F00) >> 8;
            if (self.registers[x] != self.opcode & 0x00FF) {
                self.incPc();
            }
            self.incPc();
        },

        0x5 => {
            // skip next instruction if Vx == Vy
            const vx = (self.opcode & 0x0F00) >> 8;
            const vy = (self.opcode & 0x00F0) >> 4;
            if (self.registers[vx] == self.registers[vy]) {
                self.incPc();
            }
            self.incPc();
        },

        0x9 => {
            // skip next instruction if Vx != Vy
            const vx = (self.opcode & 0x0F00) >> 8;
            const vy = (self.opcode & 0x00F0) >> 4;
            if (self.registers[vx] != self.registers[vy]) {
                self.incPc();
            }
            self.incPc();
        },

        0x6 => {
            // load a byte
            const x = (self.opcode & 0x0F00) >> 8;
            self.registers[x] = @truncate(self.opcode & 0x00FF);
            self.incPc();
        },

        0x7 => {
            // add instruction
            @setRuntimeSafety(false);
            const x = (self.opcode & 0x0F00) >> 8;
            self.registers[x] += @truncate(self.opcode & 0x00FF);
            self.incPc();
        },

        // ALU INSTRUCTIONS

        0x8 => {
            const x = (self.opcode & 0x0F00) >> 8;
            const y = (self.opcode & 0x00F0) >> 4;
            const mode = self.opcode & 0x000F;

            switch (mode) {
                0 => self.registers[x] = self.registers[y],
                1 => self.registers[x] |= self.registers[y],
                2 => self.registers[x] &= self.registers[y],
                3 => self.registers[x] ^= self.registers[y],
                4 => {
                    var sum: u16 = self.registers[x];
                    sum += self.registers[y];

                    self.registers[0xF] = if (sum > 255) 1 else 0;
                    self.registers[x] = @truncate(sum & 0x00FF);
                },
                5 => {
                    @setRuntimeSafety(false);
                    self.registers[0xF] = if (self.registers[x] > self.registers[y]) 1 else 0;
                    self.registers[x] -= self.registers[y];
                },
                6 => {
                    self.registers[0xF] = self.registers[x] & 0b00000001;
                    self.registers[x] >>= 1;
                },
                7 => {
                    @setRuntimeSafety(false);
                    self.registers[0xF] = if (self.registers[y] > self.registers[x]) 1 else 0;
                    self.registers[x] = self.registers[y] - self.registers[x];
                },
                14 => {
                    self.registers[0xF] = if (self.registers[x] & 0b10000000 != 0) 1 else 0;
                    self.registers[x] <<= 1;
                },
                else => {},
            }

            self.incPc();
        },

        0xA => {

            // load address
            self.index = self.opcode & 0x0FFF;
            self.incPc();
        },

        0xB => {

            // jump to loc nnn + reg0
            self.pc = (self.opcode & 0x0FFF) + @as(u16, @intCast(self.registers[0]));
        },

        0xC => {
            const x = (self.opcode & 0x0F00) >> 8;
            const kk = self.opcode & 0x00FF;
            const rand_gen = std.Random.DefaultPrng;
            var rand = rand_gen.init(33);
            self.registers[x] = @mod(rand.random().int(u8), 255) & @as(u8, @truncate(kk));
            self.incPc();
        },

        // DRAW INSTRUCTION
        // each row of 8 pixels read as byte from memory
        // shoutout gemini for commenting
        0xD => {
            // 1. We assume no collision happened, so we set the flag to 0.
            self.registers[0xF] = 0;

            // 2. Get the parameters from the opcode
            const xidx = (self.opcode & 0x0F00) >> 8; // Register index for X coord
            const yidx = (self.opcode & 0x00F0) >> 4; // Register index for Y coord
            const offset = self.opcode & 0x000F; // The height (n) of the sprite

            // 3. Get the actual X and Y coordinates
            const regx = self.registers[xidx]; // e.g., 20
            const regy = self.registers[yidx]; // e.g., 10

            // 4. This is the OUTER loop. It loops "n" (offset) times.
            //    It processes ONE ROW of the sprite per loop.
            var y: usize = 0;
            while (y < offset) : (y += 1) {

                // 5. Get the 8-bit sprite data for the current row.
                //    y=0: get memory[I + 0]  (e.g., 0xF0)
                //    y=1: get memory[I + 1]  (e.g., 0x90)
                const spr = self.memory[self.index + y];

                // 6. This is the INNER loop. It loops 8 times (once for each bit/pixel
                //    in the "spr" byte).
                var x: usize = 0;
                while (x < 8) : (x += 1) {

                    // 7. This is the "magic line" to check a single bit.
                    //    (0x80 >> x) slides a "1" bit across:
                    //    x=0: checks (spr & 10000000)
                    //    x=1: checks (spr & 01000000)
                    //    ...etc.
                    //    If the result is "!= 0", that bit was a 1!
                    const v: u8 = 0x80;
                    if ((spr & (v >> @intCast(x))) != 0) {

                        // 8. This bit is a 1, so we need to draw a pixel.
                        //    First, calculate the final screen coordinates,
                        //    wrapping around if we go off-screen.
                        const tX = (regx + x) % 64; // Wrap X
                        const tY = (regy + y) % 32; // Wrap Y

                        // 9. Convert the 2D (tX, tY) coordinate to a 1D index
                        //    in your self.graphics array.
                        const idx = tX + tY * 64;

                        // 10. This is the collision check!
                        //     We are about to draw a pixel (self.graphics[idx] ^= 1).
                        //     If the pixel at self.graphics[idx] is ALREADY 1,
                        //     our XOR will flip it to 0, which means we had a collision.
                        //     (This line in your code is slightly out of order,
                        //     but the logic is correct!)
                        if (self.graphics[idx] == 1) { // Check BEFORE flipping
                            self.registers[0xF] = 1; // Set collision flag!
                        }

                        // 11. This is the actual "draw" (or "flip").
                        //     XOR is used, which is why sprites erase themselves
                        //     if drawn in the same spot twice.
                        //     1 ^ 1 = 0 (flips off)
                        //     0 ^ 1 = 1 (flips on)
                        self.graphics[idx] ^= 1;
                    }
                }
            }
            // 12. Done drawing, move to the next instruction.
            self.incPc();
        },

        0xE => {
            // key based skip
            // skip if key with the value of vx is skipped
            const x = (self.opcode & 0x0F00) >> 8;
            const m = self.opcode & 0x00FF;

            if (m == 0x9E) {
                if (self.keys[self.registers[x]] == 1) {
                    self.incPc();
                }
            } else if (m == 0xA1) {
                if (self.keys[self.registers[x]] != 1) {
                    self.incPc();
                }
            }
            self.incPc();
        },

        // Misc instructions
        // commented by gemini
        0xF => {
            // Get the register index 'x' from the opcode (0xFX00)
            const x = (self.opcode & 0x0F00) >> 8;

            // Get the specific instruction 'm' from the last byte (0x00FF)
            const m = self.opcode & 0x00FF;

            // --- FX07: LD Vx, DT ---
            // Loads the current value of the delay timer into register Vx.
            if (m == 0x07) {
                self.registers[x] = self.delayTimer;

                // --- FX0A: LD Vx, K ---
                // Wait for a key press and store the value of the key in register Vx.
                // This is a *blocking* operation.
            } else if (m == 0x0A) {
                var key_pressed = false;

                // Loop through all 16 keys
                var i: usize = 0;
                while (i < 16) : (i += 1) {
                    // If a key is currently pressed...
                    if (self.keys[i] != 0) {
                        // ...store its index (0-15) in Vx
                        self.registers[x] = @truncate(i);
                        key_pressed = true;
                        // Note: We don't break here, so if multiple keys are
                        // pressed, the highest-index key will be stored.
                    }
                }

                // If no key was pressed, we *must stop* executing
                // instructions until one is.
                if (!key_pressed) {
                    // By returning here, we *skip* `self.incPc()`.
                    // This means the program counter (PC) does not advance,
                    // and this *same instruction (FX0A)* will be executed
                    // again on the next cycle. This effectively "halts"
                    // the CPU until a key is pressed.
                    return;
                }

                // --- FX15: LD DT, Vx ---
                // Loads the value from register Vx into the delay timer.
            } else if (m == 0x15) {
                self.delayTimer = self.registers[x];

                // --- FX18: LD ST, Vx ---
                // Loads the value from register Vx into the sound timer.
            } else if (m == 0x18) {
                self.soundTimer = self.registers[x];

                // --- FX1E: ADD I, Vx ---
                // Adds the value of register Vx to the index register I.
            } else if (m == 0x1E) {
                // This instruction has a special quirk:
                // VF (register 0xF) is set to 1 if I + Vx > 0xFFF (overflows
                // the 12-bit address space), and 0 otherwise.
                self.registers[0xF] = if (self.index + self.registers[x] > 0xFFF) 1 else 0;
                self.index += self.registers[x];

                // --- FX29: LD F, Vx ---
                // Sets the index register I to the memory location of the sprite
                // for the digit stored in register Vx.
            } else if (m == 0x29) {
                // The font sprites are 5 bytes each (as seen in chip8_fontset).
                // We assume the fontset starts at memory address 0x0.
                // Digit 0 -> I = 0 * 5 = 0x0
                // Digit 1 -> I = 1 * 5 = 0x5
                // ...
                // Digit F -> I = 15 * 5 = 0x4B
                self.index = self.registers[x] * 0x5;

                // --- FX33: LD B, Vx ---
                // Stores the Binary-Coded Decimal (BCD) representation of
                // the value in register Vx at memory locations I, I+1, and I+2.
            } else if (m == 0x33) {
                // Example: If Vx = 123
                // self.memory[I]   = 123 / 100         = 1
                self.memory[self.index] = self.registers[x] / 100;

                // self.memory[I+1] = (123 / 10) % 10   = 12 % 10 = 2
                self.memory[self.index + 1] = (self.registers[x] / 10) % 10;

                // self.memory[I+2] = 123 % 10          = 3
                self.memory[self.index + 2] = self.registers[x] % 10;

                // --- FX55: LD [I], Vx ---
                // Stores registers V0 through Vx (inclusive) in memory
                // starting at memory location I.
            } else if (m == 0x55) {
                var i: usize = 0;
                while (i <= x) : (i += 1) {
                    self.memory[self.index + i] = self.registers[i];
                }

                // --- FX65: LD Vx, [I] ---
                // Loads registers V0 through Vx (inclusive) with values
                // from memory starting at memory location I.
            } else if (m == 0x65) {
                var i: usize = 0;
                while (i <= x) : (i += 1) {
                    self.registers[i] = self.memory[self.index + i];
                }
            }

            // All instructions in the 0xF block (except the waiting FX0A)
            // finish by incrementing the PC to the next instruction.
            self.incPc();
        },

        else => {},
    }
    if (self.delayTimer > 0)
        self.delayTimer -= 1;

    if (self.soundTimer > 0) {
        self.soundTimer -= 1;
    }
}

pub fn main() !void {
    std.debug.print("pass\n", .{});
}
