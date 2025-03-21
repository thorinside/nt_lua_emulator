# CLAUDE.md - LUA Dev Reference

## Runtime Environment
- Engine: LÖVE framework (2D game framework)
- Run scripts: `love .` (from project root)
- Test a specific script: `love . test_script.lua`

## Hot-Reload Features
- Auto-reload: Enabled by default, watches for changes in test_script.lua
- Keyboard shortcuts:
  - `Ctrl+R`: Force reload script
  - `Ctrl+H`: Toggle hot reload on/off
  - `Ctrl+O`: Toggle OSC on/off  
  - `Ctrl+D`: Toggle debug mode
  - `Ctrl+S`: Manually save I/O mappings to state.json
  - `Alt+F4` or `Cmd+Q`: Quit application

## State Management
- I/O connections are automatically saved to `state.json` when changed
- Input modes (gate/clock, unipolar, bipolar) and scaling are also saved
- OSC connection state (enabled/disabled) is preserved between sessions
- When starting with the same script, connections and input settings are restored
- If no saved state exists, default mappings are created (1:1 connections)
- Debug messages show when state is saved or loaded
- Use `Ctrl+S` to manually save state

## Input Types
- `kGate`: Gate inputs receive clock signals and trigger gate function on rising/falling edges
- `kTrigger`: Trigger inputs respond to user clicks, firing the trigger function once
- `kCV`: CV inputs pass continuous values to the script's step function

## Parameter Automation
- Drag a physical input to a parameter knob to connect them
- The input's value (0-10V) will control the parameter value
- Connected parameters show blue rings and "CV#" indicator
- Double-click on a parameter knob to remove automation

## Connections
- Double-click on script inputs/outputs to clear their connections
- Right-click on physical inputs to toggle clock mode
- Use drag and drop to create connections

## Code Style Guidelines
- **Naming**: snake_case for variables, functions, modules (e.g., `local my_variable`, `function do_stuff()`)
- **Modules**: Each file should return a single table or function
- **Indentation**: 4 spaces (no tabs)
- **Comments**: Use `--` for single-line comments, `--[[...]]` for multi-line
- **Imports**: Use `require("module_name")` (no file extension)
- **Constants**: Define in uppercase with underscores (e.g., `MY_CONSTANT`)
- **Errors**: Use Lua's `error()` function for exceptional cases

## Project Structure
- `main.lua`: Entry point, LÖVE lifecycle hooks
- `emulator.lua`: Core simulation environment
- `constants.lua`: Shared constants
- `helpers.lua`: Utility functions
- `test_script.lua`: Example script (modify or create new ones)

## Best Practices
- Use local variables whenever possible
- Add detailed comments for complex algorithms
- Use explicit `nil` checks instead of truthiness (`if x ~= nil then`)
- Prefer table constructors over repetitive assignments