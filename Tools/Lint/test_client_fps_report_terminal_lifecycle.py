"""Regression contract for client FPS report cancellation at round end."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
FPS_REPORT_REL = Path("Client/Functions/Client_FpsReport.sqf")
LOOP_START = 'while { !(missionNamespace getVariable ["WFBE_GameOver", false]) } do {'
TERMINAL_GUARD = 'if (missionNamespace getVariable ["WFBE_GameOver", false]) exitWith {};'


def test_fps_report_aborts_after_sampling_before_expensive_snapshot() -> None:
    sources = []

    for mission_root in MISSION_ROOTS:
        source = (mission_root / FPS_REPORT_REL).read_text(encoding="utf-8-sig")
        sources.append(source.encode("utf-8"))

        loop = source[source.index(LOOP_START) :]
        average_pos = loop.index("_avg = _sum / _n;")
        assert TERMINAL_GUARD in loop, mission_root.name
        guard_pos = loop.index(TERMINAL_GUARD)
        snapshot_pos = loop.index("_nearStart = diag_tickTime;")
        publish_pos = loop.index('publicVariableServer "WFBE_FPS_REPORT"')

        assert loop.count(TERMINAL_GUARD) == 1, mission_root.name
        assert average_pos < guard_pos < snapshot_pos, mission_root.name
        assert guard_pos < publish_pos, mission_root.name

    assert all(source == sources[0] for source in sources[1:])
