#!/usr/bin/env python3
"""Reject changed faction configuration files unreachable on their terrain."""

from __future__ import annotations

import argparse
import re
import subprocess
from collections.abc import Iterable


TERRAIN_FACTIONS = {
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/": {"USMC", "RU", "GUE"},
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/": {"US", "TKA", "TKGUE"},
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/": {"US", "TKA", "TKGUE"},
}

FACTION_CONFIG_PATTERN = re.compile(
    r"Common/Config/(?:Core_Root/Root|Defenses/Defenses|Groups/Groups|"
    r"Core_Artillery/Artillery)_(?P<faction>[A-Za-z0-9_]+)\.sqf$"
)


def find_unreachable_paths(paths: Iterable[str]) -> list[str]:
    """Return changed faction config paths whose fixed terrain cannot load them."""
    unreachable = []
    for path in paths:
        normalized = path.replace("\\", "/")
        match = FACTION_CONFIG_PATTERN.search(normalized)
        if match is None:
            continue

        for terrain, live_factions in TERRAIN_FACTIONS.items():
            if terrain in normalized and match.group("faction") not in live_factions:
                unreachable.append(path)
                break
    return unreachable


def changed_paths(diff_from: str) -> list[str]:
    """Read added, copied, modified, or renamed paths relative to a Git ref."""
    completed = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", f"{diff_from}...HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [path for path in completed.stdout.splitlines() if path]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Reject edited faction config files unreachable on their terrain."
    )
    parser.add_argument("paths", nargs="*", help="Repository-relative paths to check.")
    parser.add_argument(
        "--diff-from",
        metavar="REF",
        help="Check changed paths between REF and HEAD instead of explicit paths.",
    )
    args = parser.parse_args()

    if args.diff_from and args.paths:
        parser.error("pass explicit paths or --diff-from, not both")
    paths = changed_paths(args.diff_from) if args.diff_from else args.paths
    unreachable = find_unreachable_paths(paths)

    for path in unreachable:
        print(f"{path}: FAREACH: faction configuration is unreachable on this terrain")
    return 1 if unreachable else 0


if __name__ == "__main__":
    raise SystemExit(main())
