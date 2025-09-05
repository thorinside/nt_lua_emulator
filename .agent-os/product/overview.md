# Product Overview

> Last Updated: 2025-09-05
> Version: 1.0.0

## Pitch

The Disting NT LUA Emulator is a desktop development environment that removes the friction from creating and testing Lua scripts for the Expert Sleepers Disting NT Eurorack module. Instead of requiring physical hardware, patch cables, and complex Eurorack setups, developers can prototype, debug, and perfect their NT scripts using an intuitive drag-and-drop interface with real-time signal visualization.

## Users

**Primary Users:**
- Eurorack musicians developing custom signal processing algorithms
- Sound designers creating experimental audio tools
- Disting NT script developers building libraries and utilities
- Electronic music producers exploring modular synthesis concepts

**Secondary Users:**
- Educators teaching modular synthesis and audio programming
- Hardware manufacturers prototyping Eurorack module concepts
- Audio software developers learning embedded Lua programming

## The Problem

Developing scripts for the Disting NT requires:
- Physical Eurorack hardware setup ($$$)
- Complex patch cable routing for I/O testing
- Limited debugging capabilities on hardware
- Time-consuming iteration cycles (save → transfer → test → repeat)
- Risk of hardware damage during development
- Difficulty sharing and collaborating on script projects

Traditional development workflows force creators to context-switch between code editor, hardware patching, and manual testing, breaking creative flow and slowing innovation.

## Differentiators

**Hardware Independence**: Complete NT API emulation without requiring physical modules
**Visual Development**: Drag-and-drop I/O mapping with real-time signal visualization  
**Hot Reload**: Instant script updates during development without restarting
**Dual Interface**: Switch between control-focused and parameter-focused UI modes
**Professional Tooling**: State persistence, OSC integration, MIDI support, and keyboard shortcuts
**Accurate Emulation**: Pixel-perfect 256x64 display rendering with exact NT API compatibility

## Key Features

### Core Development Environment
- **Script Hot-Reload**: Automatic detection and reload of script changes
- **Protected Execution**: Sandboxed script environment prevents crashes
- **256x64 Display Emulation**: Pixel-perfect recreation of NT hardware display
- **Full NT API Support**: Compatible with Disting NT API 1.9.0 specification

### I/O Simulation System
- **12 Input/8 Output Channels**: Complete hardware I/O emulation
- **Drag-Drop I/O Mapping**: Visual assignment of script I/O to virtual hardware
- **Signal Generation**: Bipolar, unipolar, and clock signal sources
- **Real-Time Visualization**: Live signal monitoring and waveform display

### Integration Capabilities
- **OSC Messaging**: Send output values to external applications (127.0.0.1:8000)
- **MIDI Integration**: Hardware MIDI device support with F4 device selection
- **State Persistence**: Automatic saving of I/O mappings, window position, and configuration
- **JSON Configuration**: Human-readable settings and state management

### User Experience
- **Dual UI Modes**: Control mode (buttons/encoders) and Parameter mode (knobs/sliders)
- **Hardware Keyboard Shortcuts**: F2 (load), Ctrl-O (OSC toggle), Ctrl-D (debug), Ctrl-S (save)
- **Parameter Controls**: Real-time script parameter adjustment with visual feedback
- **Professional Workflow**: Seamless integration with existing development tools