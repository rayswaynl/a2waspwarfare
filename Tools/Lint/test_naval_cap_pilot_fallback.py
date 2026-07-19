#!/usr/bin/env python3
"""Regression coverage for GUER naval CAP pilot creation fallback."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
PILOT_FALLBACKS = (
    ("_jetPilot1", 2),
    ("_jetPilot2", 1),
    ("_hindPilot", 2),
    ("_hindPilot2", 1),
    ("_hindPilot3", 1),
    ("_biplPilot", 1),
)


def test_naval_cap_pilot_fallback_checks_the_created_object() -> None:
    for mission_root in MISSION_ROOTS:
        naval_path = mission_root / "Server/Init/Init_NavalHVT.sqf"
        lines = (ROOT / naval_path).read_text(encoding="utf-8").splitlines()

        for pilot_name, expected_count in PILOT_FALLBACKS:
            pilot_create_lines = [
                index
                for index, line in enumerate(lines)
                if f"{pilot_name} = _capGrp createUnit [(missionNamespace" in line
            ]
            assert len(pilot_create_lines) == expected_count, (
                f"unexpected CAP pilot creation count for {pilot_name} in {naval_path}"
            )

            for create_line in pilot_create_lines:
                fallback = lines[create_line + 1].strip()
                assert f"if (isNull {pilot_name}) then" in fallback, (
                    f"{pilot_name} fallback does not check the createUnit result in {naval_path}"
                )
                assert f'{pilot_name} = _capGrp createUnit ["GUE_Soldier"' in fallback, (
                    f"{pilot_name} has no default GUER pilot fallback in {naval_path}"
                )
                assert f'isNil "{pilot_name}"' not in fallback, (
                    f"{pilot_name} still tests variable existence, not object creation, in {naval_path}"
                )


if __name__ == "__main__":
    test_naval_cap_pilot_fallback_checks_the_created_object()
