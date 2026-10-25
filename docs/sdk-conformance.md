# Disting NT Lua SDK conformance

Baseline: Expert Sleepers Lua scripting manual v1.17, stored in
[`reference/disting_NT_lua_scripting_1.17.pdf`](reference/disting_NT_lua_scripting_1.17.pdf).

## Implemented surface

- Algorithm callbacks: `init`, `step` at 1 kHz, `trigger`, `gate`, `draw`,
  `draw` at 30 fps, custom UI callbacks, `setupUi`, `serialise`, and
  `midiMessage`.
- Algorithm discovery: `findAlgorithm`, `getAlgorithmCount`,
  `getAlgorithmName`, and `getCurrentAlgorithm`.
- Parameter access: `findParameter`, `focusParameter`, `getCurrentParameter`,
  `getParameter`, `getParameterCount`, `getParameterInfo`, `getParameterName`, `setParameter`, and
  `setParameterNormalized`.
- Drawing: integer and smooth primitives, both text fonts and alignments,
  enum/unit-aware parameter lines, and paged algorithm parameter views.
- Globals: bus voltage, 32-bit 600 MHz cycle count, emulated firmware version,
  MIDI output, I2C command/getter forms, display modes, and UI exit.
- All parameter unit and scaling constants documented in v1.17.
- Sparse output tables preserve outputs that are not returned by `step`,
  `trigger`, or `gate`.
- UI-script event callbacks use the firmware signature without an injected
  `self`; algorithm callbacks retain `self`.

## Parameter metadata (v1.19)

`getParameterInfo(algorithmIndex, parameterIndex)` returns `name`, `min`,
`max`, `def`, `unit`, `scaling`, and `enumStrings`, as documented in the
[v1.19 manual](https://www.expert-sleepers.co.uk/downloads/manuals/disting_NT_lua_scripting_1.19.pdf).
Use the same indices as `getParameter` or those returned by `findParameter`:
algorithm indices are zero-based; parameter indices include the script's
`parameterOffset`. Invalid or unmodeled indices return `nil`.

Ranges and defaults are raw integers, not scaled display values. `unit` and
`scaling` are numeric firmware metadata codes (for example, enum unit is 1,
volts is 13, and scaling is 0/1/2/3 for none/10/100/1000), not the emulator's
script-definition constants. `enumStrings` is a fresh array (empty for numeric
parameters). Script enum ranges retain their one-based script definitions.
The loaded script (algorithm 0) exposes Bypass at index 1, followed by its
own parameters at `parameterOffset + 1` (normally index 2). Enumerate with
`for index = 1, getParameterCount(0) do ... end`; `getParameterName`,
`getParameterInfo`, `findParameter`, `getParameter`, `setParameter`, and
`setParameterNormalized` use the same indices. Script parameter writes update
`self.parameters` and the existing parameter controls. Bypass does not occupy
an entry in `self.parameters`.

```lua
local alg = getCurrentAlgorithm()
local bypass = findParameter(alg, "Bypass")
print(getParameterInfo(alg, bypass).enumStrings[1]) -- Off
setParameter(alg, bypass, 1) -- bypass on
setParameter(alg, bypass, 0) -- resume
```

Bypass pauses `step`, `gate`, `trigger`, and `midiMessage`; outputs retain their
last values. Drawing and UI controls remain active so the script can unbypass
itself. This is a processing-pause simulation, not hardware audio routing.
Other firmware system parameters (program choice/routing) are not modeled;
scripts should retain the default `parameterOffset = 1` for a contiguous list.

Reverb, Delay, Filter, and VCO are representative parameter fixtures, not
DSP simulations or exact firmware parameter catalogs. Each includes Bypass,
realistic ranges/defaults, numeric units, and working clamped writes; examples
include scaled Decay/Pitch and enumerated Type/Waveform. Values reset on script
load. Load `scripts/parameter_info_demo.lua` with F2 to inspect and control the
loaded script's own Bypass, numeric, scaled, and enum parameters.

## Emulator boundaries

- `getBusVoltage(stage, busIndex)` reads physical bus numbers, not script I/O
  slots. Zero-based indices 0–11 read the live 12 input jacks, including their
  generators/scaling; 12–19 read the eight mapped physical outputs. At stage 0
  the output buses are 0 V (there is no upstream processor); stages 1 through
  `getAlgorithmCount()` see the loaded script's latest output. The fixture
  algorithms pass buses through without DSP. For example, script output 2
  patched to physical output 8 appears at `getBusVoltage(1, 19)`. Aux indices
  20–63 default to 0 V and can be injected by a host using
  `signalProcessor.setAuxBusVoltage(oneBasedBus, volts)`. Invalid indices
  return 0 V. This is a single-processor bus model, not a complete NT DSP chain.
- I2C supports both documented argument forms with a deterministic virtual
  register device at each address: `sendI2CCommand(address, register, data...)`
  writes sequential 8-bit registers; `sendI2CGetter(address, length, register)`
  reads them. Registers wrap at 256, unwritten registers read zero, and devices
  at different addresses are independent. Getter responses are capped at 1024
  bytes. State resets on script load; the last 64 transactions are retained for
  diagnostics. This is an emulator test protocol, **not** a simulation of a real
  module's I2C commands. Explicit backend hooks still override it.
- `drawAlgorithmUI` renders a six-parameter page with the algorithm name,
  selected parameter, formatted values, enum labels, and units. The standard
  parameter-line helpers use the same formatting. These are emulator views,
  not pixel-identical firmware GUIs, and `drawAlgorithmUI` does not recursively
  invoke the loaded script's own `draw` callback.
- `standardPot1Turn` selects a six-parameter page; `standardPot2Turn` selects
  within it; `standardPot3Turn` changes the selected value with directional
  soft takeover. Its first event anchors the position without jumping; later
  motion changes the value by the corresponding fraction of its range. Small
  movements accumulate for enums/integers. Parameter selection never jumps a
  value. Pot-push shortcuts and firmware-specific page layouts are not modeled.
- Scripts start in `ui` mode, showing their custom `draw` (or the parameter
  view if absent). `parameters`, `overview`, `meters`, and `menu` draw usable
  built-in views. Meters show all physical inputs/outputs; menu shows shortcuts
  and I2C activity. `exit()` switches to the normal parameter view without
  quitting LÖVE; `setDisplayMode("ui")` returns to the script's custom UI.
  Processing continues in every display mode. In built-in modes, pots operate
  the standard UI (overview pot 1 selects an algorithm). Otherwise a script's
  pot callbacks take priority, with standard behavior as the fallback.
- `getFirmwareVersion()` reports `1, 17, 0, "1.17.0 (emulated)"` so scripts can
  feature-detect the emulated SDK baseline.
- MIDI destination masks are honored as four logical routes: Breakout (1),
  Select Bus (2), USB (4), and Internal (8). F4 opens the output-port chooser
  plus a live per-destination monitor (count and latest hexadecimal bytes).
  Click/Enter on a route toggles selected-host-output versus monitor-only;
  route choices persist in `config.json`. External routes default to the
  selected port, Internal defaults to monitor-only with **no automatic
  loopback**. Multiple forwarded bits send only once to the shared host port.
  Monitoring works without native MIDI support or an open port; the last 128
  messages are retained by `midiHandler.getOutputHistory()`. This does not
  create four separate hardware transports.

## Interactive simulation demo

Load `scripts/api_simulation_demo.lua` with F2. It mirrors input 1 to output 1
with controllable Gain/Mode and discoverable Bypass. Pots select page/parameter
and adjust its value. Button 1 cycles display views, button 2 sends a MIDI
clock tick to all logical destinations (inspect with F4), button 3 writes and
reads a virtual I2C register, and button 4 exits the custom UI. Processing is
still paused by Bypass; display controls remain usable.

## Automated checks

Run the conformance suite with either supported host runtime:

```sh
lua tests/test_nt_api.lua
lua tests/test_simulated_parameters.lua
lua tests/test_api_simulation.lua
lua tests/test_midi_routing.lua
lua tests/test_text_formatting.lua
lua tests/test_ui_script_callbacks.lua
lua tests/test_control_scheduler.lua
```

The same tests are also run under LuaJIT, matching the runtime used by LÖVE.
