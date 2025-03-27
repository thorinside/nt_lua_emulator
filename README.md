# Disting NT LUA Emulator

A comprehensive emulator for developing and testing Lua scripts for the Expert Sleepers Disting NT Eurorack module. This application provides a virtual environment that simulates the behavior of the physical hardware, allowing you to develop and test your scripts without the need for physical hardware.

## Features

### Core Functionality
- **Script Execution**: Load and run Lua scripts designed for the Disting NT
- **Simulated Display**: Full emulation of the 256x64 OLED/LCD screen
- **Input/Output Simulation**: 12 virtual inputs and 8 virtual outputs
- **Parameter Controls**: Virtual knobs, buttons, and encoders
- **State Saving**: Automatic preservation of your setup between sessions
- **OSC Integration**: Send and receive OSC messages for external control
- **Real-time Clock**: Built-in clock generator with adjustable BPM

### Input/Output Management
- **I/O Mapping**: Drag-and-drop interface for connecting script I/O to physical I/O
- **Multiple Input Modes**:
  - Bipolar (-5V to +5V)
  - Unipolar (0V to +10V)
  - Clock (generates gate signals based on BPM)
- **Input Scaling**: Adjust the scaling of each input independently
- **Signal Visualization**: Real-time visualization of signal values with voltage-based coloring

### User Interface
- **Minimal Mode**: Streamlined interface showing only the display
- **Full Mode**: Complete interface with I/O panels and parameter controls
- **I/O Panel**: Visual representation of script inputs/outputs and physical connections
- **Parameter Controls**: Interactive knobs for adjusting script parameters
- **Control Panel**: Virtual buttons, encoders, and potentiometers

## Getting Started

### Installation
1. Download [LÖVE](https://love2d.org/) (version 11.3 or higher)
2. Download the Disting NT LUA Emulator
3. Add love to your path:
   ```
   export PATH="$PATH:/Applications/love.app/Contents/MacOS"
   ```
4. Run the emulator using LÖVE:
   ```
   love path/to/nt_lua_emulator
   ```

### Loading a Script
1. Press **F2** to open the script selection dialog
2. Navigate to your script file (.lua)
3. Select the script and click "Open" or press Enter

### Basic Usage

#### Input/Output Mapping
1. Click and drag from a script input/output to a physical input/output to create a connection
2. Click on an existing connection to remove it
3. Input/output connections are automatically saved between sessions

#### Adjusting Input Modes
1. Left-click on a physical input to cycle through modes (Bipolar → Clock → Unipolar)
2. Input modes are indicated by colored rings:
   - No ring: Bipolar (-5V to +5V)
   - Yellow ring: Clock (generates gate signals)
   - Red ring: Unipolar (0V to +10V)
3. Double click an input to reset it to defaults.
4. An input connected to a kTrigger script input will generate a trigger on Left-Click.

#### Adjusting Parameters
1. Use the parameter knobs in the parameter panel to adjust script parameters
2. Parameters with different types (integer, float, enum) are handled automatically
3. Parameter values are automatically saved with your script state

#### Using Controls
1. The controls panel provides virtual buttons, encoders, and potentiometers
2. These controls interact with the script's corresponding callback functions
3. Control states are visualized in real-time

## Keyboard Shortcuts

- **F2**: Open script selection dialog
- **Alt+F4** / **Cmd+Q**: Quit the application
- **Arrow keys**: Navigate in file selection dialog
- **Enter**: Confirm selection in dialogs
- **Escape**: Cancel/close dialogs
- **Ctrl-O**: Enable OSC
- **Ctrl-D**: Enable Debug mode output
- **Ctrl-S**: Save the state

## OSC Integration

The emulator supports OSC (Open Sound Control) for external communication:

1. Enable/disable OSC in the configuration or Ctrl-O to toggle.
2. Default OSC settings:
   - Host: 127.0.0.1
   - Port: 8000
   - Address: /ch
3. Output values are sent as individual floating-point messages using the output channel numbers (/ch/1, /ch/2... bys for default)

## Developing Scripts

When writing scripts for the Disting NT:

1. Scripts should return a table with the following elements:
   - `process`: Main processing function called each frame
   - `inputs`: Table defining input types (kCV, kGate, kTrigger)
   - `outputs`: Table defining output types (kCV, kGate)
   - `init`: Initialization function (optional)
   - `gate`: Gate input handler (optional)

2. Available callback functions:
   - `button`: Handle button presses
   - `pot1Turn`, `pot2Turn`, `pot3Turn`: Handle potentiometer turns
   - `pot1Push`, `pot2Push`, `pot3Push`: Handle potentiometer pushes
   - `pot1Release`, `pot2Release`, `pot3Release`: Handle potentiometer releases
   - `encoder1Turn`, `encoder2Turn`: Handle encoder turns
   - `encoder1Push`, `encoder2Push`: Handle encoder pushes
   - `serialise`: Save script state

3. Drawing functions for the display:
   - `drawRectangle`, `drawBox`, `drawSmoothBox`
   - `drawLine`, `drawSmoothLine`
   - `drawText`, `drawTinyText`
   - `fillRectangle`
   - `drawCircle`, `fillCircle`

## Configuration

Settings are stored in `config.json` and include:

- OSC settings (host, port, enabled status)
- Window position and size
- UI mode (minimal or full)
- Active overlay (controls or I/O)

## Troubleshooting

- **Script Errors**: Error messages are displayed on screen and in the console
- **OSC Connectivity**: Check your firewall settings if OSC isn't working
- **Performance Issues**: Reduce the update rate in complex scripts

---

The Disting NT LUA Emulator is an open-source project designed to help developers create and test scripts for the Expert Sleepers Disting NT Eurorack module. It is not affiliated with Expert Sleepers.