-- Return Nil Test
-- Test script for testing nil return handling in step function
local time = 0
local counter = 0
local switchMode = false

return {
    name = 'Return Nil Test',
    author = 'Test Author',

    init = function(self)
        print("Return nil test script initialized")
        return {
            inputs = 1, -- One input for switching modes
            outputs = 2, -- Two outputs to test
            parameters = {
                {"Test Mode", {"Table", "Nil", "Empty"}, 1} -- Parameter to select return type
            }
        }
    end,

    step = function(self, dt, inputs)
        time = time + dt
        counter = counter + 1

        -- Every ~1 second (1000 steps @ 1ms each), log what's happening
        if counter >= 1000 then
            counter = 0
            print("Step function - mode:", self.parameters[1])
        end

        -- Check if input voltage crossed 2.5V threshold to change mode
        if inputs[1] > 2.5 and not switchMode then
            switchMode = true
            self.parameters[1] = (self.parameters[1] % 3) + 1
            print("Switched to mode:", self.parameters[1])
        elseif inputs[1] <= 2.5 and switchMode then
            switchMode = false
        end

        -- Generate sine wave outputs
        local out1 = 5 * math.sin(time * 2)
        local out2 = 5 * math.cos(time * 3)

        -- Based on mode parameter, return different values
        if self.parameters[1] == 1 then
            -- Mode 1: Return a table (normal operation)
            return {out1, out2}
        elseif self.parameters[1] == 2 then
            -- Mode 2: Return nil explicitly
            return nil
        else
            -- Mode 3: Return empty table
            return {}
        end
    end,

    draw = function(self)
        -- Draw mode information
        local modes = {"Table", "Nil", "Empty"}
        local modeText = "Mode: " .. modes[self.parameters[1]]
        drawText(10, 10, modeText, 15)

        -- Display explanation based on current mode
        if self.parameters[1] == 1 then
            drawText(10, 30, "Normal operation with table return", 12)
            drawText(10, 40, "Outputs should update normally", 12)
        elseif self.parameters[1] == 2 then
            drawText(10, 30, "Explicit nil return", 12)
            drawText(10, 40, "Should preserve previous outputs", 12)
        else
            drawText(10, 30, "Empty table return", 12)
            drawText(10, 40, "Outputs should maintain previous values", 12)
        end

        return true
    end
}
