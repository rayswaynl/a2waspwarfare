"""Contract for bounded scheduling in the visible team-marker scan."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "FSM"
    / "updateteamsmarkers.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Client"
    / "FSM"
    / "updateteamsmarkers.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Client"
    / "FSM"
    / "updateteamsmarkers.sqf",
]


def test_team_marker_scan_yields_between_bounded_batches():
    for source_path in SOURCES:
        source = source_path.read_text(encoding="utf-8")
        scan = source[
            source.index("_count = 1;") : source.index("// Marty: Performance Audit record")
        ]

        assert "_teamMarkerSliceEvery = 8;" in scan
        assert "_teamMarkerSliceIndex = _teamMarkerSliceIndex + 1;" in scan
        assert "if ((_teamMarkerSliceIndex % _teamMarkerSliceEvery) == 0) then {sleep 0;};" in scan


if __name__ == "__main__":
    test_team_marker_scan_yields_between_bounded_batches()
