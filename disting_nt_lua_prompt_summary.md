# Disting NT Lua Scripting Manual v1.7 — LLM Prompt Summary

> **Source:** Expert Sleepers Disting NT Lua scripting manual v1.7 citeturn0file0

## 1. Context
- Embedded **Lua 5.4.6** environment on the Disting NT
- Single global Lua instance: global variables persist across all scripts

## 2. Script API

### 2.1 Skeleton
```lua
return {
  name = "Name",
  author = "Author",
  init = function(self) ... end,
  step = function(self, dt, inputs) ... end,
  trigger = function(self, input) ... end,        -- optional
  gate = function(self, input, rising) ... end,   -- optional
  draw = function(self) ... end,                  -- optional
  ui = function(self) return true end,            -- optional
  serialise = function(self) return state end      -- optional
}
```

### 2.2 init(self)
- **Returns** a table with:
  - `inputs` : `<int>` or `{ kType, ... }`
  - `outputs`: `<int>` or `{ kType, ... }`
  - `parameters`: list of parameter specs
  - `inputNames`, `outputNames`: override defaults
- **Input types**: `kCV`, `kTrigger`, `kGate`
- **Output types**: `kStepped`, `kLinear`
- **Parameters**:
  - Numeric: `{ "Name", min, max, default, unit [, scale] }`
  - Enum:    `{ "Name", { "Opt1", "Opt2" }, defaultIndex }`

### 2.3 step(self, dt, inputs)
- **Called** every 1 ms
- `dt`: time delta in seconds
- `inputs`: 1-based array of bus voltages
- **Returns**: table of outputs (sparse updates allowed)

### 2.4 trigger(self, input) & gate(self, input, rising)
- **Hardware-monitored events** for efficiency
- `trigger`: fires on trigger input
- `gate`: fires on gate input changes (`rising`: boolean)
- **Returns**: table of outputs

### 2.5 draw(self)
- **Called** 30 fps
- Use drawing API (§5)
- **Return** `true` to suppress standard parameter line

### 2.6 ui(self) & Handlers
- **Return** `true` to override standard UI
- Define handlers:
  - Pots: `pot1Turn(x)`, `pot2Turn(x)`, `pot3Turn(x)`
  - Encoders: `encoder1Turn(dir)`, `encoder2Turn(dir)`
  - Button/Encoder pushes/releases
- `setupUi(self)`: return initial pot positions (0.0–1.0)

### 2.7 serialise(self)
- **Return** JSON-friendly table
- Stored as `self.state` before `init`

## 3. UI Script API
- Structure: `init()`, event handlers, `draw()`
- Bind controls:
  - `findAlgorithm(name)`, `findParameter(alg, name)`
  - `setParameter`, `setParameterNormalized`, `focusParameter`
- Exit script: `exit()`

## 4. Console Tool
- **Browser-based** MIDI SysEx REPL
- Inspect globals, test syntax, install scripts on-the-fly

## 5. Drawing API
- **Display**: 256×64 px, 16 shades (0–15)
- **Text**:
  - `drawText(x, y, str[, color])`
  - `drawTinyText(x, y, str)`
- **Primitives**:
  - `drawBox(x1, y1, x2, y2, color)`
  - `drawRectangle(x1, y1, x2, y2, color)`
  - `drawLine(x1, y1, x2, y2, color)`
  - `drawSmoothLine(x1, y1, x2, y2, color)`
- **Helpers**:
  - `drawStandardParameterLine()`
  - `drawParameterLine(alg, param, yOffset)`
  - `drawAlgorithmUI(alg)`

## 6. Utility Functions
- `getBusVoltage(alg, bus)`
- `getCurrentAlgorithm()`, `getCurrentParameter(alg)`
- `getParameter(alg, param)`, `setParameter(alg, param, value)`
- `setParameterNormalized(alg, param, normValue)`
- UI: `standardPot1Turn(value)`, etc.
- Lookup: `findAlgorithm(name)`, `findParameter(alg, name)`