-- constants.lua
-- Input types
kGate = "gate"       -- Gate input (high/low with rising/falling edge detection)
kTrigger = "trigger" -- Trigger input (momentary pulse)
kCV = "cv"           -- Control voltage input (continuous value)

-- Output types
kLinear = "linear"   -- Continuous output
kStepped = "stepped" -- Quantized/stepped output

-- Parameter types
kNone = "none"
kDb = "dB"
kDb_minInf = "dB_minInf"
kPercent = "percent"
kHz = "Hz"
kSemitones = "semitones"
kCents = "cents"
kMs = "ms"
kSeconds = "seconds"
kFrames = "frames"
kMIDINote = "midi_note"
kMillivolts = "millivolts"
kBPM = "bpm"

-- Input polarity
kBipolar = 0        -- -5V to +5V range
kUnipolar = 1       -- 0V to +10V range

-- Parameter value units
kVolts = 1          -- Volts (used in parameters)

-- Parameter scaling factors
kBy10 = 10          -- Scale by 10 for parameters (1 decimal place)
kBy100 = 100        -- Scale by 100 for parameters (2 decimal places)
kBy1000 = 1000      -- Scale by 1000 for parameters (3 decimal places)
