-- Test script for self.algorithmIndex property (API 1.10.0)
-- This script tests that the algorithmIndex property is available and working correctly

return {
    name = 'algorithmIndexTest',
    author = 'Agent OS Test',
    
    init = function(self)
        print("=== Algorithm Index Test ===")
        print("Testing self.algorithmIndex property...")
        
        -- Test 1: Check if algorithmIndex property exists
        if self.algorithmIndex ~= nil then
            print("✓ SUCCESS: self.algorithmIndex property exists")
            print("  algorithmIndex value:", self.algorithmIndex)
        else
            print("✗ FAILURE: self.algorithmIndex property is nil")
        end
        
        -- Test 2: Check if algorithmIndex is a number
        if type(self.algorithmIndex) == "number" then
            print("✓ SUCCESS: self.algorithmIndex is a number")
        else
            print("✗ FAILURE: self.algorithmIndex is not a number, type:", type(self.algorithmIndex))
        end
        
        -- Test 3: Check if algorithmIndex is a valid index (should be >= 0)
        if self.algorithmIndex and self.algorithmIndex >= 0 then
            print("✓ SUCCESS: self.algorithmIndex has valid value (>= 0)")
        else
            print("✗ FAILURE: self.algorithmIndex has invalid value:", self.algorithmIndex)
        end
        
        -- Test 4: Compare with getCurrentAlgorithm() (legacy function)
        local currentAlg = getCurrentAlgorithm()
        if self.algorithmIndex == currentAlg then
            print("✓ SUCCESS: self.algorithmIndex matches getCurrentAlgorithm()")
        else
            print("✗ FAILURE: self.algorithmIndex (" .. tostring(self.algorithmIndex) .. 
                  ") does not match getCurrentAlgorithm() (" .. tostring(currentAlg) .. ")")
        end
        
        print("=== Test Complete ===")
    end,
    
    process = function(self, inputs, outputs)
        -- Simple passthrough for testing
        for i = 1, #outputs do
            outputs[i] = i <= #inputs and inputs[i] or 0
        end
    end,
    
    inputs = {kCV, kCV},
    outputs = {kCV, kCV}
}