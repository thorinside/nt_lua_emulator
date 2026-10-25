#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import subprocess
for runtime in ('lua', 'luajit'):
    result = subprocess.run([runtime, 'tests/test_script_guard.lua'], timeout=10)
    if result.returncode:
        raise SystemExit(result.returncode)
PY
