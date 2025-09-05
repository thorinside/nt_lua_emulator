# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-09-05-disting-nt-api-1-10-0/spec.md

## Technical Requirements

### Script Context Enhancements
- **self.algorithmIndex Property**: Add algorithmIndex field to script execution context, populated with current algorithm index value
- **Context Integration**: Ensure algorithmIndex is available alongside existing self.parameterOffset and other context properties
- **Dynamic Updates**: Update algorithmIndex value when algorithm changes during script execution

### New Global Functions Implementation

#### Algorithm Query Functions
- **getAlgorithmCount()**: Return total number of algorithms in current preset (integer)
- **getAlgorithmName(index)**: Return display name string for algorithm at specified index (string)
- **Index Validation**: Handle invalid algorithm indices gracefully with error messages or nil returns

#### Parameter Query Functions  
- **getParameterCount(alg)**: Return number of parameters for specified algorithm index (integer)
- **getParameterName(alg, index)**: Return parameter name string for algorithm and parameter indices (string)
- **Dual Index Validation**: Validate both algorithm and parameter indices with appropriate error handling

#### Display Mode Control
- **setDisplayMode(mode)**: Accept mode strings: "overview", "meters", "parameters", "ui", "algorithm", "menu"
- **Mode Validation**: Reject invalid mode strings with clear error messages
- **Emulator Integration**: Update emulator's display state to reflect requested mode

### Drawing API Enhancements

#### Text Alignment Support
- **drawText() Extension**: Add optional 5th parameter for alignment ("left", "centre", "right")
- **drawTinyText() Extension**: Add optional 5th parameter for alignment ("left", "centre", "right") 
- **Backward Compatibility**: Maintain existing 4-parameter function signatures with "left" default alignment
- **Rendering Logic**: Implement proper text positioning calculations for centre and right alignment options

#### Implementation Details
- **Centre Alignment**: Calculate text width and position at x - (width/2)
- **Right Alignment**: Calculate text width and position at x - width
- **Font Metrics**: Use existing LÖVE2D font measurement functions for accurate positioning

### Integration Points

#### Script Loader Module
- **Context Population**: Modify script context creation to include algorithmIndex
- **Function Registration**: Register all new global functions in script execution environment
- **Error Handling**: Extend existing error handling to cover new function validation

#### Display Module  
- **Mode State Management**: Add display mode state tracking and switching logic
- **Rendering Pipeline**: Integrate mode changes with existing display rendering system

#### Signal Processor Integration
- **Algorithm Context**: Ensure algorithm index updates are reflected in script context during processing
- **Parameter Queries**: Connect parameter query functions to existing parameter management system

### Performance Considerations
- **Function Caching**: Cache algorithm and parameter metadata to avoid repeated queries
- **Context Updates**: Minimize algorithmIndex updates to only when actually changed
- **Drawing Optimizations**: Optimize text alignment calculations to avoid performance degradation

### Error Handling Strategy
- **Graceful Degradation**: New functions should fail gracefully without breaking existing scripts
- **Clear Error Messages**: Provide descriptive error messages for invalid indices or mode strings
- **Logging Integration**: Use existing notification system for error reporting

### Testing Requirements
- **Backward Compatibility**: Verify all existing 1.9.0 scripts continue to function unchanged
- **New Function Validation**: Test all new functions with valid and invalid parameters
- **Drawing Verification**: Confirm text alignment renders correctly in all three modes
- **Integration Testing**: Verify new functions work correctly with existing emulator features