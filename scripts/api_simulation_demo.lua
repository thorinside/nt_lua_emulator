-- F2: load this script. Pots: page / parameter / value (directional takeover).
-- Buttons: 1 display mode, 2 MIDI test, 3 I2C register test, 4 exit UI.
-- Input 1 is multiplied by Gain and sent to output 1; inspect the Meters view.
local modes = {"ui", "parameters", "overview", "meters", "menu"}
local modeIndex, registerValue = 1, 0
return {
    name = "API Simulation Demo",
    init = function(self)
        return {
            inputs = {kCV}, outputs = {kCV},
            parameters = {
                {"Gain", 0, 200, 100, kNone, kBy100},
                {"Mode", {"Normal", "Inverted"}, 1}
            }
        }
    end,
    step = function(self, dt, inputs)
        local sign = self.parameters[2] == 2 and -1 or 1
        return {(inputs[1] or 0) * self.parameters[1] * sign}
    end,
    pot1Turn = function(self, value) standardPot1Turn(value) end,
    pot2Turn = function(self, value) standardPot2Turn(value) end,
    pot3Turn = function(self, value) standardPot3Turn(value) end,
    button1Push = function(self)
        modeIndex = modeIndex % #modes + 1
        setDisplayMode(modes[modeIndex])
    end,
    button2Push = function(self)
        sendMIDI(0xF, 0xF8) -- One clock tick, visible per destination in F4.
    end,
    button3Push = function(self)
        registerValue = (registerValue + 1) % 256
        sendI2CCommand(0x32, {0x10, registerValue})
        print("Virtual I2C register:", sendI2CGetter(0x32, 1, 0x10)[1])
    end,
    button4Push = function(self) exit() end,
    draw = function(self)
        drawAlgorithmUI(self.algorithmIndex)
        drawTinyText(1, 62, "B1 Mode  B2 MIDI  B3 I2C  B4 Exit  F4 Monitor")
        return true
    end
}
