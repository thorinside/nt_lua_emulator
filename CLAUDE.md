# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Disting NT LUA Emulator** - a LÖVE2D-based emulator for developing and testing Lua scripts for the Expert Sleepers Disting NT Eurorack module without requiring physical hardware.

## Development Commands

### Running the Application
```bash
love /Users/nealsanche/nosuch/nt_lua_emulator
```

Since this is a pure Lua/LÖVE2D project, there are no build, test, or lint commands configured. The application runs directly through the LÖVE2D framework.

## High-Level Architecture

### Core Technology Stack
- **Framework**: LÖVE2D (Love2D) - version 11.3+
- **Language**: Lua
- **External Libraries**: dkjson (lib/dkjson.lua)

### Architecture Pattern
The codebase follows a modular event-driven architecture with clear separation of concerns:

1. **main.lua** - Entry point that integrates with LÖVE2D lifecycle hooks
2. **modules/emulator.lua** - Core simulation engine that orchestrates all subsystems
3. **Modular Components** - Each major feature is encapsulated in its own module under `modules/`

### Key Subsystems

#### Script Management
- **script_loader.lua**: Handles loading, execution, and hot-reloading of user scripts in a sandboxed environment
- **script_manager.lua**: Manages script lifecycle, state serialization, and parameter definitions

#### I/O System
- **io_panel.lua**: Drag-and-drop UI for mapping script I/O to virtual hardware I/O
- **signal_processor.lua**: Generates and processes signals (bipolar, unipolar, clock)
- **io_state.lua**: Persists I/O mappings and configurations

#### Display & Controls
- **display.lua**: Emulates the 256x64 OLED/LCD hardware display
- **controls.lua**: Virtual buttons, encoders, and potentiometers with callback system
- **parameter_knobs.lua**: UI controls for script parameter adjustment

#### State Management
- **config.json**: Application configuration (OSC settings, UI mode)
- **state.json**: Runtime state (script path, I/O mappings, window position)
- State automatically persists on changes and application exit

### Script Environment
User scripts run in a protected Lua environment with access to:
- Drawing functions (drawRectangle, drawText, etc.) for the virtual display
- Input/Output processing through `process(inputs, outputs)` callback
- Control callbacks (button, pot1Turn, encoder1Push, etc.)
- Parameter management (setParameter, getParameter)

Scripts must return a table with:
- `inputs`/`outputs`: I/O type definitions (kCV, kGate, kTrigger)
- `process`: Main processing function called each frame
- `init`: Optional initialization
- Control callbacks: Optional handlers for user interaction

### Data Flow
1. User input or generated signals → Signal Processor
2. Signal Processor → Script inputs (via I/O mappings)
3. Script process() function → Script outputs
4. Script outputs → Signal Processor (via I/O mappings)
5. Signal Processor → Display updates, OSC messages, UI visualization

### OSC Integration
The emulator can send output values as OSC messages to external applications:
- Default endpoint: 127.0.0.1:8000
- Message format: /ch/[channel_number] with float value
- Toggle with Ctrl-O

## Important Notes

- **No test framework**: This project has no automated tests
- **No linting**: No Lua linting configuration exists
- **File monitoring**: Scripts automatically reload when modified on disk
- **Protected execution**: All user scripts run in sandboxed environments to prevent crashes
- **Keyboard shortcuts**: F2 (load script), Ctrl-O (toggle OSC), Ctrl-D (debug mode), Ctrl-S (save state)