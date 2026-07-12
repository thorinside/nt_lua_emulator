# Architecture Documentation
## Disting NT LUA Emulator

**Generated**: 2025-10-19
**Project Type**: Desktop Application (Monolith)
**Architecture Pattern**: Event-Driven Modular

---

## Executive Summary

The Disting NT LUA Emulator is a **desktop application** built with **LÖVE2D** (Lua game framework) that provides a virtual environment for developing and testing Lua scripts designed for the Expert Sleepers Disting NT Eurorack module. The architecture follows an **event-driven modular pattern** with clear separation of concerns, enabling hot-reloading, state persistence, and real-time signal processing.

**Key Architectural Characteristics**:
- **Monolithic structure** with modular organization
- **Event-driven execution** via LÖVE2D lifecycle hooks
- **Dependency injection** for loose coupling
- **Sandboxed script execution** with callback-based API
- **State persistence** via JSON files
- **External integrations**: OSC, MIDI

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Technology Stack](#technology-stack)
3. [Architecture Patterns](#architecture-patterns)
4. [Component Architecture](#component-architecture)
5. [Data Architecture](#data-architecture)
6. [Execution Flow](#execution-flow)
7. [Module Interactions](#module-interactions)
8. [State Management](#state-management)
9. [Script Execution Environment](#script-execution-environment)
10. [External Integrations](#external-integrations)
11. [UI Architecture](#ui-architecture)
12. [Error Handling & Recovery](#error-handling--recovery)
13. [Performance Considerations](#performance-considerations)
14. [Security & Sandboxing](#security--sandboxing)

---

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     LÖVE2D Runtime Engine                    │
│                    (Event Loop & Graphics)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │      main.lua (Entry)      │
         │  - love.load()             │
         │  - love.update(dt)         │
         │  - love.draw()             │
         └──────────┬─────────────────┘
                    │
         ┌──────────▼──────────────────────┐
         │   emulator.lua (Orchestrator)   │
         │   - Dependency injection        │
         │   - Subsystem coordination      │
         └──────────┬──────────────────────┘
                    │
      ┌─────────────┼─────────────┬────────────┬─────────────┐
      │             │             │            │             │
┌─────▼─────┐ ┌─────▼─────┐ ┌────▼─────┐ ┌───▼──────┐ ┌────▼────┐
│  Script   │ │    I/O    │ │    UI    │ │  State   │ │External │
│ Execution │ │Processing │ │Components│ │Management│ │Integration│
└───────────┘ └───────────┘ └──────────┘ └──────────┘ └─────────┘
  - loader      - signal      - display    - io_state   - OSC
  - manager       processor   - controls   - ui_state   - MIDI
  - utils       - inputs      - io_panel   - config
                - outputs     - dialogs
```

### Architectural Layers

1. **Platform Layer**: LÖVE2D framework
2. **Application Core**: `main.lua`, `emulator.lua`, `conf.lua`
3. **Subsystem Layer**: Modular components in `/modules/`
4. **Integration Layer**: OSC, MIDI, File I/O
5. **User Script Layer**: Sandboxed Lua scripts

---

## Technology Stack

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Framework** | LÖVE2D | 11.3+ | Game engine / windowing / graphics |
| **Language** | Lua (LuaJIT) | 5.1 | Application logic |
| **JSON** | dkjson | - | Configuration & state serialization |
| **MIDI** | luamidi.so | - | MIDI I/O (macOS arm64) |
| **OSC** | socket (implicit) | - | Open Sound Control protocol |
| **Graphics** | OpenGL (via LÖVE) | - | Display rendering |
| **Complex Math** | complex.lua | - | Complex number operations |

### Justification

- **LÖVE2D**: Cross-platform, built-in graphics/audio, Lua-native
- **Lua**: Lightweight, fast, same language as target hardware
- **JSON**: Human-readable configuration, easy editing
- **Modular Architecture**: Maintainability, testability, extensibility

---

## Architecture Patterns

### 1. Module Pattern

All modules follow Lua's module pattern with encapsulated state:

```lua
-- modules/example.lua
local M = {}  -- Module table

-- Private state
local privateVar = 0

-- Private functions
local function privateHelper()
    -- ...
end

-- Public interface
function M.publicFunction()
    return privateVar
end

return M
```

**Benefits**:
- Encapsulation
- Namespace management
- Clear public API

### 2. Dependency Injection

`emulator.lua` serves as a dependency injection container:

```lua
-- Initialize modules with their dependencies
scriptLoader.init({
    showNotification = notifications.showNotification,
    showErrorNotification = notifications.showErrorNotification,
    midiHandler = midiHandler
})
```

**Benefits**:
- Loose coupling
- Testability
- Flexibility

### 3. Observer Pattern (Implicit)

LÖVE2D's callback system acts as an observer:

```lua
function love.keypressed(key)
    -- Notify interested components
    if key == "f2" then
        PathInputDialog.open()
    end
end
```

### 4. Strategy Pattern

Signal modes (Bipolar, Unipolar, Clock) use strategy-like behavior:

```lua
if inputPolarity[i] == kBipolar then
    currentInputs[i] = (i - 1) * 0.2 - 1.0  -- -1 to +1
elseif inputPolarity[i] == kUnipolar then
    currentInputs[i] = (i - 1) * 0.2          -- 0 to +1
elseif inputClock[i] then
    currentInputs[i] = clockGateState and 1.0 or 0.0
end
```

### 5. Sandbox Pattern

User scripts execute in a controlled environment with limited API access:

```lua
local scriptEnv = {
    -- Whitelisted globals
    print = print,
    math = math,
    string = string,
    -- Custom APIs
    drawRectangle = display.drawRectangle,
    setParameter = parameterManager.setParameter
}
```

---

## Component Architecture

### Core Components

#### 1. Emulator (`emulator.lua`)
**Responsibility**: Central orchestrator

**Functions**:
- Initialize all subsystems
- Coordinate update loop
- Manage module dependencies

**Dependencies**: All modules

#### 2. Script Loader (`script_loader.lua`)
**Responsibility**: Script file management

**Functions**:
- Load Lua scripts from disk
- Hot-reload monitoring
- Sandboxed execution
- Error recovery

**Key Features**:
- File watching (checks every 2 seconds)
- Automatic reload on modification
- Preserves state across reloads

#### 3. Script Manager (`script_manager.lua`)
**Responsibility**: Script lifecycle management

**Functions**:
- Execute script callbacks
- Manage script state
- Handle control interactions

#### 4. Display (`display.lua`)
**Responsibility**: 256x64 OLED/LCD emulation

**Features**:
- Canvas-based rendering
- Scaled output (3x or 4x)
- Drawing primitives (rectangles, lines, text, circles)
- Electric blue tint simulation
- Pixel-perfect fonts

#### 5. Signal Processor (`signal_processor.lua`)
**Responsibility**: I/O signal generation and processing

**Functions**:
- Generate input signals (bipolar, unipolar, clock)
- Process script outputs
- Clock generation (30-200 BPM)
- Trigger pulse management

#### 6. I/O State (`io_state.lua`)
**Responsibility**: I/O mapping persistence

**Functions**:
- Save/load I/O mappings to `state.json`
- Track mapping changes
- Window position persistence

#### 7. UI State (`ui_state.lua`)
**Responsibility**: UI transitions and visual effects

**Functions**:
- Fade transitions
- Debug mode state

#### 8. Configuration (`config.lua`)
**Responsibility**: Application configuration

**Functions**:
- Load/save `config.json`
- Merge defaults with user config
- OSC, MIDI, UI mode settings

### UI Components

| Component | File | Purpose |
|-----------|------|---------|
| **Display** | `display.lua` | OLED screen emulation |
| **Controls** | `controls.lua` | Buttons, encoders, pots |
| **I/O Panel** | `io_panel.lua` | Drag-and-drop I/O mapping UI |
| **Parameter Knobs** | `parameter_knobs.lua` | Script parameter controls |
| **File Dialog** | `file_dialog.lua` | Native file browser |
| **Path Input** | `path_input_dialog.lua` | Keyboard path entry |
| **MIDI Input Dialog** | `midi_input_dialog.lua` | MIDI device selection |
| **MIDI Output Dialog** | `midi_output_dialog.lua` | MIDI output selection |
| **Minimal Mode** | `minimal_mode.lua` | Streamlined UI |
| **Notifications** | `notifications.lua` | Toast messages |

### Integration Components

| Component | File | Purpose |
|-----------|------|---------|
| **OSC Client** | `osc_client.lua` | Send OSC messages |
| **OSC Protocol** | `osc.lua` | OSC message encoding |
| **MIDI Handler** | `midi_handler.lua` | MIDI I/O management |

---

## Data Architecture

### State Persistence

#### `state.json`
**Purpose**: Runtime state (auto-saved)

**Structure**:
```json
{
  "scriptPath": "./test_script.lua",
  "minimalMode": false,
  "activeOverlay": "io",
  "inputs": {
    "1": 0.5,
    "2": -0.3
  },
  "outputs": {
    "1": 0.8
  },
  "inputAssignments": {
    "1": 1,
    "2": 2
  },
  "outputAssignments": {
    "1": 1
  },
  "scriptParameters": [
    {"value": 5, "displayValue": "5"}
  ],
  "window": {
    "x": 100,
    "y": 100,
    "width": 768,
    "height": 600
  }
}
```

#### `config.json`
**Purpose**: User preferences (manually editable)

**Structure**:
```json
{
  "osc": {
    "enabled": false,
    "host": "127.0.0.1",
    "port": 8000,
    "address": "/ch",
    "sendInterval": 0.001,
    "outputFormat": "single"
  },
  "midi": {
    "enabled": false,
    "selectedInput": -1,
    "selectedOutput": -1
  },
  "script": {
    "path": "test_script.lua"
  },
  "minimalMode": false
}
```

### In-Memory Data Structures

**Script I/O**:
```lua
-- Input assignments (script input → physical input)
inputAssignments = {
    [1] = 1,  -- Script input 1 → Physical input 1
    [2] = 3   -- Script input 2 → Physical input 3
}

-- Output assignments (script output → physical output)
outputAssignments = {
    [1] = 1,  -- Script output 1 → Physical output 1
    [2] = 2   -- Script output 2 → Physical output 2
}

-- Current signal values
currentInputs = { [1] = 0.5, [2] = -0.3, ... }
currentOutputs = { [1] = 0.8, [2] = 0.0, ... }
```

---

## Execution Flow

### Application Lifecycle

```
1. conf.lua runs FIRST
   ↓
2. LÖVE2D reads config (window size, modules, vsync)
   ↓
3. love.load() called → emulator.load()
   ↓
4. Emulator initializes all modules (dependency injection)
   ↓
5. Load saved state from state.json
   ↓
6. Load script from config.json (if exists)
   ↓
7. Enter main loop:
   ┌──────────────────────────┐
   │ love.update(dt)          │ → 60 FPS (vsync enabled)
   │  - Update time           │
   │  - Process inputs        │
   │  - Run script callbacks  │
   │  - Update signal processor│
   │  - Check file changes    │
   └──────────────────────────┘
           ↓
   ┌──────────────────────────┐
   │ love.draw()              │
   │  - Render display        │
   │  - Draw UI components    │
   │  - Draw dialogs          │
   └──────────────────────────┘
           ↓
   ┌──────────────────────────┐
   │ love.quit()              │
   │  - Save state.json       │
   └──────────────────────────┘
```

### Script Execution Flow

```
1. User presses F2 → PathInputDialog.open()
   ↓
2. User selects script file
   ↓
3. scriptLoader.loadScript(path)
   ↓
4. Create sandboxed environment
   ↓
5. Execute script file → returns script table
   ↓
6. Extract inputs, outputs, callbacks
   ↓
7. Call script.init(self) if exists
   ↓
8. Create default I/O mappings
   ↓
9. Save script path to config.json
   ↓
10. Enter processing loop:
    ┌──────────────────────────┐
    │ Each frame:              │
    │  - Read physical inputs  │
    │  - Map to script inputs  │
    │  - Call script.process() │
    │  - Map from script outputs│
    │  - Send OSC/MIDI         │
    │  - Render display        │
    └──────────────────────────┘
```

### Hot Reload Flow

```
1. File watcher checks script modification time (every 2s)
   ↓
2. Modification detected
   ↓
3. Call script.serialise() to save state
   ↓
4. Reload script file
   ↓
5. Create new sandboxed environment
   ↓
6. Execute script → get new script table
   ↓
7. Call script.init(self) with saved state
   ↓
8. Restore I/O mappings
   ↓
9. Display "Script Reloaded" notification
```

---

## Module Interactions

### Dependency Graph

```
emulator.lua (root)
├── script_loader.lua
│   ├── script_manager.lua
│   ├── notifications.lua
│   ├── midi_handler.lua
│   └── display.lua
├── signal_processor.lua
│   └── script_manager.lua
├── io_state.lua
├── ui_state.lua
├── config.lua
├── parameter_manager.lua
│   └── script_manager.lua
├── input_handler.lua
│   ├── io_panel.lua
│   ├── controls.lua
│   └── parameter_knobs.lua
├── window_manager.lua
├── osc_client.lua
│   └── osc.lua
├── midi_handler.lua
└── notifications.lua
```

**Key Principles**:
- **No circular dependencies**
- **Unidirectional data flow**
- **Dependencies injected via init()**

---

## State Management

### State Flow

```
User Action → Module → State Update → Save to JSON
                ↓
        Notify Dependent Modules
                ↓
        Update UI / Render
```

### State Synchronization

**When state changes**:
1. Module updates in-memory state
2. Mark state as "dirty" (`mappingsChanged = true`)
3. On next `saveIOState()` call, write to disk
4. Update UI to reflect new state

**Example**:
```lua
-- User clicks to create I/O mapping
function io_panel.mousepressed(x, y, button)
    -- Update in-memory mapping
    inputAssignments[scriptInput] = physicalInput

    -- Mark for save
    ioState.markChanged()

    -- UI auto-updates on next draw()
end
```

---

## Script Execution Environment

### Sandboxed API

User scripts have access to a **whitelist** of functions:

**Drawing Functions** (from `display.lua`):
- `drawRectangle()`, `fillRectangle()`
- `drawLine()`, `drawSmoothLine()`
- `drawBox()`, `drawSmoothBox()`
- `drawText()`, `drawTinyText()`
- `drawCircle()`, `fillCircle()`

**Parameter Functions** (from `parameter_manager.lua`):
- `setParameter(index, value)`
- `getParameter(index)`

**Constants**:
- `kCV`, `kGate`, `kTrigger` (input/output types)

**Standard Lua**:
- `math.*`, `string.*`, `table.*`
- `print()`

### Script Contract

Scripts must return a table with:

```lua
return {
    inputs = { kCV, kGate, kTrigger },  -- Input types
    outputs = { kCV, kGate },            -- Output types

    init = function(self, savedState)
        -- Optional: Initialize script
    end,

    process = function(self, inputs, outputs)
        -- Required: Main processing function
        -- Called every frame (~60 FPS)
        outputs[1] = inputs[1] * 0.5
    end,

    -- Optional callbacks:
    button = function(self) end,
    pot1Turn = function(self, direction) end,
    encoder1Push = function(self) end,
    gate = function(self, inputIndex, state) end,
    trigger = function(self, inputIndex) end,
    midiMessage = function(self, msg) end,
    serialise = function(self) return {...} end
}
```

---

## External Integrations

### OSC (Open Sound Control)

**Flow**:
```
Script Outputs → signal_processor.lua → osc_client.lua → Network
```

**Message Format**:
```
Address: /ch/1, /ch/2, ..., /ch/8
Values: float (-1.0 to +1.0 for CV, 0.0/1.0 for gates)
```

**Configuration**: `config.json` → `osc` section

### MIDI

**Input Flow**:
```
Hardware MIDI Device → luamidi.so → midi_handler.lua → script.midiMessage()
```

**Output Flow**:
```
Script → midi_handler.lua → luamidi.so → Hardware MIDI Device
```

**Device Selection**: F3 key → `midi_input_dialog.lua`

---

## UI Architecture

### UI Modes

**Full Mode**:
- Display (256x64 scaled)
- I/O Panel (drag-and-drop)
- Parameter Knobs
- Controls Panel OR I/O Panel (toggle)

**Minimal Mode**:
- Display only (scaled to fill window)

### Layout System

Window size calculated dynamically in `conf.lua`:

```lua
windowHeight = scaledDisplayHeight + scriptIOHeight +
               physicalIOHeight + paramKnobHeight + spacing
```

---

## Error Handling & Recovery

### Script Errors

1. **Execution protected by `pcall()`**
2. Error caught → Display notification
3. Script continues running (if possible)
4. Hot-reload preserves state

### File Errors

- Missing files → Use defaults
- Corrupt JSON → Fallback to defaults
- Write failures → Log to console

---

## Performance Considerations

- **Update rate**: 60 FPS (vsync enabled)
- **Hot-reload check**: Every 2 seconds
- **Canvas rendering**: GPU-accelerated
- **Memory profiling**: Available via `debug_utils.lua`

---

## Security & Sandboxing

### Script Isolation

- **No file I/O** in scripts
- **No network access** in scripts
- **Limited globals** (whitelisted only)
- **pcall protection** prevents crashes

---

*This architecture document was generated from an exhaustive analysis of the codebase.*
