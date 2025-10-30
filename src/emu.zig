const std = @import("std");
const cstd = @cImport(@cInclude("stdlib.h"));
const time = @cImport(@cInclude("time.h"));

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
const chip8_fontset = [80]u8{
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
    self.sp - 0;
    self.delayTimer = 0;
    self.soundTimer = 0;

    // zero out bitfields
    for (self.graphics) |*x| {
        x.* = 0;
    }
    for (self.memory) |*x| {
        x.* = 0;
    }
    for (self.stack) |*x| {
        x.* = 0;
    }
    for (self.registers) |*x| {
        x.* = 0;
    }
    for (self.keys) |*x| {
        x.* = 0;
    }

    // load fontset from 0x0 to 0x4F
    for (chip8_fontset) |c, idx| {
        self.memory[idx] = c;
    }
}

fn incPc(self: *Self) void {
    // every instruction is 2 bytes. we can access one byte at a time.
    // so go up two bytes
    self.pc += 2;
}

pub fn cycle(self: *Self) void {
    // we address 1 byte at a time. opcode is stored as two seperate bytes contiguously.
    // shift first byte (higher), slot into the higher word, and add the lower byte
    self.opcode = self.memory[self.pc] << 8 | self.memory[self.pc + 1];

    // first significant nibble
    // THIS 0000 0000 0000
    var msn = self.opcode >> 12;

    switch(msn) {
        0x0 => {
            if (self.opcode == 0x00E0) {
                // clrscr
                for (self.graphics) |*gval| {
                    gval.* = 0;
                }
            } else if (self.opcode == 0x00EE) {
                // ret instruction
                // opposite of call, given below
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

            // increment top
            self.sp += 1;

            // set pc to new address (last 3 nibbles)
            self.pc = self.opcode & 0x0FFF;
        },

        0x3 => {
            // skip next instruction if Vx = kk
            var regno = (self.opcode & 0x0F00) >> 8;
            if (self.registers[regno] == (self.opcode & 0x00FF)) {
                self.incPc();
            }
            self.incPc();
        },

        0x4 => {
            // skip next instruction if Vx != kk
            var regno = (self.opcode & 0x0F00) >> 8;
            if (self.registers[regno] != (self.opcode & 0x00FF)) {
                self.incPc();
            }
            self.incPc();
        },

        0x5 => {
            // skip next instructio if Vx == Vy
            var vx = (self.opcode & 0x0F00) >> 8;
            var vy = (self.opcode & 0x00F0) >> 4;
            if (self.registers[vx] != self.registers[vy]) {
                self.incPc();
            }
            self.incPc();
        },
    }
}
