-- mod_julia
--[[
  A modulation source based on a bouncing ball traversing a Julia set.

  Controls:
  - Input 1: Trigger input to reset ball position and velocity (also via Encoder 2 Push)
  - Pot 1: Iterations (complexity of the Julia set)
  - Pot 2: Zoom (magnification of the Julia set)
  - Pot 3: Ball Speed
  - Encoder 1 Turn: Offset X (pan Julia set horizontally)
  - Encoder 1 Push: (Not assigned)
  - Encoder 2 Turn: Offset Y (pan Julia set vertically)
  - Encoder 2 Push: Reset Ball (same as Input 1 trigger)
--]] local Julia = {
    c_real = -0.7,
    c_imag = 0.27015,
    max_iterations = 64, -- Updated by parameter
    zoom = 1.0, -- Updated by parameter
    offsetX = 0.0, -- Updated by parameter
    offsetY = 0.0, -- Updated by parameter
    screenWidth = 256,
    screenHeight = 64,
    rect_w = 2,
    rect_h = 2
}

-- Calculates iterations for a point in the Julia set
Julia.calculate_iterations = function(zx, zy, cr, ci, max_iter)
    local iter = 0
    while zx * zx + zy * zy <= 4 and iter < max_iter do
        local xtemp = zx * zx - zy * zy + cr
        zy = 2 * zx * zy + ci
        zx = xtemp
        iter = iter + 1
    end
    return iter
end

-- Pre-calculates the Julia set visualization as a table of rectangles
Julia.calculate_rects = function()
    local rects = {}
    local num_rects_x = Julia.screenWidth / Julia.rect_w
    local num_rects_y = Julia.screenHeight / Julia.rect_h

    for ry = 0, num_rects_y - 1 do
        for rx = 0, num_rects_x - 1 do
            local screen_x = rx * Julia.rect_w
            local screen_y = ry * Julia.rect_h

            local zx = ((screen_x + Julia.rect_w / 2) / Julia.screenWidth) *
                           (4.0 / Julia.zoom) - (2.0 / Julia.zoom) +
                           Julia.offsetX
            local zy = ((screen_y + Julia.rect_h / 2) / Julia.screenHeight) *
                           (1.0 / Julia.zoom) - (0.5 / Julia.zoom) +
                           Julia.offsetY

            local iterations = Julia.calculate_iterations(zx, zy, Julia.c_real,
                                                          Julia.c_imag,
                                                          Julia.max_iterations)
            local color
            if iterations == Julia.max_iterations then
                color = 0 -- Inside the set: black
            else
                color = (iterations % 15) + 1 -- Outside the set: cycling colors
            end
            table.insert(rects, color) -- Store only the color value
        end
    end
    return rects
end

local iteration_options = {32, 64, 128, 256, 512, 1024}

return {
    name = "ModJulia",
    author = "Thorinside",

    init = function(self)
        self.last_iteration_param_idx = nil
        self.last_zoom_param_val = nil
        self.last_offset_x_param_val = nil
        self.last_offset_y_param_val = nil
        self.last_ball_speed_param_val = nil
        self.julia_rects = {}
        self.output_table = {[1] = 0.0} -- Pre-initialize output table

        -- Ball physics properties
        self.ball_x = Julia.screenWidth / 2
        self.ball_y = Julia.screenHeight / 2
        self.base_ball_vx = 50.0
        self.base_ball_vy = 30.0

        -- Pre-calculate base speed magnitude and direction
        self.base_speed_magnitude = math.sqrt(
                                        self.base_ball_vx ^ 2 +
                                            self.base_ball_vy ^ 2)
        if self.base_speed_magnitude > 0.0001 then
            self.base_dir_x = self.base_ball_vx / self.base_speed_magnitude
            self.base_dir_y = self.base_ball_vy / self.base_speed_magnitude
        else
            self.base_dir_x = 0 -- Or 1.0 if a default direction is preferred for zero base speed
            self.base_dir_y = 0
        end

        self.ball_vx = self.base_ball_vx
        self.ball_vy = self.base_ball_vy
        self.ball_rect_w = 5 -- Constant width
        self.ball_rect_h = 5 -- Constant height
        self.ball_half_w = 2.5 -- Pre-calculated half width
        self.ball_half_h = 2.5 -- Pre-calculated half height
        self.ball_draw_color = 15 -- White, updated by proximity to Julia set
        self.ball_outline_color = 15 -- White outline for visibility

        -- Store dimensions of the Julia rectangle grid
        self.num_julia_rects_x = Julia.screenWidth / Julia.rect_w
        self.num_julia_rects_y = Julia.screenHeight / Julia.rect_h

        -- Define parameter structures, using live self.parameters for defaults if available
        local iter_default = (self.parameters and self.parameters[1]) or 4
        local zoom_default = (self.parameters and self.parameters[2]) or 1
        local offset_x_default = (self.parameters and self.parameters[3]) or 0
        local offset_y_default = (self.parameters and self.parameters[4]) or 0
        local speed_default = (self.parameters and self.parameters[5]) or 100

        local init_params = {
            inputs = {kTrigger},
            inputNames = {"Reset Ball"},
            outputs = {kLinear},
            outputNames = {"Mod Out"},
            parameters = {
                {
                    "Iterations", {"32", "64", "128", "256", "512", "1024"},
                    iter_default
                }, -- Param 1
                {"Zoom", 1, 1000, zoom_default, kNone}, -- Param 2
                {"Offset X", -100, 100, offset_x_default, kNone}, -- Param 3
                {"Offset Y", -100, 100, offset_y_default, kNone}, -- Param 4
                {"Ball Speed", 10, 200, speed_default, kNone} -- Param 5
            }
        }
        self.parameter_specs = init_params.parameters

        -- Initialize Julia properties and ball speed from the determined parameter values
        Julia.max_iterations = iteration_options[init_params.parameters[1][3]]
        Julia.zoom = init_params.parameters[2][3]
        Julia.offsetX = init_params.parameters[3][3] / 1000.0
        Julia.offsetY = init_params.parameters[4][3] / 1000.0

        local current_speed_param_val_for_init = init_params.parameters[5][3]
        local speed_multiplier = current_speed_param_val_for_init / 100.0
        self.ball_vx = self.base_ball_vx * speed_multiplier
        self.ball_vy = self.base_ball_vy * speed_multiplier

        -- Initialize last known parameter values for step function comparisons
        self.last_iteration_param_idx = init_params.parameters[1][3]
        self.last_zoom_param_val = init_params.parameters[2][3]
        self.last_offset_x_param_val = init_params.parameters[3][3]
        self.last_offset_y_param_val = init_params.parameters[4][3]
        self.last_ball_speed_param_val = init_params.parameters[5][3]

        self.julia_rects = Julia.calculate_rects()
        return init_params
    end,

    step = function(self, dt, inputs)
        local needs_recalc = false

        -- Check for changes in parameters and update Julia set properties accordingly
        local current_iter_param_idx = self.parameters[1]
        if current_iter_param_idx ~= self.last_iteration_param_idx then
            if iteration_options[current_iter_param_idx] then
                Julia.max_iterations = iteration_options[current_iter_param_idx]
                self.last_iteration_param_idx = current_iter_param_idx
                needs_recalc = true
            end
        end

        local current_zoom_param_val = self.parameters[2]
        if current_zoom_param_val ~= self.last_zoom_param_val then
            Julia.zoom = current_zoom_param_val
            self.last_zoom_param_val = current_zoom_param_val
            needs_recalc = true
        end

        local current_offset_x_param_val = self.parameters[3]
        if current_offset_x_param_val ~= self.last_offset_x_param_val then
            Julia.offsetX = current_offset_x_param_val / 1000.0
            self.last_offset_x_param_val = current_offset_x_param_val
            needs_recalc = true
        end

        local current_offset_y_param_val = self.parameters[4]
        if current_offset_y_param_val ~= self.last_offset_y_param_val then
            Julia.offsetY = current_offset_y_param_val / 1000.0
            self.last_offset_y_param_val = current_offset_y_param_val
            needs_recalc = true
        end

        local current_ball_speed_param_val = self.parameters[5]
        if current_ball_speed_param_val ~= self.last_ball_speed_param_val then
            local speed_multiplier = current_ball_speed_param_val / 100.0
            local base_speed_magnitude = self.base_speed_magnitude -- Use pre-calculated value
            local new_total_speed = base_speed_magnitude * speed_multiplier
            local current_vel_magnitude_sq =
                self.ball_vx * self.ball_vx + self.ball_vy * self.ball_vy

            if current_vel_magnitude_sq > 0.0001 then -- If ball is moving, preserve direction
                local current_vel_magnitude =
                    math.sqrt(current_vel_magnitude_sq)
                local dir_x = self.ball_vx / current_vel_magnitude
                local dir_y = self.ball_vy / current_vel_magnitude
                self.ball_vx = dir_x * new_total_speed
                self.ball_vy = dir_y * new_total_speed
            else -- If ball is stationary, apply new speed to base direction (or keep stationary if base speed is zero)
                if base_speed_magnitude > 0.0001 then
                    local base_dir_x = self.base_dir_x -- Use pre-calculated value
                    local base_dir_y = self.base_dir_y -- Use pre-calculated value
                    self.ball_vx = base_dir_x * new_total_speed
                    self.ball_vy = base_dir_y * new_total_speed
                else
                    self.ball_vx = 0
                    self.ball_vy = 0
                end
            end
            self.last_ball_speed_param_val = current_ball_speed_param_val
        end

        if needs_recalc then self.julia_rects = Julia.calculate_rects() end

        -- Update ball position based on velocity and delta time
        self.ball_x = self.ball_x + self.ball_vx * dt
        self.ball_y = self.ball_y + self.ball_vy * dt

        -- Screen edge collision detection and response for the ball
        if self.ball_x < 0 then
            self.ball_x = 0
            self.ball_vx = -self.ball_vx
        elseif self.ball_x + self.ball_rect_w > Julia.screenWidth then
            self.ball_x = Julia.screenWidth - self.ball_rect_w
            self.ball_vx = -self.ball_vx
        end

        if self.ball_y < 0 then
            self.ball_y = 0
            self.ball_vy = -self.ball_vy
        elseif self.ball_y + self.ball_rect_h > Julia.screenHeight then
            self.ball_y = Julia.screenHeight - self.ball_rect_h
            self.ball_vy = -self.ball_vy
        end

        -- Determine output color based on the Julia set rectangle under the ball's center
        local output_color = 0 -- Default color

        if #self.julia_rects > 0 then -- Safeguard, should effectively always be true after init
            local ball_center_x = self.ball_x + self.ball_half_w
            local ball_center_y = self.ball_y + self.ball_half_h

            -- Determine the grid cell (0-indexed rx, ry) under the ball's center
            local target_rx = math.floor(ball_center_x / Julia.rect_w)
            local target_ry = math.floor(ball_center_y / Julia.rect_h)

            -- Clamp to valid grid indices
            target_rx = math.max(0, math.min(target_rx,
                                             self.num_julia_rects_x - 1))
            target_ry = math.max(0, math.min(target_ry,
                                             self.num_julia_rects_y - 1))

            -- Convert 2D grid coordinates to 1D index for self.julia_rects table
            local target_idx = target_ry * self.num_julia_rects_x + target_rx +
                                   1

            if self.julia_rects[target_idx] then -- Should always be true due to clamping
                output_color = self.julia_rects[target_idx] -- Direct color value
            end
        end

        self.ball_draw_color = output_color -- Update ball's visual color for draw function

        -- Output the determined color value (0-15), scaled to 0-10V
        self.output_table[1] = (output_color / 15.0) * 10.0
        return self.output_table
    end,

    -- Handles trigger input to reset ball position and velocity
    trigger = function(self, input_idx)
        self.ball_x = (Julia.screenWidth / 2) - self.ball_half_w -- Use pre-calculated half width
        self.ball_y = (Julia.screenHeight / 2) - self.ball_half_h -- Use pre-calculated half height

        local rand_dir_x, rand_dir_y
        repeat
            rand_dir_x = math.random() * 2.0 - 1.0
            rand_dir_y = math.random() * 2.0 - 1.0
        until (rand_dir_x ~= 0 or rand_dir_y ~= 0)

        local dir_magnitude = math.sqrt(rand_dir_x ^ 2 + rand_dir_y ^ 2)
        rand_dir_x = rand_dir_x / dir_magnitude
        rand_dir_y = rand_dir_y / dir_magnitude

        local current_ball_speed_param_val = self.parameters[5]
        local speed_multiplier = current_ball_speed_param_val / 100.0
        local base_speed_magnitude = self.base_speed_magnitude -- Use pre-calculated value
        local new_total_speed = base_speed_magnitude * speed_multiplier

        if base_speed_magnitude <= 0.0001 then -- If base speed is zero, use a default speed
            new_total_speed = 50.0 * speed_multiplier
        end

        self.ball_vx = rand_dir_x * new_total_speed
        self.ball_vy = rand_dir_y * new_total_speed
        return {} -- No direct output from trigger
    end,

    -- Custom drawing routine for the display
    draw = function(self)
        -- Draw the pre-calculated Julia set by iterating through the grid
        for ry = 0, self.num_julia_rects_y - 1 do
            for rx = 0, self.num_julia_rects_x - 1 do
                local screen_x = rx * Julia.rect_w
                local screen_y = ry * Julia.rect_h
                local idx = ry * self.num_julia_rects_x + rx + 1
                local color_to_draw = self.julia_rects[idx]

                if color_to_draw then -- Safeguard, though idx should always be valid
                    drawRectangle(screen_x, screen_y,
                                  screen_x + Julia.rect_w - 1,
                                  screen_y + Julia.rect_h - 1, color_to_draw)
                end
            end
        end

        -- Draw the bouncing ball
        local ball_draw_x = math.floor(self.ball_x + 0.5)
        local ball_draw_y = math.floor(self.ball_y + 0.5)
        local ball_x2 = ball_draw_x + self.ball_rect_w - 1
        local ball_y2 = ball_draw_y + self.ball_rect_h - 1

        drawRectangle(ball_draw_x, ball_draw_y, ball_x2, ball_y2,
                      self.ball_draw_color) -- Filled part
        drawBox(ball_draw_x, ball_draw_y, ball_x2, ball_y2,
                self.ball_outline_color) -- Outline

        return true -- Hide default parameter line
    end,

    -- Enable custom UI handlers
    ui = function(self) return true end,

    -- Setup initial pot values for soft takeover
    setupUi = function(self)
        local potSyncValues = {}

        -- Iterations (Parameter 1)
        local iter_spec = self.parameter_specs[1]
        local num_iter_options = #iter_spec[2]
        if num_iter_options > 1 then
            potSyncValues[1] = (self.parameters[1] - 1) / (num_iter_options - 1)
        else
            potSyncValues[1] = 0.5
        end

        -- Zoom (Parameter 2)
        local zoom_spec = self.parameter_specs[2]
        local zoom_min = zoom_spec[2]
        local zoom_max = zoom_spec[3]
        if zoom_max > zoom_min then
            potSyncValues[2] = (self.parameters[2] - zoom_min) /
                                   (zoom_max - zoom_min)
        else
            potSyncValues[2] = 0.5
        end

        -- Ball Speed (Parameter 5)
        local speed_spec = self.parameter_specs[5]
        local speed_min = speed_spec[2]
        local speed_max = speed_spec[3]
        if speed_max > speed_min then
            potSyncValues[3] = (self.parameters[5] - speed_min) /
                                   (speed_max - speed_min)
        else
            potSyncValues[3] = 0.5
        end
        return potSyncValues
    end,

    -- Pot 1: Iterations
    pot1Turn = function(self, value) -- Parameter 1
        setParameterNormalized(getCurrentAlgorithm(), self.parameterOffset + 1,
                               value)
    end,

    -- Pot 2: Zoom
    pot2Turn = function(self, value) -- Parameter 2
        setParameterNormalized(getCurrentAlgorithm(), self.parameterOffset + 2,
                               value)
    end,

    -- Pot 3: Ball Speed
    pot3Turn = function(self, value) -- Parameter 5
        setParameterNormalized(getCurrentAlgorithm(), self.parameterOffset + 5,
                               value)
    end,

    -- Encoder 1 Turn: Offset X
    encoder1Turn = function(self, dir) -- Parameter 3
        setParameter(getCurrentAlgorithm(), self.parameterOffset + 3,
                     self.parameters[3] + dir)
    end,

    -- Encoder 2 Turn: Offset Y
    encoder2Turn = function(self, dir) -- Parameter 4
        setParameter(getCurrentAlgorithm(), self.parameterOffset + 4,
                     self.parameters[4] + dir)
    end,

    -- Encoder 2 Push: Reset Ball
    encoder2Push = function(self) if self.trigger then self:trigger(1) end end
}

