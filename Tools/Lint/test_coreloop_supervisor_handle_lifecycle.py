from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SUPERVISOR = Path("Server/FSM/server_coreloop_supervisor.sqf")


def _source(mission: Path) -> str:
    return (mission / SUPERVISOR).read_text(encoding="utf-8")


def test_finished_registered_handle_is_detected_before_first_heartbeat() -> None:
    for mission in MISSION_DIRS:
        source = _source(mission)

        probe_start = source.index("if (_hb <= 0) then {")
        probe = source[probe_start : probe_start + 400]
        assert "_oldHandle = missionNamespace getVariable _handleKey;" in probe
        assert 'if (!isNil "_oldHandle") then {' in probe
        assert "_deadBeforeFirstBeat = scriptDone _oldHandle;" in probe

        assert "if ((_hb > 0) || {_deadBeforeFirstBeat}) then {" in source
        assert "if (_deadBeforeFirstBeat || {_age > _thresh}) then {" in source
        assert (
            '_failureReason = if (_deadBeforeFirstBeat) then '
            '{"ended-before-first-heartbeat"} else {"stale-heartbeat"};'
        ) in source
        assert '"|reason=" + _failureReason' in source


def test_supervisor_mirrors_keep_identical_handle_lifecycle_contract() -> None:
    sources = [(mission / SUPERVISOR).read_bytes() for mission in MISSION_DIRS]
    assert all(source == sources[0] for source in sources[1:])
