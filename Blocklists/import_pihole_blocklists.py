#!/usr/bin/env python3
"""
import_pihole_blocklists.py

Imports Pi-hole blocklists from a remote or local text file into the
Pi-hole gravity database.

What it does
------------
- Downloads PiHoleBlocklistSources.txt from the GitHub repo (or reads a local copy)
- Parses each URL, skipping blank lines and comments
- Inserts each URL into Pi-hole's gravity.db adlist table
- Skips duplicates automatically via INSERT OR IGNORE
- Runs pihole -g to update gravity after all inserts

Requirements
------------
- Must be run as root on the Pi-hole host
- Python 3.6+
- requests library (pip install requests)

Examples
--------
sudo python3 import_pihole_blocklists.py

sudo python3 import_pihole_blocklists.py --local-file ./PiHoleBlocklistSources.txt

sudo python3 import_pihole_blocklists.py --skip-gravity-update

sudo python3 import_pihole_blocklists.py \
    --blocklist-url https://raw.githubusercontent.com/mickpletcher/PiHole/main/Blocklists/PiHoleBlocklistSources.txt \
    --gravity-db /etc/pihole/gravity.db

Author
------
Mick Pletcher
"""

from __future__ import annotations

import argparse
import os
import platform
import sqlite3
import subprocess
import sys
import time
from typing import List, Optional

import requests


DEFAULT_BLOCKLIST_URL = "https://raw.githubusercontent.com/mickpletcher/PiHole/main/Blocklists/PiHoleBlocklistSources.txt"
DEFAULT_GRAVITY_DB    = "/etc/pihole/gravity.db"


# ==========================================================================================
# VALIDATION
# ==========================================================================================

def validate_prerequisites(gravity_db: str) -> None:
    if platform.system() == "Windows":
        raise RuntimeError("This script must be run on the Pi-hole host (Linux). It cannot be run on Windows.")

    if os.geteuid() != 0:
        raise RuntimeError("This script must be run as root. Try: sudo python3 import_pihole_blocklists.py")

    if not os.path.isfile(gravity_db):
        raise RuntimeError(f"Pi-hole gravity database not found at: {gravity_db}")


# ==========================================================================================
# LOAD BLOCKLIST FILE
# ==========================================================================================

def load_blocklist_urls(blocklist_url: str, local_file: Optional[str]) -> List[str]:
    lines: List[str] = []

    if local_file:
        if not os.path.isfile(local_file):
            raise RuntimeError(f"Local file not found: {local_file}")
        print(f"Reading blocklists from local file: {local_file}")
        with open(local_file, "r", encoding="utf-8") as f:
            lines = f.readlines()
    else:
        print(f"Downloading blocklists from: {blocklist_url}")
        try:
            response = requests.get(blocklist_url, timeout=30)
            response.raise_for_status()
            lines = response.text.splitlines()
        except requests.RequestException as exc:
            raise RuntimeError(f"Failed to download PiHoleBlocklistSources.txt: {exc}") from exc

    urls: List[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            continue
        urls.append(stripped)

    return urls


# ==========================================================================================
# DATABASE HELPERS
# ==========================================================================================

def get_existing_adlist_urls(conn: sqlite3.Connection) -> set:
    cursor = conn.execute("SELECT address FROM adlist;")
    return {row[0].strip() for row in cursor.fetchall()}


def insert_adlist_url(conn: sqlite3.Connection, url: str) -> None:
    conn.execute(
        """
        INSERT OR IGNORE INTO adlist (address, enabled, date_added, comment)
        VALUES (?, 1, strftime('%s', 'now'), 'Imported by import_pihole_blocklists.py')
        """,
        (url,),
    )


# ==========================================================================================
# GRAVITY UPDATE
# ==========================================================================================

def run_gravity_update() -> None:
    print("\nUpdating Pi-hole gravity. This may take a few minutes...")
    result = subprocess.run(["pihole", "-g"], check=False)
    if result.returncode != 0:
        print(f"[warn] pihole -g exited with code {result.returncode}. Check Pi-hole logs for details.", file=sys.stderr)
    else:
        print("Gravity update complete.")


# ==========================================================================================
# MAIN
# ==========================================================================================

def run(args: argparse.Namespace) -> int:
    validate_prerequisites(args.gravity_db)

    urls = load_blocklist_urls(args.blocklist_url, args.local_file)
    print(f"Found {len(urls)} URLs to process.")

    conn = sqlite3.connect(args.gravity_db)

    try:
        existing = get_existing_adlist_urls(conn)

        added   = 0
        skipped = 0

        for url in urls:
            if url in existing:
                print(f"  [skip]  {url}")
                skipped += 1
            else:
                print(f"  [add]   {url}")
                insert_adlist_url(conn, url)
                added += 1

        conn.commit()

    finally:
        conn.close()

    print(f"\nImport complete.")
    print(f"  Added   : {added}")
    print(f"  Skipped : {skipped} (already existed)")

    if args.skip_gravity_update:
        print("\nSkipping gravity update (--skip-gravity-update flag set).")
        print("Run 'pihole -g' manually to apply the new lists.")
    else:
        run_gravity_update()

    return 0


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Import Pi-hole blocklists from a remote or local text file into the Pi-hole gravity database."
    )
    parser.add_argument(
        "--blocklist-url",
        default=DEFAULT_BLOCKLIST_URL,
        help="URL to the raw PiHoleBlocklistSources.txt file. Defaults to the GitHub raw URL."
    )
    parser.add_argument(
        "--local-file",
        default=None,
        help="Path to a local PiHoleBlocklistSources.txt file. If supplied, skips the download."
    )
    parser.add_argument(
        "--gravity-db",
        default=DEFAULT_GRAVITY_DB,
        help=f"Path to the Pi-hole gravity database. Defaults to {DEFAULT_GRAVITY_DB}."
    )
    parser.add_argument(
        "--skip-gravity-update",
        action="store_true",
        help="If set, skips running pihole -g after inserting. Useful for testing."
    )
    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()

    try:
        return run(args)
    except Exception as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
