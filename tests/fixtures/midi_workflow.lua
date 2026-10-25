-- Used by the real LÖVE UI regression harness, not loaded by normal users.
return {
    name = "MIDI Workflow Test",
    init = function(self)
        self.elapsed, self.stream, self.stepMessages = 0, false, 0
        return {inputs = {}, outputs = {},
            parameters = {{"MIDI channel", 0, 16, 1}},
            midi = {channelParameter = 1,
                messages = {"note", "cc", "bend", "aftertouch", "poly pressure", "program change"}}}
    end,
    step = function(self, dt)
        self.elapsed = self.elapsed + dt
        if self.stream and self.elapsed >= 0.02 then
            self.elapsed = 0
            self.stepMessages = self.stepMessages + 1
            sendMIDI(4, 0xB0, 1, self.stepMessages % 128)
        end
    end,
    button1Push = function(self) self.stream = not self.stream end,
    button2Push = function(self) sendMIDI(4, 0x90, 60, 100) end,
    button2Release = function(self) sendMIDI(4, 0x80, 60, 0) end,
    pot1Turn = function(self, value) sendMIDI(2, 0xB0, 7, math.floor(value * 127)) end,
    encoder1Turn = function(self, delta) sendMIDI(1, 0xB0, 10, math.max(0, math.min(127, 64 + delta))) end,
    button3Push = function(self)
        sendMIDI(0, 0xF8)
        sendMIDI(16, 0xF8)
    end,
    midiMessage = function(self, message)
        local kind = math.floor(message[1] / 16)
        if kind == 12 or kind == 13 then sendMIDI(8, message[1], message[2])
        else sendMIDI(8, message[1], message[2], message[3]) end
    end,
    draw = function(self)
        drawText(1, 10, "MIDI workflow: A note, Q stream, F diagnostics")
        drawText(1, 24, "F4 routing; F5 live log (controls stay active)")
        return true
    end
}
