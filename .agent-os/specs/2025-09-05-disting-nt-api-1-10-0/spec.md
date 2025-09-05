# Spec Requirements Document

> Spec: Disting NT API 1.10.0 Support
> Created: 2025-09-05

## Overview

Update the Disting NT LUA Emulator to support API version 1.10.0, adding new script context properties, algorithm/parameter query functions, display mode control, and enhanced drawing capabilities. This update maintains full backward compatibility with existing 1.9.0 scripts while enabling developers to utilize the expanded feature set of the latest hardware specification.

## User Stories

### Script Developer Workflow Enhancement

As a script developer, I want to access the new algorithmIndex property and query functions, so that I can write more efficient and discoverable scripts without needing to call legacy functions like getCurrentAlgorithm().

When developing scripts, I can now use `self.algorithmIndex` directly in functions like `getCurrentParameter(alg)` and query algorithm/parameter metadata using the new functions `getAlgorithmCount()`, `getAlgorithmName(index)`, `getParameterCount(alg)`, and `getParameterName(alg, index)`. This reduces API calls and enables dynamic script behavior based on the current preset configuration.

### Enhanced Display Control

As a script developer, I want to programmatically control the display mode, so that I can create scripts that provide optimal user interfaces for different contexts.

Using the new `setDisplayMode(mode)` function, I can switch between "overview", "meters", "parameters", "ui", "algorithm", and "menu" modes to present the most relevant information for my script's current state or user interaction.

### Improved Text Rendering

As a script developer, I want to use text alignment options in drawing functions, so that I can create more polished and professional-looking script interfaces.

The enhanced `drawText()` and `drawTinyText()` functions now accept alignment parameters ("left", "centre", "right") allowing me to create better-designed UI layouts without manual positioning calculations.

## Spec Scope

1. **Script Context Enhancement** - Add `self.algorithmIndex` property to script execution environment
2. **Algorithm Query Functions** - Implement `getAlgorithmCount()` and `getAlgorithmName(index)` functions
3. **Parameter Query Functions** - Implement `getParameterCount(alg)` and `getParameterName(alg, index)` functions  
4. **Display Mode Control** - Implement `setDisplayMode(mode)` function with six mode options
5. **Drawing API Enhancement** - Extend `drawText()` and `drawTinyText()` with optional alignment parameter

## Out of Scope

- Changes to existing 1.9.0 API functions (maintaining backward compatibility)
- UI modifications to the emulator interface itself
- Performance optimizations beyond what's required for new functions
- Documentation updates (handled separately)
- Migration tools for existing scripts (not needed due to backward compatibility)

## Expected Deliverable

1. All existing 1.9.0 scripts continue to work without modification in the updated emulator
2. New 1.10.0 API functions are fully functional and return expected values/behaviors as specified
3. Drawing functions properly render text with specified alignment options
4. Scripts can successfully query algorithm and parameter metadata using new functions