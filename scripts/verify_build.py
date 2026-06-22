#!/usr/bin/env python3
"""Verify DEX++ module lists stay in sync and source files exist."""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_build_modules() -> list[str]:
    return [name for names in load_module_groups().values() for name in names]


def load_shell_modules() -> list[str]:
    shell = (ROOT / "DEX++.luau").read_text(encoding="utf-8")
    match = re.search(r'Main\.ModuleList\s*=\s*\{([^}]+)\}', shell)
    if not match:
        raise RuntimeError("Main.ModuleList not found in DEX++.luau")
    return re.findall(r'"(\w+)"', match.group(1))


def resolve_module_path(name: str, groups: dict[str, list[str]]) -> Path:
    group = next(g for g, names in groups.items() if name in names)
    if name.endswith("Menu"):
        return ROOT / "Modules" / group / "ContextMenu" / f"{name}.luau"
    if group == "Roblox Assets Viewer":
        return ROOT / "Modules" / "Explorer" / "ContextMenu" / "Roblox Assets Viewer" / f"{name}.luau"
    return ROOT / "Modules" / group / f"{name}.luau"


def load_module_groups() -> dict[str, list[str]]:
    build_py = (ROOT / "build.py").read_text(encoding="utf-8")
    match = re.search(r"module_groups\s*=\s*(\{.*?\n    \})", build_py, re.DOTALL)
    if not match:
        raise RuntimeError("module_groups not found in build.py")
    return ast.literal_eval(match.group(1))


def main() -> int:
    errors: list[str] = []
    groups = load_module_groups()
    build_modules = load_build_modules()
    shell_modules = load_shell_modules()

    build_set = set(build_modules)
    shell_set = set(shell_modules)

    for name in sorted(shell_set - build_set):
        errors.append(f"Module '{name}' in DEX++.luau ModuleList but missing from build.py")
    for name in sorted(build_set - shell_set):
        errors.append(f"Module '{name}' in build.py but missing from DEX++.luau ModuleList")

    if len(build_modules) != len(build_set):
        errors.append("build.py module_groups contains duplicate module names")
    if len(shell_modules) != len(shell_set):
        errors.append("DEX++.luau ModuleList contains duplicate module names")

    for name in build_modules:
        path = resolve_module_path(name, groups)
        if not path.exists():
            alt = path.with_suffix(".lua")
            if not alt.exists():
                errors.append(f"Missing source file for module '{name}': {path.relative_to(ROOT)}")

    compiled = ROOT / "DEX++_compiled.luau"
    if compiled.exists():
        compiled_text = compiled.read_text(encoding="utf-8")
        for name in build_modules:
            needle = f'["{name}"] = function()'
            if needle not in compiled_text:
                errors.append(f"Compiled bundle missing embedded module '{name}' (re-run build.py)")

    if errors:
        print("verify_build: FAILED", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(f"verify_build: OK ({len(build_modules)} modules)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
