# Source Tree Analysis
## Disting NT LUA Emulator

**Generated**: 2025-10-19
**Project Type**: Desktop Application (Monolith)
**Technology**: Lua + LÖVE2D 11.3+

---

## Directory Structure

```
nt_lua_emulator/
├── main.lua                    # 🔵 Entry point - LÖVE2D application bootstrap
├── conf.lua                    # Configuration for LÖVE2D engine
├── config.json                 # User configuration (OSC, MIDI, UI mode)
├── state.json                  # Runtime state persistence (I/O mappings, script state)
│
├── modules/                    # Core emulator modules (28 files)
│   ├── emulator.lua           # 🔵 Main orchestration module
│   │
│   ├── script_loader.lua      # Script loading & hot-reload
│   ├── script_manager.lua     # Script lifecycle management
│   ├── script_utils.lua       # Script utilities
│   │
│   ├── display.lua            # 256x64 OLED/LCD emulation
│   ├── controls.lua           # Virtual buttons, encoders, pots
│   ├── io_panel.lua           # Drag-and-drop I/O mapping UI
│   ├── parameter_knobs.lua    # Parameter adjustment UI
│   ├── parameter_manager.lua  # Parameter state management
│   │
│   ├── signal_processor.lua   # Signal generation & processing
│   ├── input_handler.lua      # Mouse/keyboard input handling
│   │
│   ├── io_state.lua           # I/O mapping persistence
│   ├── ui_state.lua           # UI state & transitions
│   ├── config.lua             # Configuration management
│   │
│   ├── midi_handler.lua       # MIDI I/O management
│   ├── midi_input_dialog.lua  # MIDI device selection dialog
│   ├── midi_output_dialog.lua # MIDI output dialog
│   │
│   ├── osc.lua                # OSC protocol handler
│   ├── osc_client.lua         # OSC client implementation
│   │
│   ├── file_dialog.lua        # File selection dialog
│   ├── path_input_dialog.lua  # Path input UI
│   ├── window_manager.lua     # Window state management
│   ├── minimal_mode.lua       # Minimal UI mode
│   ├── notifications.lua      # In-app notifications
│   │
│   ├── helpers.lua            # Utility functions
│   ├── debug_utils.lua        # Debugging & profiling
│   ├── constants.lua          # Global constants (kCV, kGate, kTrigger, etc.)
│   └── README.md              # Module documentation
│
├── lib/                        # External libraries
│   ├── dkjson.lua             # JSON encoding/decoding
│   └── complex.lua            # Complex number math
│
├── luamidi.so                  # MIDI support library (macOS arm64)
│
├── scripts/                    # Example user scripts
│   └── (various .lua files)
│
├── fonts/                      # Custom fonts for display
│   ├── PixelmixRegular.ttf
│   └── tom-thumb.ttf
│
├── docs/                       # Project documentation
│   └── stories/               # Development stories
│
├── .github/                    # GitHub configuration
│   └── workflows/             # CI/CD workflows
│
├── README.md                   # Project overview & usage guide
├── DESIGN.md                   # Design documentation
├── CLAUDE.md                   # Claude Code instructions
├── disting_nt_lua_prompt_summary.md  # Disting NT API reference
├── lua-algorithm.lua.template  # Template for algorithm scripts
├── LICENSE                     # Project license
│
└── test_*.lua                  # Test scripts (various)
```

---

## Critical Directories

### `/modules/` - Core Emulator Modules
**Purpose**: Contains all core functionality organized into single-responsibility modules.

**Key Subsystems**:
- **Script Execution**: `script_loader.lua`, `script_manager.lua`, `script_utils.lua`
- **Display & UI**: `display.lua`, `controls.lua`, `io_panel.lua`, `parameter_knobs.lua`
- **I/O Processing**: `signal_processor.lua`, `input_handler.lua`
- **State Management**: `io_state.lua`, `ui_state.lua`, `config.lua`
- **External Integration**: `midi_handler.lua`, `osc.lua`, `osc_client.lua`
- **Dialogs**: `file_dialog.lua`, `path_input_dialog.lua`, `midi_input_dialog.lua`, `midi_output_dialog.lua`

### `/lib/` - External Libraries
**Purpose**: Third-party Lua libraries.
- `dkjson.lua`: JSON serialization/deserialization
- `complex.lua`: Complex number operations

### `/scripts/` - User Scripts
**Purpose**: Example Lua scripts that run in the emulator. Users can load their own scripts designed for the Disting NT hardware.

### `/fonts/` - Display Fonts
**Purpose**: Custom pixel fonts for the 256x64 display emulation.

### `/docs/` - Project Documentation
**Purpose**: Generated and curated project documentation.

---

## Entry Points

### Primary Entry Point
- **`main.lua`** (line 1)
  - Initializes all subsystems via `emulator.load()`
  - Sets up LÖVE2D lifecycle hooks: `love.load()`, `love.update()`, `love.draw()`
  - Handles global input events and delegates to dialogs/emulator

### Configuration Entry Point
- **`conf.lua`** (line 1)
  - Runs before `main.lua`
  - Configures LÖVE2D engine settings
  - Determines window size based on UI mode (minimal vs full)
  - Reads `state.json` to restore window position

### Core Orchestrator
- **`modules/emulator.lua`** (line 1)
  - Central coordinator for all subsystems
  - Dependency injection container
  - Manages update loop orchestration

---

## Key Integration Points

### State Persistence
- **Files**: `state.json`, `config.json`
- **Modules**: `io_state.lua`, `config.lua`
- **Flow**: Automatic save on changes, load on startup

### Script Lifecycle
- **Entry**: `script_loader.lua` → Loads user scripts
- **Execution**: `script_manager.lua` → Manages callbacks
- **Hot Reload**: File watching with automatic error recovery

### I/O Data Flow
1. User interaction or signal generation → `signal_processor.lua`
2. Process script inputs → User script `process()` function
3. Script outputs → `signal_processor.lua`
4. Display updates + OSC messages + MIDI output

### External Communication
- **OSC**: `osc_client.lua` sends output values to external applications
- **MIDI**: `midi_handler.lua` routes MIDI messages to/from scripts
- **File System**: Hot-reload monitoring, state persistence

---

## Architecture Patterns

### Module Pattern
All modules return a table with public functions, maintaining encapsulated state.

```lua
local M = {}
-- private state
function M.publicFunction() end
return M
```

### Dependency Injection
`emulator.lua` initializes modules with their dependencies:

```lua
scriptLoader.init({
    showNotification = notifications.showNotification,
    midiHandler = midiHandler
})
```

### Event-Driven Architecture
LÖVE2D lifecycle hooks drive the execution:
- `love.update(dt)` → Process inputs, update state
- `love.draw()` → Render display and UI
- `love.keypressed()`, `love.mousepressed()` → Handle input

---

## File Organization Strategy

**By Responsibility**: Each module has a single, well-defined responsibility
**Flat Structure**: All modules in `/modules/` for easy discovery
**Clear Naming**: Module names directly indicate their purpose
**No Circular Dependencies**: Dependency flow is unidirectional through `emulator.lua`

---

## Development Workflow Support

### Hot Reload
- `script_loader.lua` monitors script files for changes
- Automatic reload on save with error recovery
- State preservation across reloads

### Debug Support
- `debug_utils.lua` provides memory profiling wrappers
- Console logging throughout
- Error notifications displayed on-screen

### Configuration
- `config.json` for user preferences (persistent across sessions)
- `state.json` for runtime state (I/O mappings, window position)
- `conf.lua` for LÖVE2D engine settings

---

*This analysis was generated from an exhaustive scan of the codebase.*
