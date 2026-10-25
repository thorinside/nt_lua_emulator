#!/usr/bin/env bash
# Real UI regression, isolated from user state/config, MIDI devices and repo files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOVE_BIN="${LOVE_BIN:-$(command -v love || true)}"
if [[ -z "$LOVE_BIN" && -x /Applications/love.app/Contents/MacOS/love ]]; then
  LOVE_BIN=/Applications/love.app/Contents/MacOS/love
fi
if [[ -z "$LOVE_BIN" ]]; then echo 'Set LOVE_BIN to the LÖVE executable.' >&2; exit 1; fi
ARTIFACTS="$(mktemp -d "${TMPDIR:-/tmp}/nt-midi-workflow.XXXXXX")"
printf 'MIDI workflow artifacts: %s\n' "$ARTIFACTS"
for mode in no-native fake; do
  work="$ARTIFACTS/$mode"
  mkdir -p "$work"
  rsync -a --exclude=.git --exclude=graphify-out "$ROOT/" "$work/"
  cp "$ROOT/main.lua" "$work/app.lua"
  cp "$ROOT/tests/love_midi_workflow.lua" "$work/main.lua"
  printf '%s\n' '{"scriptPath":"tests/fixtures/midi_workflow.lua"}' > "$work/state.json"
  printf '%s\n' '{"osc":{"enabled":false},"script":{"path":"tests/fixtures/midi_workflow.lua"},"minimalMode":false,"midi":{"enabled":false,"selectedInput":-1,"selectedOutput":-1,"destinationRoutes":{"1":false,"2":false,"4":false,"8":false}}}' > "$work/config.json"
  if ! MIDI_WORKFLOW_NATIVE="$mode" python3 - "$LOVE_BIN" "$work" <<'PY'
import pathlib, subprocess, sys
binary, work = sys.argv[1:]
with open(pathlib.Path(work) / "workflow.log", "w") as log:
    try:
        result = subprocess.run([binary, "."], cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=30)
        sys.exit(result.returncode)
    except subprocess.TimeoutExpired:
        print("LÖVE workflow timed out", file=log)
        sys.exit(1)
PY
  then
    printf 'FAILED (%s): inspect %s/workflow.log\n' "$mode" "$work" >&2
    exit 1
  fi
  printf 'PASS: %s (log + screenshot in %s)\n' "$mode" "$work"
done
