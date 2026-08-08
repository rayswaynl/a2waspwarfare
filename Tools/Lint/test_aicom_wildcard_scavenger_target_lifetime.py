"""Regression contract for the GUER scavenger's delayed wreck resolution."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
WILDCARD_PATH = "Server/Functions/AI_Commander_Wildcard_GUER.sqf"

WATCHER_MARKER = "//--- WATCHER: iterate wrecks, scav each, pay reward, delete; TTL or wipe -> cleanup."
SCAVENGE_DELAY = "sleep 30; _el = _el + 30;"
RESOLUTION_GUARD = (
    "if (_alive && {_el < _ttl} && {!isNull _bestV} && {alive _bestV} && "
    '{_bestV getVariable ["wfbe_aicom_abandoned", false]}) then {'
)
TYPE_SNAPSHOT = "_bestVType = typeOf _bestV;"
DELETE_TARGET = "if (!isNull _bestV) then {deleteVehicle _bestV};"
TYPE_LOG = '|type=" + _bestVType + "|remaining='


def _watcher_block(source: str) -> str:
    start = source.index(WATCHER_MARKER)
    end = source.index("//--- Logging (mirror the conventional worker's AICOMSTAT line).", start)
    return source[start:end]


def test_guer_scavenger_revalidates_delayed_wreck_before_payout():
    """A wreck removed during the 30s delay must not receive a false bounty."""
    sources = []
    for mission_root in MISSION_ROOTS:
        source = (mission_root / WILDCARD_PATH).read_text(encoding="utf-8-sig")
        sources.append(source.encode("utf-8"))
        watcher = _watcher_block(source)

        assert SCAVENGE_DELAY in watcher
        assert RESOLUTION_GUARD in watcher
        assert watcher.index(SCAVENGE_DELAY) < watcher.index(RESOLUTION_GUARD)
        assert TYPE_SNAPSHOT in watcher
        assert watcher.index(TYPE_SNAPSHOT) < watcher.index(DELETE_TARGET)
        assert TYPE_LOG in watcher
        assert watcher.index(DELETE_TARGET) < watcher.index(TYPE_LOG)
        assert watcher.count("_vehs = _vehs - [_bestV];") == 2

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_guer_scavenger_revalidates_delayed_wreck_before_payout()
    print("AICOM GUER scavenger target lifetime contract: PASS")
