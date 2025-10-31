# CHIP-8

![Zig Version](https://img.shields.io/badge/zig-0.15.1+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)

A simple CHIP-8 emulator/interpreter written in Zig, using Raylib for graphics.

![CHIP-8 Emulator Demo](demo/img1.gif)

## Features

*   All 35 instructions.
*   Supports running of CHIP-8 & ETI-660 ROMS.
*   Supports the 16-key hex keyboard.

## Build

### Dependencies

*   Zig 0.15.1

### Instructions

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/nxck2005/chip8.git
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
