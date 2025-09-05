# Technical Stack

> Last Updated: 2025-09-05
> Version: 1.0.0

## Application Framework

- **Framework:** LÖVE2D (Love2D)
- **Version:** 11.3+
- **Language:** Lua
- **Architecture:** Event-driven modular design

## Core Dependencies

### Runtime Libraries
- **dkjson** - JSON parsing and serialization (lib/dkjson.lua)
- **luamidi.so** - Native MIDI hardware integration
- **Built-in LÖVE2D modules** - Graphics, audio, input, filesystem

### Development Tools
- **No formal build system** - Direct LÖVE2D execution
- **No testing framework** - Manual testing and validation
- **No linting** - Code quality through review and standards

## Architecture Overview

### Modular Component System
The codebase uses a 30+ module architecture with clear separation of concerns:

```
main.lua                    # LÖVE2D integration entry point
modules/emulator.lua        # Core orchestration engine
modules/
├── script_loader.lua       # Sandboxed script execution
├── script_manager.lua      # Lifecycle and state management  
├── io_panel.lua           # Drag-drop I/O mapping UI
├── signal_processor.lua   # Signal generation and processing
├── display.lua            # 256x64 hardware display emulation
├── controls.lua           # Virtual buttons and encoders
├── parameter_knobs.lua    # Script parameter UI controls
└── io_state.lua          # I/O configuration persistence
```

### Data Persistence
- **config.json** - Application settings (OSC, UI mode preferences)
- **state.json** - Runtime state (script path, I/O mappings, window geometry)
- **Automatic persistence** - State saves on changes and application exit

## Signal Processing Pipeline

### Input Path
1. **Signal Sources**: Generated (sine, square, clock) or external (MIDI, OSC)
2. **Signal Processor**: Type conversion and scaling (bipolar ±5V, unipolar 0-5V)
3. **I/O Mapping**: Virtual routing to script input channels
4. **Script Sandbox**: Protected execution in isolated Lua environment

### Output Path
1. **Script Processing**: User code generates output values
2. **I/O Mapping**: Virtual routing from script output channels  
3. **Signal Processor**: Visualization and external messaging
4. **OSC Integration**: Network messages to external applications (127.0.0.1:8000)

## Script Execution Environment

### Sandboxing Strategy
- **Protected pcall()** - Prevents script crashes from affecting emulator
- **Limited global access** - Restricted to safe Lua standard library
- **Hardware API emulation** - Full NT API 1.9.0 function set
- **Hot-reload capability** - File system monitoring for automatic updates

### API Surface
Scripts interface through:
```lua
-- Drawing functions
drawRectangle(x, y, width, height, filled)
drawText(x, y, text, size, color)

-- I/O processing  
function process(inputs, outputs)
  -- Real-time signal processing
end

-- Control callbacks
function button1(pressed)
  -- Hardware button emulation
end

function pot1Turn(value)
  -- Potentiometer input
end
```

## External Integrations

### OSC (Open Sound Control)
- **Protocol:** UDP over IP
- **Default endpoint:** 127.0.0.1:8000
- **Message format:** `/ch/[channel_number]` with float32 value
- **Toggle:** Ctrl-O keyboard shortcut

### MIDI Integration
- **Native library:** luamidi.so (platform-specific)
- **Device selection:** F4 hardware keyboard shortcut
- **Real-time processing:** Low-latency input/output
- **Cross-platform support:** macOS, Linux, Windows

## Development Workflow

### No-Build Philosophy
The project deliberately avoids complex build systems:
- **Direct execution:** `love /path/to/project`
- **Immediate feedback:** Changes visible on file save
- **Zero configuration:** Works out-of-the-box with LÖVE2D installation

### Quality Assurance
- **Manual testing** - Interactive validation of all features
- **Hardware comparison** - Regular testing against physical NT module
- **Community validation** - User feedback and bug reports
- **Code review** - Careful maintenance of "vibe coded" architecture

## Platform Support

### Supported Platforms
- **macOS** - Primary development and testing platform
- **Linux** - Full feature compatibility
- **Windows** - Complete functionality with luamidi.so

### System Requirements
- **LÖVE2D 11.3+** - Core framework requirement
- **OpenGL 2.1+** - Graphics rendering
- **Audio device** - Optional for sound generation
- **MIDI hardware** - Optional for external control

## Performance Characteristics

### Real-time Constraints
- **60 FPS rendering** - Smooth UI and signal visualization
- **Low-latency processing** - Minimal delay between input and output
- **Memory efficiency** - Lua garbage collection tuning
- **CPU optimization** - Efficient signal processing algorithms

### Scalability Limits
- **Single-threaded execution** - LÖVE2D/Lua constraint
- **Limited by script complexity** - User code performance impact
- **Memory bounded** - Lua heap size limitations
- **File I/O dependent** - Hot-reload performance varies by system