"""Research S5: measure Python cold/warm startup + skill-router import latency.

Design v2 section 3.2.5 / 8.2 budget the per-prompt route at < 200ms total, with
~100ms reserved for the Python interpreter itself.  This research script measures
the actual numbers on the target machine.

Run directly (not as a hook):
  python references/research/s5_python_startup_latency.py

Output: 5-iteration table of:
  - subprocess startup time (cold per-invocation, what the hook actually pays)
  - skill-router import time within the spawned process
  - end-to-end route() call against an empty stdin payload
"""
from __future__ import annotations

import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path


_LIB_DIR = Path(__file__).resolve().parent.parent / "scripts" / "routing"


def _self_measure() -> dict[str, float]:
    """Inside-process measurement (no subprocess overhead)."""
    t0 = time.perf_counter()
    sys.path.insert(0, str(_LIB_DIR))
    import build_index  # type: ignore  # noqa: F401
    import session_state  # type: ignore  # noqa: F401
    import route  # type: ignore
    t1 = time.perf_counter()

    # Use a deliberately tiny payload; we only want to exercise import + dispatch.
    payload = {"session_id": "research-s5", "prompt": "/research-noop"}
    t2 = time.perf_counter()
    _ = route.route(payload)
    t3 = time.perf_counter()

    return {
        "import_ms": (t1 - t0) * 1000,
        "route_call_ms": (t3 - t2) * 1000,
    }


def _subprocess_round() -> dict[str, float]:
    """Cold start measurement: spawn `python -c "import time;..."` and time it."""
    cmd = [
        sys.executable,
        "-c",
        (
            "import time, sys, os, json;"
            f"sys.path.insert(0, r'{_LIB_DIR}');"
            "t0=time.perf_counter();"
            "import build_index, session_state, route;"
            "t1=time.perf_counter();"
            "route.route({'session_id':'research-s5','prompt':'/x'});"
            "t2=time.perf_counter();"
            "print(json.dumps({'import_ms':(t1-t0)*1000,'route_call_ms':(t2-t1)*1000}))"
        ),
    ]
    started = time.perf_counter()
    proc = subprocess.run(cmd, capture_output=True, text=True, env={**os.environ, "PYTHONUTF8": "1"})
    elapsed_ms = (time.perf_counter() - started) * 1000
    inner: dict[str, float] = {}
    if proc.stdout:
        try:
            inner = json.loads(proc.stdout.strip().splitlines()[-1])
        except (ValueError, IndexError):
            inner = {}
    return {"e2e_ms": elapsed_ms, **inner}


def main() -> int:
    rounds = 5
    print(f"Lib dir: {_LIB_DIR}")
    print(f"Python : {sys.version.split()[0]}")
    print()

    print("=== self-import measurement (warm in-process) ===")
    self_result = _self_measure()
    print(json.dumps(self_result, indent=2))
    print()

    print(f"=== subprocess cold start x{rounds} ===")
    e2e: list[float] = []
    imp: list[float] = []
    for i in range(rounds):
        r = _subprocess_round()
        e2e.append(r.get("e2e_ms", 0.0))
        imp.append(r.get("import_ms", 0.0))
        print(f"  round {i+1}: e2e={r.get('e2e_ms', 0):7.2f}ms  import={r.get('import_ms', 0):7.2f}ms  route={r.get('route_call_ms', 0):7.2f}ms")
    print()
    print("Summary (subprocess e2e):")
    print(f"  median: {statistics.median(e2e):7.2f}ms")
    print(f"  mean  : {statistics.mean(e2e):7.2f}ms")
    print(f"  max   : {max(e2e):7.2f}ms")
    print()
    if max(e2e) > 200:
        print("WARNING: at least one cold start exceeded the 200ms route budget.")
    else:
        print("OK: all cold starts within the 200ms route budget.")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
