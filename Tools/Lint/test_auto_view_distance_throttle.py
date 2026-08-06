from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AutomaticViewDistance.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_AutomaticViewDistance.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_AutomaticViewDistance.sqf",
)


def test_auto_view_distance_adjustment_is_cooldown_gated():
    for path in MIRRORS:
        source = path.read_text(encoding="utf-8-sig")
        guard = "if (_now < _nextAdjust) exitWith {};"
        assert guard in source, f"{path}: missing adaptive-view-distance cooldown guard"
        gate = source.index(guard)

        assert "_nextAdjust" in source, f"{path}: missing adaptive-view-distance deadline"
        assert "_now + 3" in source, f"{path}: missing three-second adjustment interval"
        writes = re.findall(r"(?m)^[ \t]*setViewDistance\b", source)
        assert len(writes) == 2, f"{path}: unexpected view-distance write count"
        write_positions = [
            match.start() for match in re.finditer(r"(?m)^[ \t]*setViewDistance\b", source)
        ]
        assert gate < min(write_positions), (
            f"{path}: cooldown must guard both engine view-distance writes"
        )


def test_auto_view_distance_mirrors_are_identical():
    normalized = [path.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for path in MIRRORS]
    assert normalized[0] == normalized[1] == normalized[2]
