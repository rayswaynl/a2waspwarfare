"""Regression contract for the optional GUER scavenger vehicle census.

``allDead`` only returns dead or destroyed objects.  The scavenger path keeps
only ``alive _x`` objects, so an ``allDead`` pass can never contribute a
candidate and only adds an unnecessary engine-wide scan.  The maintained
Chernarus/Takistan/Zargabad GUER wildcard mirrors must keep the same contract.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCAVENGER_PATHS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Functions" / "AI_Commander_Wildcard_GUER.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Server" / "Functions" / "AI_Commander_Wildcard_GUER.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Server" / "Functions" / "AI_Commander_Wildcard_GUER.sqf",
)


def test_scavenger_does_not_scan_unreachable_dead_objects() -> None:
    for scavenger_path in SCAVENGER_PATHS:
        source = scavenger_path.read_text(encoding="utf-8-sig")

        assert "forEach allDead" not in source, scavenger_path
        assert source.count('forEach allMissionObjects "LandVehicle"') == 2, scavenger_path


if __name__ == "__main__":
    test_scavenger_does_not_scan_unreachable_dead_objects()
