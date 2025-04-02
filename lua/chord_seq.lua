table.sort(self.matrix_names)

-- Clock Div Options
self.clock_division_options = {
    "1", "2", "3", "4", "6", "8", "12", "16", "24", "32"
};
self.clock_division_values = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32};

-- Transition Type Options
self.transition_options_param = {"V7", "iv", "bVII", "dim7", "Random"};
self.transition_options = {"V7", "iv", "bVII", "dim7"};

-- Inversion Options
self.inversion_options = {"Root", "1st", "2nd", "3rd"} -- Make this part of self

-- Parameter Defaults (Used ONLY for the definition table)
local default_root = 0

-- ... existing code ...

if loaded_clock_div_idx < 1 or loaded_clock_div_idx > #self.clock_division_values then
    loaded_clock_div_idx = default_clock_div_idx
end
if loaded_transition_idx < 1 or loaded_transition_idx > #self.transition_options_param then
    loaded_transition_idx = default_transition_idx
end
if loaded_inversion_idx < 1 or loaded_inversion_idx > #self.inversion_options then -- Use self.inversion_options
    loaded_inversion_idx = default_inversion_idx
end
if loaded_root < 0 or loaded_root > 11 then
-- ... existing code ...
end

-- ... existing code ...

-- Handle matrix change (update immediately)
if matrix_param_idx ~= nil and self.previous_parameters and
    matrix_param_idx ~= self.previous_parameters[3] then
    self.current_matrix_name = self.matrix_names[matrix_param_idx]
    self.current_matrix = self.matrices[self.current_matrix_name]
    self.previous_parameters[3] = matrix_param_idx
end

-- Handle clock div change (update immediately)
if clock_div_param_idx ~= nil and self.previous_parameters and
    clock_div_param_idx ~= self.previous_parameters[4] then
    self.clock_division_steps =
        self.clock_division_values[clock_div_param_idx]
    self.internal_clock_count = 0
    self.previous_parameters[4] = clock_div_param_idx
end

-- Handle transition type change (update immediately)
if transition_param_idx ~= nil and self.previous_parameters and
    transition_param_idx ~= self.previous_parameters[5] then
    self.transition_type =
        self.transition_options_param[transition_param_idx]
    self.previous_parameters[5] = transition_param_idx
end

-- Handle inversion change (update immediately, handled by apply_voicing)
if inversion_param_idx ~= nil and self.previous_parameters and
    inversion_param_idx ~= self.previous_parameters[6] then
    self.previous_parameters[6] = inversion_param_idx
    -- No internal state changes needed here, apply_voicing uses param directly
end

-- Output Logic: Return cached voltages if they were updated
-- ... existing code ...

setupUi = function(self)
    -- Define defaults locally IF needed, ensure access to self properties
    local default_matrix_idx = 1
    local default_transition_idx = 5
    local default_inversion_idx = 1

    -- Check if self and self.parameters exist before accessing them
    local current_matrix_idx = (self and self.parameters and self.parameters[3]) or default_matrix_idx
    local current_transition_idx = (self and self.parameters and self.parameters[5]) or default_transition_idx
    local current_inversion_idx = (self and self.parameters and self.parameters[6]) or default_inversion_idx

    -- Ensure self properties used for division exist
    local matrix_count = (self and self.matrix_names and #self.matrix_names) or 1
    local transition_count = (self and self.transition_options_param and #self.transition_options_param) or 1
    local inversion_count = (self and self.inversion_options and #self.inversion_options) or 1

    -- Avoid division by zero
    if matrix_count == 0 then matrix_count = 1 end
    if transition_count == 0 then transition_count = 1 end
    if inversion_count == 0 then inversion_count = 1 end

    return {
        current_matrix_idx / matrix_count,       -- Use calculated values
        current_transition_idx / transition_count,
        current_inversion_idx / inversion_count  -- Use calculated values
    }
end,

pot1Turn = function(self, value)
-- ... existing code ...
