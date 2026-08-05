"""Regression contract for the local performance-audit terminal flush."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
AUDIT_REL = Path("Common/Functions/Common_PerformanceAudit.sqf")
SLEEP_CALL = 'sleep (missionNamespace getVariable ["PerformanceAuditFlushInterval", 60]);'
FLUSH_CALL = "[_scope] call PerformanceAudit_Flush;"
TERMINAL_GUARD = 'if !(isNil "gameOver") then {\n\t\t\tif (gameOver) exitWith {};\n\t\t};'


def test_terminal_guard_precedes_periodic_flush_and_keeps_final_flush() -> None:
    sources = []

    for mission_root in MISSION_ROOTS:
        source = (mission_root / AUDIT_REL).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        sources.append(source.encode("utf-8"))

        run = source[source.index("PerformanceAudit_Run = {") :]
        assert SLEEP_CALL in run, mission_root.name
        assert TERMINAL_GUARD in run, mission_root.name

        sleep_pos = run.index(SLEEP_CALL)
        guard_pos = run.index(TERMINAL_GUARD)
        periodic_flush_pos = run.index(FLUSH_CALL)
        loop_close = run.index("\n\t};\n\n\t" + FLUSH_CALL)
        final_flush_pos = run.index(FLUSH_CALL, loop_close)

        assert sleep_pos < guard_pos < periodic_flush_pos, mission_root.name
        assert final_flush_pos > loop_close, mission_root.name
        assert run.count(FLUSH_CALL) == 2, mission_root.name

    assert all(source == sources[0] for source in sources[1:])
