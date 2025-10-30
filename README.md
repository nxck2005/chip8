# CHIP-8 Emulator

![Zig Version](https://img.shields.io/badge/zig-0.15.1+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)

A simple CHIP-8 emulator written in Zig, using Raylib for graphics.

## Features

*   Implements all 35 original CHIP-8 opcodes.
*   Supports CHIP-8 ROMs.
*   Basic graphics and input handling.

## Building and Running

### Dependencies

*   Zig 0.15.1

### Instructions

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/chip8.git
    cd chip8
    ```

2.  **Build the project:**
    ```bash
    zig build
    ```

3.  **Run the emulator:**
    ```bash
    zig build run -- <path_to_rom>
    ```
    For example:
    ```bash
    zig build run -- roms/Breakout.ch8
    ```

## Usage

To run a CHIP-8 ROM, provide the path to the ROM file as a command-line argument to the emulator.

## Controls

The emulator uses the following keyboard layout for CHIP-8's 16-key hexadecimal keypad:

| Key | CHIP-8 Key |
| --- | ---------- |
| 1   | 1          |
| 2   | 2          |
| 3   | 3          |
| 4   | C          |
| Q   | 4          |
| W   | 5          |
| E   | 6          |
| R   | D          |
| A   | 7          |
| S   | 8          |
| D   | 9          |
| F   | E          |
| Z   | A          |
| X   | 0          |
| C   | B          |
| V   | F          |


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.