"""Regression contract for the GUER Director startup readiness gate.

The Director is launched before the server starting-mode assignment.  It must
not seed its GUER ledger while town side IDs are still unset, nor remain parked
forever when town initialization cannot become ready.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DIRECTOR_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Server_GuerDirector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Server_GuerDirector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Server_GuerDirector.sqf"),
)


def read(relative: Path) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def test_guer_director_waits_for_true_town_startup_readiness() -> None:
    for relative in DIRECTOR_PATHS:
        text = read(relative)

        assert 'waitUntil {!isNil "towns"};' not in text
        assert "waitUntil {count towns > 0};" not in text
        assert 'waitUntil {!isNil "townInitServer"};' not in text
        assert "_gdirTownInitDeadline = diag_tickTime + 420;" in text
        assert "diag_tickTime + 90;" not in text
        assert "while {!_gdirTownReady && {diag_tickTime < _gdirTownInitDeadline}" in text
        assert '_gdirTownInitServerReady = missionNamespace getVariable ["townInitServer", false];' in text
        assert '_gdirTownsReady = !isNil "towns" && {count towns > 0};' in text
        assert "sleep 0.25;" in text
        assert "GDIR_STARTUP_TIMEOUT" in text
        assert "if (!_gdirTownReady) exitWith" in text


def test_guer_director_startup_gate_remains_after_flag_and_singleton_guards() -> None:
    text = read(DIRECTOR_PATHS[0])

    assert text.index("AICOMV2_LANE_GUER_DIRECTOR") < text.index("_gdirTownInitDeadline")
    assert text.index("AICOMV2_GDIR_INSTANCE") < text.index("_gdirTownInitDeadline")


def test_guer_director_exits_when_mission_generation_is_superseded() -> None:
    for relative in DIRECTOR_PATHS:
        text = read(relative)

        assert 'AICOMV2_GDIR_MISSION_TOKEN' in text
        assert "_gdirMissionToken = format" in text
        assert 'missionNamespace setVariable ["AICOMV2_GDIR_MISSION_TOKEN", _gdirMissionToken];' in text
        assert 'missionNamespace getVariable ["AICOMV2_GDIR_MISSION_TOKEN", ""]' in text
        assert "GDIR_STALE_GENERATION" in text
        assert "while {!WFBE_GameOver &&" in text
        assert "== _gdirMissionToken" in text
        post_sleep_guard = 'sleep _tickSec;\n    if ((missionNamespace getVariable ["AICOMV2_GDIR_MISSION_TOKEN", ""]) != _gdirMissionToken) exitWith {\n        diag_log "AICOMSTAT|v3|DIRECTOR|GUER|0|GDIR_STALE_GENERATION";\n    };\n    _tick  = _tick + 1;'
        assert post_sleep_guard in text
        assert text.index(post_sleep_guard) < text.index("// PHASE 0")
        startup_guard = 'while {!_gdirTownReady && {diag_tickTime < _gdirTownInitDeadline} && {!(missionNamespace getVariable ["WFBE_GameOver", false])} && {(missionNamespace getVariable ["AICOMV2_GDIR_MISSION_TOKEN", ""]) == _gdirMissionToken}} do {'
        assert startup_guard in text


def test_guer_director_mirrors_are_byte_identical() -> None:
    blobs = [(ROOT / relative).read_bytes() for relative in DIRECTOR_PATHS]
    assert blobs[0] == blobs[1] == blobs[2]


if __name__ == "__main__":
    test_guer_director_waits_for_true_town_startup_readiness()
    test_guer_director_startup_gate_remains_after_flag_and_singleton_guards()
    test_guer_director_exits_when_mission_generation_is_superseded()
    test_guer_director_mirrors_are_byte_identical()
    print("GUER Director startup readiness contract: PASS")
