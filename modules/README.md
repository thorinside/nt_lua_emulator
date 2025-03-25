# NT Lua Emulator Modular Components

This directory contains modular components that have been extracted from the original monolithic `emulator.lua` file. The goal of this refactoring is to make the codebase more maintainable and easier to understand.

## Modules

### `script_loader.lua`
Handles loading and monitoring of Lua scripts. Provides:
- Script loading functionality for both absolute and relative paths
- Script hot-reloading detection
- Initialization of the global environment with required functions
- Script execution and error handling

### `io_state.lua`
Manages the I/O state and persistence. Provides:
- Default I/O mappings creation
- State saving and loading from JSON
- Tracking of mapping changes

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

The current implementation uses a delegation pattern where the main emulator file delegates specific tasks to the appropriate modules while maintaining a consistent interface for the rest of the application. 