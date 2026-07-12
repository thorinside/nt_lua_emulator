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
  `getParameter`, `getParameterCount`, `getParameterName`, `setParameter`, and
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

## Emulator boundaries

- The emulator exposes the NT's 28 logical bus indices. Its hardware panel
  still models the physical 12 inputs and 8 outputs; unrepresented logical
  buses read as 0 V and cannot be patched to a physical jack.
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
lua tests/test_text_formatting.lua
lua tests/test_ui_script_callbacks.lua
lua tests/test_control_scheduler.lua
```

The same tests are also run under LuaJIT, matching the runtime used by LÖVE.
