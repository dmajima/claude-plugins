"""Research S3: probe whether ${CLAUDE_PLUGIN_DATA} is provided in the runtime env.

Run directly (not as a hook) to inspect the result, e.g.:
  python references/research/s3_plugin_data_var.py

Outputs:
  - presence (bool)
  - resolved path (if any)
  - writable check (touch a temp file)
  - sibling vars (CLAUDE_PLUGIN_ROOT, CLAUDE_PROJECT_DIR, CLAUDE_SESSION_ID)
"""
from __future__ import annotations

import os
import sys
from pathlib import Path


def _check_writable(path: Path) -> bool:
    try:
        path.mkdir(parents=True, exist_ok=True)
        probe = path / ".s3_probe.tmp"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink(missing_ok=True)
        return True
    except OSError:
        return False


def main() -> int:
    var = "CLAUDE_PLUGIN_DATA"
    raw = os.environ.get(var, "")
    print(f"{var} present: {bool(raw)}")
    if raw:
        path = Path(raw)
        print(f"  raw value : {raw}")
        print(f"  exists    : {path.exists()}")
        print(f"  writable  : {_check_writable(path)}")

    print()
    print("Sibling Claude Code variables:")
    for sibling in ("CLAUDE_PLUGIN_ROOT", "CLAUDE_PROJECT_DIR", "CLAUDE_SESSION_ID"):
        val = os.environ.get(sibling, "")
        print(f"  {sibling:<22} = {val!r}")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
