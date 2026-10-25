# Runtime safety

The emulator is a development tool for **trusted Lua scripts**, not a security sandbox. Scripts still share the Lua global environment and can access native APIs.

## Script execution budgets

`modules/script_guard.lua` guards script loading, initialization, setup, step/draw/control/MIDI callbacks, and serialization:

- Regular callbacks: 50 ms of CPU time or 2 million Lua instructions.
- Loading, including initialization/setup: 1 second of CPU time or 20 million instructions.
- Budgets are checked every 10,000 instructions. Nested guarded calls share the outer budget.
- LuaJIT is disabled during guarded execution so compiled loops cannot evade hooks. The previous JIT enabled state and debug hook are restored afterward. This has a performance cost compared with unrestricted JIT execution.
- A timed-out runtime callback is disabled until a newly loaded script supplies a new callback function. Other callbacks remain usable, and the timeout is reported once by the normal callback wrappers.
- Host-side I/O loops accept at most 64 declared inputs and 64 outputs. Invalid, fractional, negative, or larger declarations reject the load.

These are emulator safety limits, not firmware execution guarantees. Heavy legitimate callbacks may need to spread work over multiple steps.

## Failed loads

Failed loads preserve the selected script/path and do not persist the failed path. The loader restores its package search path, previous module cache entry, display mode, and a shallow snapshot of global bindings. Initialization errors now reject the new script instead of keeping a partially initialized script.

This is **not transactional rollback of arbitrary side effects**: mutations inside existing tables, files written by scripts, MIDI already sent, and newly required dependencies cannot all be undone.

## Remaining limits

- Debug hooks cannot interrupt blocking native calls, filesystem reads, or MIDI drivers.
- Deliberately hostile code can bypass hooks or catch a timeout and keep looping. The watchdog is intended to catch accidental runaway loops, not enforce isolation.
- Script-created coroutines are not independently guarded.
- JSON saves use a same-directory temporary file and rename after successful write/close. This assumes one emulator writer per directory; it is not multi-process locking or a power-loss durability guarantee. A failed replacement leaves the previous file intact rather than deleting it as a fallback.

## Regression checks

```sh
bash tests/run_script_guard.sh
bash tests/run_love_hardening.sh
bash tests/run_love_midi_workflow.sh
```

The watchdog and LÖVE runners use external process timeouts. The LÖVE runners copy the project to temporary directories, disable real MIDI ports, and never use the working checkout's saved configuration/state.
