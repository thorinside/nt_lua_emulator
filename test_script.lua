-- Bouncy
-- Bouncing ball test script
--[[
MIT License

Copyright (c) 2025 Expert Sleepers Ltd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]] local time = 0
local f = 2 * math.pi
local x = 0
local y = 0
local dx = 5
local dy = 6.7
local bing = 0.0
local gateState = false
local p1 = 0.5
local p2 = 0.5
local p3 = 1.0

local toScreenX = function(x) return 1.0 + 2.5 * (x + 10.0) end
local toScreenY = function(y) return 12.0 + 2.5 * (10.0 - y) end

local lx = toScreenX(-10.0)
local cx = toScreenX(0.0)
local rx = toScreenX(10.0)
local ty = toScreenY(10.0)
local cy = toScreenY(0.0)
local by = toScreenY(-10.0)

return {
    name = 'bouncy',
    author = 'Expert Sleepers Ltd',
    init = function(self)
        local state = self.state or {}
        p1 = state.p1 or 0.5
        p2 = state.p2 or 0.5
        p3 = state.p3 or 1.0
        return {
            inputs = {kCV, kTrigger, kGate},
            outputs = 2,
            parameters = {
                {"Min X", -10, 10, state.minX or -10, kVolts} -- min, max, default, unit
                , {"Max X", -10, 10, state.maxX or 10, kVolts},
                {"Min Y", -100, 100, state.minY or -100, kVolts, kBy10} -- min, max, default, unit, scale
                , {"Max Y", -100, 100, state.maxY or 100, kVolts, kBy10},
                {"Edges", {"Bounce", "Warp"}, state.edges or 1} -- enums, default
            }
        }
    end,
    setupUi = function(self) return {p1, p2, p3} end,
    trigger = function(self, input)
        if input == 2 then
            x = 0
            y = 0
        end
    end,
    gate = function(self, input, rising)
        if input == 3 then gateState = rising end
    end,
    step = function(self, dt, inputs)
        x = x + dx * dt
        y = y + dy * dt
        if dx < 0 and x < self.parameters[1] then
            if self.parameters[5] == 1 then
                dx = -dx
            else
                x = x - self.parameters[1] + self.parameters[2]
            end
        elseif dx > 0 and x > self.parameters[2] then
            if self.parameters[5] == 1 then
                dx = -dx
            else
                x = x - self.parameters[2] + self.parameters[1]
            end
        end
        if dy < 0 and y < self.parameters[3] then
            if self.parameters[5] == 1 then
                dy = -dy
            else
                y = y - self.parameters[3] + self.parameters[4]
            end
        elseif dy > 0 and y > self.parameters[4] then
            if self.parameters[5] == 1 then
                dy = -dy
            else
                y = y - self.parameters[4] + self.parameters[3]
            end
        end
        time = time + dt
        local out = {}
        local t = f * time
        out[1] = x + math.sin(t)
        out[2] = y + inputs[1]
        return out
    end,
    pot1Turn = function(self, x) p1 = x end,
    pot2Turn = function(self, x) p2 = x end,
    pot3Turn = function(self, x) p3 = x end,
    encoder1Turn = function(self, x) bing = 0.5 end,
    encoder2Turn = function(self, x) bing = 0.5 end,
    pot3Push = function(self) bing = 0.5 end,
    encoder2Push = function(self) bing = 0.5 end,
    ui = function(self) return true end,
    draw = function(self)
        local alg = getCurrentAlgorithm()
        local p = getCurrentParameter(alg) - self.parameterOffset
        drawRectangle(cx, ty, cx, by, 2)
        drawRectangle(lx, cy, rx, cy, 2)
        local x1 = toScreenX(self.parameters[1])
        local x2 = toScreenX(self.parameters[2])
        local y1 = toScreenY(self.parameters[4])
        local y2 = toScreenY(self.parameters[3])
        drawRectangle(x1, y1, x2, y1, p == 4 and 15 or 2)
        drawRectangle(x1, y2, x2, y2, p == 3 and 15 or 2)
        drawRectangle(x1, y1, x1, y2, p == 1 and 15 or 2)
        drawRectangle(x2, y1, x2, y2, p == 2 and 15 or 2)
        local px = toScreenX(x)
        local py = toScreenY(y)
        drawSmoothBox(px - 1.0, py - 1.0, px + 1.0, py + 1.0, 15.0)

        if bing > 0.0 then
            drawText(100, 30, "bing!")
            bing = bing - 0.03
        end

        drawText(100, 50, gateState and "Open" or "Closed")
        drawText(100, 20, "p1: " .. p1)
        drawText(100, 30, "p2: " .. p2)
        drawText(100, 40, "p3: " .. p3)
        drawText(0, 10,
                 "0123456789-0123456789-0123456789-0123456789-01234567890")
        drawText(0, 20, "1")
        drawText(0, 30, "2")
        drawText(0, 40, "3")
        drawText(0, 50, "4")
        drawText(0, 60, "5")
        drawText(0, 70, "6")

        drawTinyText(0, 55,
                     "0123456789-0123456789-0123456789-0123456789-0123456789-0123456789-0123456789-0123456789")
        drawTinyText(60, 0, "1")
        drawTinyText(60, 6, "2")
        drawTinyText(60, 12, "3")
        drawTinyText(60, 18, "4")
        drawTinyText(60, 24, "5")
        drawTinyText(60, 30, "6")
        drawTinyText(60, 36, "7")
        drawTinyText(60, 42, "8")
        drawTinyText(60, 48, "9")
        drawTinyText(60, 54, "0")
        drawTinyText(60, 60, "1")
        drawTinyText(60, 66, "2")
        drawTinyText(60, 72, "3")
        drawTinyText(60, 78, "4")
        drawTinyText(60, 84, "5")
        drawTinyText(60, 90, "6")

        return true
    end,
    serialise = function(self)
        local state = {}
        state.minX = self.parameters[1]
        state.maxX = self.parameters[2]
        state.minY = self.parameters[3] * 10
        state.maxY = self.parameters[4] * 10
        state.edges = self.parameters[5]
        state.p1 = p1
        state.p2 = p2
        state.p3 = p3
        return state
    end
}
