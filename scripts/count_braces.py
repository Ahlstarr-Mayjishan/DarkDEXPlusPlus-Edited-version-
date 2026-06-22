import re
from pathlib import Path

text = Path("HelperServer/Routes.cpp").read_text(encoding="utf-8")
stripped = re.sub(r'"(\\.|[^"\\])*"', '""', text)
depth = 0
for i, line in enumerate(stripped.splitlines(), 1):
    prev = depth
    for ch in line:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
    if depth != prev and i >= 380:
        print(f"{i:4} depth {prev}->{depth}: {line.strip()[:90]}")
