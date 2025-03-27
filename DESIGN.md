# Disting NT LUA Emulator - Technical Design

This document outlines the internal design and architecture of the Disting NT LUA Emulator, providing insights into how the different components work together, the data flow, and implementation details of key features.

## Architecture Overview

The Disting NT LUA Emulator is built on the [LÖVE](https://love2d.org/) framework, a 2D game engine for Lua. The architecture follows a modular design with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                      LÖVE Framework                          │
└─────────────────────────────────────────────────────────────┘
                               │
┌─────────────────────────────┼─────────────────────────────┐
│                        main.lua (Entry Point)              │
└─────────────────────────────┼─────────────────────────────┘
                               │
┌─────────────────────────────┼─────────────────────────────┐
│                     modules/emulator.lua                   │
│                     (Core Simulation Engine)               │
└─────────────────────────────┼─────────────────────────────┘
                               │
        ┌───────────┬───────────┼───────────┬───────────┐
        │           │           │           │           │
┌───────┴──────┐┌───┴───────┐┌───┴───────┐┌─┴─────────┐┌┴───────────┐
│    Script    ││   I/O     ││  Signal   ││ Parameter ││    UI      │
│  Management  ││ Management││ Processing││  Control  ││ Components │
└──────────────┘└───────────┘└───────────┘└───────────┘└────────────┘
```

## Core Components

### 1. Entry Point (`main.lua`)

This is the application's entry point that integrates with LÖVE's lifecycle hooks:
- `love.load()`: Initializes the emulator and path input dialog
- `love.update(dt)`: Updates the emulator state and UI elements
- `love.draw()`: Renders the display and UI
- Various event handlers (mouse/keyboard/etc.)

### 2. Core Emulation Engine (`modules/emulator.lua`)

The central orchestrator that ties together all components and manages the overall state:
- Initializes and manages all subsystems
- Handles script loading and execution
- Coordinates input/output processing
- Manages the UI state and overlays

### 3. Script Management

- **Script Loader** (`modules/script_loader.lua`): Handles loading, executing and monitoring Lua scripts
- **Script Manager** (`modules/script_manager.lua`): Manages script lifecycle, reloading, and state serialization

### 4. I/O Management

- **I/O Panel** (`modules/io_panel.lua`): Provides the UI for I/O mapping and visualization
- **I/O State** (`modules/io_state.lua`): Manages persistence of I/O configurations
- **Signal Processor** (`modules/signal_processor.lua`): Handles signal generation, processing, and conversion

### 5. Parameter Management

- **Parameter Manager** (`modules/parameter_manager.lua`): Handles script parameters
- **Parameter Knobs** (`modules/parameter_knobs.lua`): Provides UI for parameter adjustment

### 6. UI Components

- **Display** (`modules/display.lua`): Emulates the hardware display
- **Controls** (`modules/controls.lua`): Emulates hardware controls (buttons, encoders, etc.)
- **Window Manager** (`modules/window_manager.lua`): Manages window modes and overlays
- **Minimal Mode** (`modules/minimal_mode.lua`): Provides a simplified UI mode
- **Notifications** (`modules/notifications.lua`): Handles on-screen notifications
- **Path Input Dialog** (`modules/path_input_dialog.lua`): File selection interface
- **File Dialog** (`modules/file_dialog.lua`): Advanced file browser functionality

### 7. Supporting Modules

- **OSC Client** (`modules/osc_client.lua`): Open Sound Control implementation
- **Debug Utils** (`modules/debug_utils.lua`): Debugging utilities
- **Helpers** (`modules/helpers.lua`): Shared utility functions
- **Constants** (`modules/constants.lua`): Global constants and enumerations
- **Config** (`modules/config.lua`): Configuration management

## Data Flow

### Script Execution Flow

1. User loads a script through the UI or at startup
2. `modules/script_loader.lua` loads and initializes the script
3. The script's `init()` function is called if available
4. `modules/emulator.lua` sets up I/O mappings based on script definitions
5. For each frame:
   - Input values are processed by `modules/signal_processor.lua`
   - Script's `process()` function receives input values and computes outputs
   - Output values are routed back through the signal processor
   - Display is updated if the script uses drawing functions
   - OSC messages are sent if enabled

### Input Processing Flow

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│ User Input or │     │    Signal     │     │ Script Input  │     │    Script     │
│Generated Signal│────▶│   Processor  │────▶│   Mappings    │────▶│   Process()   │
└───────────────┘     └───────────────┘     └───────────────┘     └───────────────┘
```

### Output Processing Flow

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│    Script     │     │ Script Output │     │    Signal     │     │ Display, OSC  │
│   Process()   │────▶│   Mappings    │────▶│   Processor   │────▶│   & UI Update │
└───────────────┘     └───────────────┘     └───────────────┘     └───────────────┘
```

## State Management

The emulator maintains state across sessions through several files:

1. **state.json**: Stores script path, I/O mappings, window position, and UI state
2. **config.json**: Stores global configuration like OSC settings

State saving occurs:
- Automatically when I/O mappings change
- When the application closes
- When a new script is loaded
- Manually when triggered by the user

## Key Feature Implementations

### Script Hot-Reloading

Script hot-reloading is implemented in `modules/script_loader.lua` by:
1. Tracking the last modification time of the script file
2. Periodically checking if the file has been modified
3. When a change is detected, reloading the script while preserving I/O mappings

```lua
-- In modules/script_loader.lua
function M.checkScriptModified(path)
    -- Check if file modification time has changed
    -- If changed, reload the script
end
```

### I/O Mapping System

The I/O mapping system uses a drag-and-drop interface implemented in `modules/io_panel.lua`:
1. Mouse events are tracked to detect drag operations
2. When a connection is made, it's stored in `scriptInputAssignments` or `scriptOutputAssignments`
3. These mappings are used by the signal processor to route signals

```lua
-- Example I/O mapping from scriptInputAssignments
{
    [1] = 3,  -- Script input 1 is connected to physical input 3
    [2] = 7,  -- Script input 2 is connected to physical input 7
    -- ...
}
```

### Signal Processing and Input Modes

The signal processor (`modules/signal_processor.lua`) supports different input modes:
1. **Bipolar**: Simulates -5V to +5V range
2. **Unipolar**: Simulates 0V to +10V range
3. **Clock**: Generates gate signals based on BPM

For each input:
1. Mode is determined by checking `inputClock` and `inputPolarity` flags
2. Signal is generated or processed accordingly
3. Values are scaled based on `inputScaling`

```lua
-- In modules/signal_processor.lua
function M.updateInputs(scriptInputAssignments, script)
    -- For each input, generate appropriate signal based on mode
    if inputClock[i] then
        -- Generate clock signal based on BPM
    elseif inputPolarity[i] == kBipolar then
        -- Generate bipolar signal (-5V to +5V)
    else
        -- Generate unipolar signal (0V to +10V)
    end
end
```

### OSC Integration

OSC (Open Sound Control) support is implemented in `modules/osc_client.lua` and `modules/osc.lua`:
1. UDP sockets are used for communication
2. Output values are automatically sent as OSC messages when enabled
3. Custom address patterns can be configured

```lua
-- In modules/osc_client.lua
function osc_client.sendValue(outputIndex, value)
    -- Format as OSC message and send via UDP
    client:send("/dnt/" .. outputIndex, value)
end
```

### Minimal Mode

The minimal mode (`modules/minimal_mode.lua`) provides a streamlined UI:
1. Only shows the display without I/O panels or controls
2. Can be toggled from the UI or via configuration
3. State is preserved between sessions

## Script Environment

When a script is loaded, it runs in a protected environment with access to:

1. **Drawing Functions**:
   - `drawRectangle`, `drawLine`, `drawText`, etc.
   - These functions modify the virtual display

2. **Input/Output Access**:
   - Through the `process(inputs, outputs)` function
   - Script receives mapped input values and produces output values

3. **Control Callbacks**:
   - `button`, `pot1Turn`, `encoder1Push`, etc.
   - Called when user interacts with virtual controls

4. **Parameter Access**:
   - `setParameter`, `getParameter`
   - Used to read and modify script parameters

5. **Utility Functions**:
   - `getBusVoltage`: Get voltage on a physical input
   - `focusParameter`: Set UI focus to a parameter
   - Various coordinate conversion functions

Example script structure:
```lua
return {
    -- I/O definitions
    inputs = {kCV, kGate, kTrigger},
    outputs = {kCV, kCV},
    
    -- Initialization
    init = function(self)
        self.state = {counter = 0}
        return {
            parameters = {
                {
                    name = "Scale",
                    type = "float",
                    min = 0.0,
                    max = 10.0,
                    default = 5.0
                }
            }
        }
    end,
    
    -- Main processing function
    process = function(self, inputs, outputs)
        outputs[1] = inputs[1] * 2
        outputs[2] = math.sin(self.state.counter / 10) * 5
        self.state.counter = self.state.counter + 1
        
        -- Draw to the display
        drawRectangle(10, 10, 100, 30, 15)
        drawText(15, 20, "Hello World!", 15)
    end,
    
    -- Control callback
    button = function(self, button, pressed)
        if pressed then
            self.state.counter = 0
        end
    end,
    
    -- State serialization
    serialise = function(self)
        return self.state
    end
}
```

## Extension Points

The emulator is designed to be extensible through several mechanisms:

1. **New Script Types**: New script capabilities can be added by extending the script loader

2. **Additional UI Overlays**: New UI modes can be implemented similarly to minimal mode

3. **Plugin System**: The modular architecture allows for future plugin support

4. **Alternative I/O Methods**: Beyond OSC, other protocols could be implemented

## Code Style and Patterns

The codebase follows these patterns:

1. **Module Pattern**: Each Lua file returns a table or function
   ```lua
   local M = {}
   -- Module implementation
   return M
   ```

2. **Dependency Injection**: Components receive dependencies through initialization
   ```lua
   function M.init(dependencies)
      -- Store dependencies for later use
      return M
   end
   ```

3. **Event-Based Communication**: Components often communicate via callbacks

4. **State Encapsulation**: Each module manages its own state

## Conclusion

The Disting NT LUA Emulator is built on a robust, modular architecture that effectively simulates the hardware environment for script development. Its design emphasizes clean separation of concerns, providing a maintainable codebase that can be extended for future features and enhancements. 