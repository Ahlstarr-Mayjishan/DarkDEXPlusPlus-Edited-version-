#!/usr/bin/env python3
"""Migrate dex_helper.db from relative paths to fixed path.

Finds all old dex_helper.db files across the filesystem,
selects the one with the most entries, and copies it to:
    %LOCALAPPDATA%\\DEX++Helper\\dex_helper.db
"""

import os
import sqlite3
import shutil
import sys
from pathlib import Path

APPDATA = Path(os.getenv("LOCALAPPDATA", ""))
NEW_DB_DIR = APPDATA / "DEX++Helper"
NEW_DB_PATH = NEW_DB_DIR / "dex_helper.db"

SEARCH_ROOTS = [
    Path("D:/Scripting/Rework DarkDEX++"),
    Path("D:/Scripting/Rework DarkDEX++/HelperServer"),
    Path.home() / "Desktop",
    Path.home(),
    Path("C:/Program Files"),
    Path("C:/Program Files (x86)"),
]


def count_entries(db_path: Path) -> int:
    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM indexed_scripts")
        count = cur.fetchone()[0]
        conn.close()
        return count
    except Exception:
        return -1


def find_old_dbs() -> list[tuple[Path, int]]:
    results = []
    seen_paths = set()

    for root in SEARCH_ROOTS:
        if not root.exists():
            continue
        for db_path in root.rglob("dex_helper.db"):
            if db_path in seen_paths:
                continue
            seen_paths.add(db_path)
            count = count_entries(db_path)
            results.append((db_path, count))

    results.sort(key=lambda x: x[1], reverse=True)
    return results


def main():
    print("=" * 60)
    print("DEX++ Helper DB Migration Script")
    print("=" * 60)
    print()

    old_dbs = find_old_dbs()

    if not old_dbs:
        print("No old dex_helper.db found.")
        print("A fresh database will be created on first run.")
        return

    print(f"Found {len(old_dbs)} old database(s):")
    print(f"{'Count':>10}  Path")
    print("-" * 60)
    for path, count in old_dbs:
        size_kb = path.stat().st_size // 1024
        print(f"{count:>10}  {path} ({size_kb} KB)")

    print()

    if NEW_DB_PATH.exists():
        current_count = count_entries(NEW_DB_PATH)
        print(f"New location already has a DB with {current_count} entries.")
        best = old_dbs[0]
        if best[1] > current_count:
            print(f"Better DB found ({best[1]} entries). Will overwrite.")
            overwrite = True
        else:
            print(f"Keeping existing DB. No migration needed.")
            return
    else:
        overwrite = False
        best = old_dbs[0]
        print(f"Will copy best DB ({best[1]} entries) to new location.")

    print()
    NEW_DB_DIR.mkdir(parents=True, exist_ok=True)

    if overwrite and NEW_DB_PATH.exists():
        bak_path = NEW_DB_PATH.with_suffix(".db.bak")
        shutil.copy2(NEW_DB_PATH, bak_path)
        print(f"Backed up existing DB to: {bak_path}")

    shutil.copy2(best[0], NEW_DB_PATH)
    print()
    print(f"Migration complete!")
    print(f"New DB location: {NEW_DB_PATH}")
    print(f"Copied from:     {best[0]}")
    print(f"Total entries:   {best[1]}")

    if len(old_dbs) > 1:
        print()
        print(f"Old DB files found ({len(old_dbs)}):")
        for path, _ in old_dbs:
            print(f"  {path}")
        print("You can delete them manually if no longer needed.")


if __name__ == "__main__":
    main()
