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
  standard/specific parameter lines, and algorithm UI placeholders.
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

- The emulator exposes all 64 logical bus indices. Its hardware panel still
  models the physical 12 inputs and 8 outputs; the remaining 44 aux buses read
  as 0 V unless supplied by an emulator backend and cannot be patched directly
  to a physical jack.
- I2C calls support both documented argument forms. Without an attached I2C
  backend, commands are no-ops and getters return the requested number of zero
  bytes.
- `drawAlgorithmUI`, `drawParameterLine`, and
  `drawStandardParameterLine` provide useful emulator representations rather
  than pixel-identical copies of proprietary firmware screens.
- `getFirmwareVersion()` reports `1, 17, 0, "1.17.0 (emulated)"` so scripts can
  feature-detect the emulated SDK baseline.
- MIDI destination masks are accepted, but output is sent to the emulator's
  selected MIDI port rather than separate breakout, Select Bus, USB, and
  internal transports.

## Automated checks

Run the conformance suite with either supported host runtime:

```sh
lua tests/test_nt_api.lua
lua tests/test_simulated_parameters.lua
lua tests/test_text_formatting.lua
lua tests/test_ui_script_callbacks.lua
lua tests/test_control_scheduler.lua
```

The same tests are also run under LuaJIT, matching the runtime used by LÖVE.
