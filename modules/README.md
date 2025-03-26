# NT Lua Emulator Modular Components

This directory contains modular components that have been extracted from the original monolithic `emulator.lua` file. The goal of this refactoring is to make the codebase more maintainable and easier to understand.

## Modules

### `script_loader.lua`
Handles loading and monitoring of Lua scripts. Provides:
- Script loading functionality for both absolute and relative paths
- Script hot-reloading detection
- Initialization of the global environment with required functions
- Script execution and error handling

### `script_manager.lua`
Manages script execution, callbacks, and control interactions. Provides:
- Script reload management 
- Control callback setup for script-to-UI interaction
- Script step and draw function calling
- Script I/O count determination

### `io_state.lua`
Manages the I/O state and persistence. Provides:
- Default I/O mappings creation
- State saving and loading from JSON
- Tracking of mapping changes

### `input_handler.lua`
Manages mouse and input event handling. Provides:
- Mouse event processing (click, drag, wheel)
- Double-click detection
- Parameter knob interaction
- Input mode cycling
- Drag-and-drop connection management

### `parameter_manager.lua`
Handles script parameter management and automation. Provides:
- Parameter value updates
- Parameter automation connections
- CV-to-parameter mapping
- Parameter reset functionality

### `signal_processor.lua`
Handles signal processing, clock generation, and trigger pulses. Provides:
- Clock signal generation based on BPM
- Input signal processing
- Gate and trigger handling
- Input/output signal routing
- CV scaling and polarity management

### `window_manager.lua`
Manages window sizing and display layout. Provides:
- Window resizing
- Display scaling
- Layout calculations
- Minimal mode management
- Overlay switching

### `ui_state.lua`
Manages UI state, transitions, and visual effects. Provides:
- Fade transitions
- Debug mode management
- UI state tracking

### `notifications.lua`
Manages the UI notifications system. Provides:
- Regular notification display
- Error notification display
- Animation and timing of notifications

## Integration

These modules are imported in the main `emulator.lua` file and integrated in a way that maintains backward compatibility. The refactoring process is incremental, allowing for more functionality to be moved into modules over time without disrupting the existing application.

## Future Refactoring

Additional modules that could be extracted in future refactoring:
- `ui_manager.lua` - Window and UI management
- `parameters.lua` - Parameter handling
- `input_controller.lua` - Input handling and event processing
- `clock.lua` - Clock and timing-related functionality

## Implementation Notes

The modules use a dependency injection pattern where each module is initialized with the dependencies it needs from other modules or the main emulator. This creates a clean separation of concerns while allowing modules to interact with each other when necessary. 