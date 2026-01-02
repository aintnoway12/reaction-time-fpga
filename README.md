# FPGA Reaction Time Measurement Game

## Project Overview
This project implements a **reaction time measurement game** on an FPGA board,
designed using **Verilog HDL** and implemented with **Xilinx Vivado**.

The system measures user reaction time in milliseconds after a random delay
and provides visual and audio feedback using LEDs, 7-segment display, RGB LED,
LCD, and a piezo buzzer.

## Development Environment
- Tool: Xilinx Vivado
- Language: Verilog HDL
- Clock: 50 MHz
- Platform: FPGA Board

## Game Flow (FSM)
1. **IDLE** – Wait for START button
2. **WAIT** – Random delay (500ms–2000ms)
3. **SIGNAL** – Reaction signal ON
4. **CAPTURE** – Measure reaction time
5. **RESULT** – Display result
6. **FALSE START** – Early button press detection


## Features
- Millisecond stopwatch
- Random delay using LFSR
- FSM-based control
- False start detection
- LED / RGB / 7-Segment / LCD output
- Piezo buzzer sound feedback
