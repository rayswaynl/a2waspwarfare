import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def test_player_blocked_terminal_recycle_yields_between_unit_deletes() -> None:
    for root in MISSION_ROOTS:
        recovery = (
            ROOT / root / "Common/Functions/Common_RunUnstuckRecovery.sqf"
        ).read_text(encoding="utf-8-sig")
        start = recovery.index("PATROL_RECYCLE_PLAYER_BLOCKED")
        end = recovery.index("if (!_uTerminal) then {", start)
        terminal = recovery[start:end]

        assert re.search(
            r"if \(!isNull _x && \{alive _x\} && \{!isPlayer _x\}\) then \{"
            r"\s*deleteVehicle _x;\s*sleep 0;\s*\};\s*\} forEach _uGroupUnits;",
            terminal,
        )
        assert terminal.index("sleep 0;") < terminal.index("_uHull = _x;")
