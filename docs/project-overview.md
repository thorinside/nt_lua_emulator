# Project Overview
## Disting NT LUA Emulator

**Generated**: 2025-10-19

---

## What is This Project?

The **Disting NT LUA Emulator** is a desktop application that provides a virtual development environment for creating and testing Lua scripts designed for the **Expert Sleepers Disting NT** Eurorack module. It simulates the hardware's display, controls, and I/O, allowing developers to iterate quickly without physical hardware.

---

## Project Identity

| Property | Value |
|----------|-------|
| **Name** | Disting NT LUA Emulator |
| **Type** | Desktop Application |
| **Category** | Developer Tool / Emulator |
| **Platform** | Cross-platform (macOS, Linux, Windows) |
| **License** | See LICENSE file |

---

## Quick Reference

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Framework** | LÖVE2D | 11.3+ |
| **Language** | Lua (LuaJIT) | 5.1 |
| **JSON Library** | dkjson | - |
| **MIDI Library** | luamidi.so | macOS arm64 |
| **Graphics** | OpenGL (via LÖVE) | - |

### Architecture Type

**Pattern**: Event-Driven Modular
**Structure**: Monolith (single application with 28 modules)
**Integration**: OSC, MIDI

---

## Repository Structure

```
nt_lua_emulator/           # Monolithic desktop application
├── main.lua               # Entry point
├── conf.lua               # LÖVE2D configuration
├── config.json            # User configuration
├── state.json             # Runtime state
├── modules/               # Core modules (28 files)
│   ├── emulator.lua       # Main orchestrator
│   ├── script_loader.lua  # Script management
│   ├── display.lua        # 256x64 OLED emulation
│   ├── signal_processor.lua # I/O processing
│   └── ...                # (24 more modules)
├── lib/                   # External libraries
├── scripts/               # Example user scripts
├── fonts/                 # Display fonts
└── docs/                  # Documentation (this folder)
```

**Repository Type**: Monolith
**Primary Language**: Lua
**Lines of Code**: ~10,000+ (estimated)

---

## Core Features

### For Script Developers

1. **Virtual Hardware Emulation**
   - 256x64 OLED/LCD display
   - 12 virtual inputs (CV, gate, trigger)
   - 8 virtual outputs
   - Buttons, encoders, potentiometers

2. **Rapid Development Workflow**
   - Hot-reload: Edit scripts and see changes instantly
   - No hardware required
   - Sandboxed execution with error recovery

3. **I/O Management**
   - Drag-and-drop I/O mapping
   - Signal visualization
   - Clock generation (30-200 BPM)

4. **External Integration**
   - OSC output for external applications
   - MIDI input/output support
   - Real-time parameter adjustment

### Technical Features

- **State Persistence**: Automatic save/restore of configurations and I/O mappings
- **Minimal Mode**: Streamlined display-only UI
- **Debug Support**: Memory profiling and console logging
- **Cross-Platform**: Runs on macOS, Linux, Windows

---

## What Problem Does This Solve?

**Problem**: Developing Lua scripts for the Disting NT hardware module requires:
- Physical hardware ($500+)
- Eurorack power supply and case
- Patching and manual testing
- Slow iteration cycle (upload, test, modify, repeat)

**Solution**: The emulator provides:
- **Virtual hardware** accessible to anyone with a computer
- **Instant feedback** via hot-reload
- **Simulated I/O** without physical patch cables
- **Visual debugging** with on-screen display

---

## Who Is This For?

### Primary Audience

- **Eurorack Musicians** exploring Lua scripting on Disting NT
- **Algorithm Developers** prototyping DSP ideas
- **Educators** teaching modular synthesis concepts

### Secondary Audience

- **Hobbyists** learning Lua programming
- **Tool Developers** building utilities for Disting NT

---

## Key Use Cases

1. **Script Development**
   - Write Lua scripts
   - Test signal processing
   - Debug visual output

2. **Learning & Experimentation**
   - Explore Disting NT API
   - Prototype algorithms
   - Test ideas before hardware investment

3. **Integration Testing**
   - Test OSC integration with DAWs
   - Validate MIDI communication
   - Verify complex I/O routing

---

## Getting Started

### Quick Start (5 Minutes)

```bash
# 1. Install LÖVE2D
brew install love   # macOS
# or download from https://love2d.org/

# 2. Run the emulator
love /path/to/nt_lua_emulator

# 3. Load a script
Press F2 → select scripts/test_script.lua

# 4. Start developing!
Edit the script → Save → See changes instantly
```

### Next Steps

- **Read**: [Development Guide](./development-guide.md)
- **Understand**: [Architecture Documentation](./architecture.md)
- **Explore**: [Source Tree Analysis](./source-tree-analysis.md)
- **Reference**: [Project README](../README.md)

---

## Project Maturity

| Aspect | Status |
|--------|--------|
| **Stability** | Mature (core features complete) |
| **Testing** | Manual testing only (no test suite) |
| **Documentation** | Moderate (README, DESIGN.md, this docs folder) |
| **Active Development** | Maintenance mode |

---

## External Dependencies

### Runtime Dependencies

- **LÖVE2D** (11.3+): Core framework
- **Operating System**: macOS, Linux, or Windows

### Bundled Libraries

- `lib/dkjson.lua`: JSON encoding/decoding
- `lib/complex.lua`: Complex number math
- `luamidi.so`: MIDI support (macOS arm64, optional)

### Optional Dependencies

- **MIDI Devices**: For MIDI integration testing
- **OSC-Compatible Software**: For OSC output testing (e.g., TouchOSC, Max/MSP)

---

## Related Projects

- **Expert Sleepers Disting NT**: The hardware module this emulates
- **LÖVE2D**: The framework powering this emulator
- **lovemidi**: MIDI library for Lua (https://github.com/thorinside/lovemidi)

---

## Support & Resources

### Documentation

- **README.md**: Quick start and features overview
- **DESIGN.md**: Design decisions and rationale
- **CLAUDE.md**: Instructions for Claude Code AI assistant
- **disting_nt_lua_prompt_summary.md**: Disting NT API reference

### Official Links

- **Disting NT Manual**: https://www.expert-sleepers.co.uk/distingNT.html
- **LÖVE2D Documentation**: https://love2d.org/wiki/

---

## Project Statistics

| Metric | Value |
|--------|-------|
| **Modules** | 28 core modules |
| **External Libraries** | 2 (dkjson, complex) |
| **Example Scripts** | 10+ test scripts |
| **Supported Input Types** | 3 (CV, Gate, Trigger) |
| **Supported Output Types** | 2 (CV, Gate) |
| **Display Resolution** | 256x64 pixels |
| **I/O Channels** | 12 inputs, 8 outputs |
| **Control Elements** | 4 buttons, 3 pots, 2 encoders |

---

## Development Philosophy

1. **Modularity**: Each module has a single, well-defined responsibility
2. **Simplicity**: Lua's simplicity reflected in architecture
3. **Usability**: Focus on developer experience (hot-reload, visual feedback)
4. **Fidelity**: Accurate emulation of hardware behavior

---

## Future Directions

Based on codebase analysis, potential areas for enhancement:

- **Testing**: Add automated test suite
- **Linting**: Integrate Lua linter
- **Distribution**: Create standalone application bundles
- **Documentation**: Video tutorials and interactive guides
- **Community**: Script library and sharing platform

---

*This overview was generated from an exhaustive analysis of the project structure and codebase.*
