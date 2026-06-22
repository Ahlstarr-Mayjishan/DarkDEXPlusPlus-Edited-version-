#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / "HelperServer" / "Dashboard.h").read_text(encoding="utf-8")
match = re.search(r'R"DEXAPP\((.*)\)DEXAPP";', src, re.DOTALL)
if not match:
    raise SystemExit("dashboard marker not found")

out_dir = ROOT / "HelperServer" / "dashboard"
out_dir.mkdir(exist_ok=True)
target = out_dir / "index.html"
target.write_text(match.group(1), encoding="utf-8")
print(f"Wrote {target} ({target.stat().st_size} bytes)")
