#!/usr/bin/env python3
"""Regression checks for the town air-tier activation wiring.

The game runtime is not available in CI, so this keeps the essential control-flow
contract explicit: an air-only contact must contribute to the activation gate
before that gate executes and must retain a zero ground component for the AA tier.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


RELATIVE_SOURCE = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf"
)


def read_source(root: Path, git_ref: str | None) -> str:
    if git_ref is None:
        return (root / RELATIVE_SOURCE).read_text(encoding="utf-8")
    result = subprocess.run(
        ["git", "-C", str(root), "show", f"{git_ref}:{RELATIVE_SOURCE.as_posix()}"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def require(source: str, text: str, detail: str) -> int:
    if text in source:
        return source.index(text)
    raise AssertionError(detail)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--git-ref", help="read the mission source at this git ref")
    args = parser.parse_args()
    source = read_source(args.root.resolve(), args.git_ref)

    scan_end = require(
        source,
        "} else {_currentEnemies = 0; _enemies = 0;};",
        "town scan must finish before the activation gate",
    )
    activation_gate = require(
        source,
        "if(_enemies > 0)then{",
        "activation gate is missing",
    )
    assert scan_end < activation_gate, "activation gate must follow the town scan"

    air_fold = require(
        source,
        "_enemies = count _detectedAir;",
        "air-only contact must contribute to _enemies",
    )
    assert air_fold < activation_gate, (
        "air-only contact is still folded after the _enemies > 0 activation gate"
    )

    require(
        source,
        "_enemies_ground = _currentEnemies;",
        "air-only contact must retain a zero ground component for the AA tier",
    )
    require(
        source,
        "(side _x) in _airHostileSides",
        "only hostile high-air contacts may wake a town",
    )
    assert "((getPos _x) select 2) > 20" not in source, (
        "low-flying aircraft still bypass the AA-only contact path"
    )
    require(
        source,
        "if (!(_x isKindOf \"Air\")) then {",
        "aircraft must be excluded from the ground-contact collection",
    )
    require(
        source,
        "AIR-TIER ACTIVATED",
        "air-tier activation must emit one observable liveness line",
    )
    require(
        source,
        "if (_enemies_ground > 0) then {\n\t\t\t\t\t\t\tif (missionNamespace getVariable Format [\"WFBE_%1_PRESENT\",_side]) then {[_side,\"HostilesDetectedNear\",_town] Spawn SideMessage};",
        "air-only activation must not send the full-garrison side message",
    )
    require(
        source,
        "if (_enemies_ground > 0) then {\n\t\t\t\t\t\t\t[_town, _side, \"spawn\"] Call WFBE_SE_FNC_OperateTownDefensesUnits;\n\t\t\t\t\t\t\t[getPos _town, _side] Call WFBE_CO_FNC_SpawnFactionSmoke;",
        "air-only activation must not man statics or spawn faction smoke",
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
