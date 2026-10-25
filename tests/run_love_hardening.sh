#!/usr/bin/env bash
# Isolated startup checks: never read/write the user's state or open MIDI ports.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOVE_BIN="${LOVE_BIN:-$(command -v love || true)}"
if [[ -z "$LOVE_BIN" && -x /Applications/love.app/Contents/MacOS/love ]]; then
  LOVE_BIN=/Applications/love.app/Contents/MacOS/love
fi
if [[ -z "$LOVE_BIN" ]]; then echo 'Set LOVE_BIN to the LÖVE executable.' >&2; exit 1; fi
python3 - "$ROOT" "$LOVE_BIN" <<'PY'
import pathlib, shutil, subprocess, sys, tempfile
root, binary = pathlib.Path(sys.argv[1]), sys.argv[2]
artifacts = pathlib.Path(tempfile.mkdtemp(prefix='nt-hardening-'))
print('Hardening artifacts:', artifacts, flush=True)
cases = {
    'script-guard': '{}',
    'truncated': '{', 'null': 'null', 'scalar': '42',
    'wrong-types': '{"midi":3,"osc":false,"script":true,"scriptPath":42,"inputs":true,"outputs":"bad","inputModes":{"1":false},"parameterValues":false,"window":{"x":"bad","y":0},"clockBPM":"fast"}',
    'invalid-mappings': '{"inputs":{"1":"bad","-1":3},"outputs":{"1":999},"parameterAutomation":false,"inputModes":{"1":{"scaling":"bad","clock":"false"}},"window":{"x":0,"y":0,"width":-1,"height":600}}',
}
for name, content in cases.items():
    work = artifacts / name
    shutil.copytree(root, work, ignore=shutil.ignore_patterns('.git', 'graphify-out', 'state.json', 'config.json'))
    (work / 'main.lua').rename(work / 'app.lua')
    harness = 'love_script_guard.lua' if name == 'script-guard' else 'love_hardening.lua'
    shutil.copy(root / 'tests' / harness, work / 'main.lua')
    for file in ('config.json', 'state.json'):
        (work / file).write_text(content)
    with (work / 'hardening.log').open('w') as log:
        try:
            result = subprocess.run([binary, '.'], cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=20)
        except subprocess.TimeoutExpired:
            raise SystemExit(f'TIMEOUT: {work}/hardening.log')
    if result.returncode or 'LOVE_HARDENING_PASSED' not in (work / 'hardening.log').read_text():
        raise SystemExit(f'FAILED: {work}/hardening.log')
    print('PASS:', name, flush=True)
PY
