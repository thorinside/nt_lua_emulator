# Development Guide
## Disting NT LUA Emulator

**Generated**: 2025-10-19
**Project Type**: Desktop Application
**Technology Stack**: Lua + LÖVE2D 11.3+

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Environment Setup](#environment-setup)
4. [Running the Application](#running-the-application)
5. [Development Workflow](#development-workflow)
6. [Testing](#testing)
7. [Building & Distribution](#building--distribution)
8. [Common Development Tasks](#common-development-tasks)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

1. **LÖVE2D** (version 11.3 or higher)
   - Download from: https://love2d.org/
   - The Lua-based game framework that powers the emulator

2. **Lua** (LuaJIT included with LÖVE2D)
   - No separate Lua installation required
   - LÖVE2D bundles LuaJIT

### Optional Software

1. **Git** - For version control
2. **Text Editor/IDE** - VS Code, Sublime Text, or any Lua-aware editor
3. **MIDI Device** - For testing MIDI integration (optional)

### Operating System Support

- **macOS**: Fully supported (arm64 and x86_64)
- **Linux**: Supported via LÖVE2D
- **Windows**: Supported via LÖVE2D

**Note**: The included `luamidi.so` library is compiled for **macOS arm64**. Other platforms require recompilation (see MIDI Setup section).

---

## Installation

### 1. Download LÖVE2D

**macOS**:
```bash
# Download from https://love2d.org/ or use Homebrew:
brew install love
```

**Linux** (Ubuntu/Debian):
```bash
sudo apt-get install love
```

**Windows**:
- Download installer from https://love2d.org/
- Run the installer

### 2. Clone the Repository

```bash
git clone https://github.com/yourusername/nt_lua_emulator.git
cd nt_lua_emulator
```

### 3. Verify Installation

Check LÖVE2D version:
```bash
love --version
# Should output: LÖVE 11.3 (or higher)
```

---

## Environment Setup

### Adding LÖVE to PATH

**macOS**:
```bash
# Add to ~/.zshrc or ~/.bashrc:
export PATH="$PATH:/Applications/love.app/Contents/MacOS"

# Reload shell configuration:
source ~/.zshrc
```

**Linux**:
LÖVE is typically added to PATH automatically during installation.

**Windows**:
Add LÖVE installation directory to system PATH via Environment Variables.

### Configuration Files

The emulator uses two primary configuration files:

1. **`config.json`** - User preferences (created on first run)
   - OSC settings (host, port, enabled status)
   - MIDI settings (selected devices)
   - UI mode (minimal or full)

2. **`state.json`** - Runtime state (auto-generated)
   - Script path
   - I/O mappings
   - Window position
   - Script parameters

Both files are automatically created and managed by the emulator.

---

## Running the Application

### Basic Execution

```bash
# From the project directory:
love .

# Or with full path:
love /path/to/nt_lua_emulator
```

### With a Specific Script

```bash
# The emulator remembers the last loaded script in config.json
# To load a different script, press F2 in the running application
```

### Command Line (Alternative)

```bash
# Directly invoke via absolute path:
/Applications/love.app/Contents/MacOS/love /path/to/nt_lua_emulator
```

---

## Development Workflow

### Project Structure

```
nt_lua_emulator/
├── main.lua              # Entry point
├── conf.lua              # LÖVE configuration
├── modules/              # Core modules (28 files)
├── lib/                  # External libraries
├── scripts/              # Example user scripts
└── docs/                 # Documentation
```

### Hot Reload

The emulator supports **automatic hot-reloading** of user scripts:

1. Load a script via **F2**
2. Edit the script in your editor
3. Save the file
4. The emulator automatically reloads the script
5. State is preserved across reloads

**Benefits**:
- Instant feedback
- No need to restart the emulator
- Error recovery with notifications

### Adding New Modules

1. Create new module in `/modules/`:
   ```lua
   -- modules/my_module.lua
   local M = {}

   function M.init(deps)
       -- Initialize with dependencies
       return M
   end

   -- Public functions
   function M.doSomething()
       -- Implementation
   end

   return M
   ```

2. Require in `emulator.lua`:
   ```lua
   local myModule = require("modules.my_module")
   ```

3. Initialize in `emulator.load()`:
   ```lua
   myModule.init({ /* dependencies */ })
   ```

### Debugging

**Console Output**:
- Use `print()` statements
- Output appears in terminal (if running from command line)

**Debug Mode**:
- Press **Ctrl-D** to toggle debug mode
- Enables verbose logging

**Memory Profiling**:
- `debug_utils.lua` provides memory tracking wrappers
- Press **F11** to enable profiling (see `main.lua`)

---

## Testing

### No Automated Test Framework

This project currently has **no automated test suite**.

### Manual Testing

**Load Example Scripts**:
```bash
# Test scripts are located in /scripts/
ls scripts/
```

**Test Workflow**:
1. Launch emulator: `love .`
2. Press **F2** to load a test script
3. Verify functionality:
   - Display rendering
   - I/O mapping (drag-and-drop)
   - Parameter controls
   - MIDI input (if available)
   - OSC output (if enabled)

**Test Scripts Available**:
- `test_script.lua` - Basic functionality test
- `test_midi_output.lua` - MIDI output test
- `test_algorithm_index.lua` - Algorithm introspection
- `test_algorithm_query.lua` - Algorithm query test
- `test_error_*.lua` - Error handling tests

---

## Building & Distribution

### Creating a .love Package

```bash
# From project root:
zip -9 -r nt_lua_emulator.love . -x "*.git*" -x "*bmad*" -x "*docs*"
```

### Standalone Distribution

**macOS**:
```bash
# Copy .love file into LÖVE app bundle:
cp nt_lua_emulator.love /Applications/love.app/Contents/Resources/
# Rename the app bundle
cp -r /Applications/love.app ./DistingNTEmulator.app
```

**Windows/Linux**:
- Follow LÖVE distribution guide: https://love2d.org/wiki/Game_Distribution

---

## Common Development Tasks

### Changing Display Resolution

Edit `modules/display.lua`:
```lua
local config = {
    width = 256,   -- Change width
    height = 64,   -- Change height
    scaling = 4    -- Change scaling factor
}
```

### Adding OSC Endpoints

Edit `modules/osc_client.lua` to customize OSC message format.

### Compiling MIDI Library (Non-macOS)

The `luamidi.so` library is pre-compiled for macOS arm64. For other platforms:

```bash
# Clone lovemidi:
git clone https://github.com/thorinside/lovemidi
cd lovemidi

# Build rtmidi dependency:
cd rtmidi && mkdir build && cd build
cmake .. -DRTMIDI_API_JACK=OFF -DRTMIDI_API_CORE=ON -DBUILD_SHARED_LIBS=OFF
make
cd ../..

# Build luamidi (adjust paths for your system):
make -f Makefile.simple

# Copy to emulator directory:
cp luamidi.so /path/to/nt_lua_emulator/
```

**Requirements**:
- CMake
- C++ compiler
- LuaJIT headers (install via package manager)

### Modifying UI Layout

- **Minimal Mode**: Edit `modules/minimal_mode.lua`
- **Full Mode**: Edit `conf.lua` window size calculations
- **I/O Panel**: Edit `modules/io_panel.lua`
- **Controls**: Edit `modules/controls.lua`

---

## Troubleshooting

### Application Won't Launch

**Check LÖVE version**:
```bash
love --version
# Must be 11.3 or higher
```

**Check working directory**:
```bash
# Must run from project root or provide full path:
love /full/path/to/nt_lua_emulator
```

### Script Errors

- Errors are displayed on-screen as notifications
- Check console output for detailed stack traces
- Verify script syntax with a Lua linter

### MIDI Not Working

- **macOS**: Ensure `luamidi.so` is present and compiled for your architecture
- **Other platforms**: Recompile `luamidi.so` (see above)
- Check MIDI device selection via **F3**

### OSC Not Sending

1. Enable OSC: Press **Ctrl-O** or edit `config.json`
2. Check firewall settings
3. Verify host/port in `config.json` (default: 127.0.0.1:8000)
4. Test with an OSC monitor application

### Performance Issues

- Reduce signal processing rate in complex scripts
- Disable OSC if not needed
- Use minimal mode (**Toggle in config.json: `"minimalMode": true`**)

### State Corruption

If `state.json` becomes corrupted:
```bash
# Delete and restart:
rm state.json
love .
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **F2** | Open script selection dialog |
| **F3** | Open MIDI input device selection |
| **Ctrl-O** | Toggle OSC output |
| **Ctrl-D** | Toggle debug mode |
| **Ctrl-S** | Save state manually |
| **Alt-F4** / **Cmd-Q** | Quit application |
| **Arrow keys** | Navigate dialogs |
| **Enter** | Confirm selection |
| **Escape** | Cancel/close dialogs |

---

## Additional Resources

- **LÖVE2D Documentation**: https://love2d.org/wiki/
- **Disting NT Manual**: https://www.expert-sleepers.co.uk/distingNT.html
- **Lua Reference**: https://www.lua.org/manual/5.1/
- **Project README**: `README.md`
- **Design Documentation**: `DESIGN.md`
- **API Reference**: `disting_nt_lua_prompt_summary.md`

---

## Contributing

Currently, this project has no formal contribution guidelines (`CONTRIBUTING.md` does not exist).

For questions or issues:
1. Check existing documentation (`README.md`, `DESIGN.md`)
2. Review example scripts in `/scripts/`
3. Open an issue on the project repository

---

*This guide was generated from an exhaustive analysis of the codebase and existing documentation.*
