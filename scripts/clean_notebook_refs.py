#!/usr/bin/env python3
"""Remove stale Notebook dependency injection from DEX++ modules."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
modules = ROOT / "Modules"

for path in modules.rglob("*.luau"):
    text = path.read_text(encoding="utf-8")
    original = text
    text = text.replace(", Notebook", "")
    text = text.replace("Notebook = Apps.Notebook\n", "")
    text = text.replace("\tNotebook = Apps.Notebook\n", "")
    text = text.replace("\tNotebook = t.Notebook\n", "")
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"cleaned {path.relative_to(ROOT)}")
