-- control_scheduler.lua
-- Fixed-rate scheduler for the disting NT's 1 kHz Lua control callback.
local M = {}

function M.new(interval, maxSteps)
    local scheduler = {
        interval = interval or 0.001,
        maxSteps = maxSteps or 100,
        accumulator = 0
    }

    function scheduler:reset()
        self.accumulator = 0
    end

    function scheduler:advance(dt, callback)
        if type(dt) ~= "number" or dt <= 0 then return 0 end
        self.accumulator = math.min(self.accumulator + dt,
                                    self.interval * self.maxSteps)
        local steps = math.min(
                          math.floor((self.accumulator + self.interval * 1e-9) /
                                         self.interval), self.maxSteps)
        for _ = 1, steps do
            callback(self.interval)
        end
        self.accumulator = self.accumulator - steps * self.interval
        if math.abs(self.accumulator) < self.interval * 1e-9 then
            self.accumulator = 0
        end
        return steps
    end

    return scheduler
end

return M
