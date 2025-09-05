-- Test script for Algorithm Query Functions (API 1.10.0)
-- This script tests getAlgorithmCount() and getAlgorithmName(index) functions

return {
    name = 'algorithmQueryTest',
    author = 'Agent OS Test',
    
    init = function(self)
        print("=== Algorithm Query Functions Test ===")
        print("Testing getAlgorithmCount() and getAlgorithmName(index)...")
        
        -- Test 1: Check if getAlgorithmCount function exists
        if getAlgorithmCount then
            print("✓ SUCCESS: getAlgorithmCount() function exists")
        else
            print("✗ FAILURE: getAlgorithmCount() function is missing")
            return
        end
        
        -- Test 2: Check if getAlgorithmName function exists
        if getAlgorithmName then
            print("✓ SUCCESS: getAlgorithmName() function exists")
        else
            print("✗ FAILURE: getAlgorithmName() function is missing")
            return
        end
        
        -- Test 3: Call getAlgorithmCount and verify it returns a number
        local count = getAlgorithmCount()
        if type(count) == "number" then
            print("✓ SUCCESS: getAlgorithmCount() returns a number")
            print("  Algorithm count:", count)
        else
            print("✗ FAILURE: getAlgorithmCount() did not return a number, type:", type(count))
            return
        end
        
        -- Test 4: Verify algorithm count is valid (should be >= 1 for emulator)
        if count >= 1 then
            print("✓ SUCCESS: getAlgorithmCount() returns valid count (>= 1)")
        else
            print("✗ FAILURE: getAlgorithmCount() returned invalid count:", count)
        end
        
        -- Test 5: Test getAlgorithmName with valid index (0)
        local name0 = getAlgorithmName(0)
        if type(name0) == "string" then
            print("✓ SUCCESS: getAlgorithmName(0) returns a string")
            print("  Algorithm name at index 0:", name0)
        else
            print("✗ FAILURE: getAlgorithmName(0) did not return a string, type:", type(name0))
            print("  Value:", tostring(name0))
        end
        
        -- Test 6: Test getAlgorithmName with invalid negative index
        local nameNeg = getAlgorithmName(-1)
        if nameNeg == nil then
            print("✓ SUCCESS: getAlgorithmName(-1) returns nil for invalid index")
        else
            print("✗ FAILURE: getAlgorithmName(-1) should return nil for invalid index, got:", tostring(nameNeg))
        end
        
        -- Test 7: Test getAlgorithmName with index beyond count
        local nameHigh = getAlgorithmName(count)
        if nameHigh == nil then
            print("✓ SUCCESS: getAlgorithmName(" .. count .. ") returns nil for out-of-bounds index")
        else
            print("✗ FAILURE: getAlgorithmName(" .. count .. ") should return nil for out-of-bounds index, got:", tostring(nameHigh))
        end
        
        -- Test 8: Test consistency - current algorithm index should be valid
        if self.algorithmIndex ~= nil then
            local currentName = getAlgorithmName(self.algorithmIndex)
            if currentName then
                print("✓ SUCCESS: getAlgorithmName(self.algorithmIndex) returns valid name")
                print("  Current algorithm name:", currentName)
            else
                print("✗ FAILURE: getAlgorithmName(self.algorithmIndex) returned nil for current index")
            end
        end
        
        -- Test 9: Verify all valid indices return strings
        local allValid = true
        for i = 0, count - 1 do
            local name = getAlgorithmName(i)
            if type(name) ~= "string" then
                print("✗ FAILURE: getAlgorithmName(" .. i .. ") did not return string, type:", type(name))
                allValid = false
                break
            end
        end
        if allValid then
            print("✓ SUCCESS: All valid indices return string names")
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