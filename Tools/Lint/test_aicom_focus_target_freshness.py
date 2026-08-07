"""Regression contract for deferred AICOM focus town references."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
ALLOCATE_PATH = "Server/AI/Commander/AI_Commander_Allocate.sqf"
FOCUS_SNAPSHOT_ASSIGNMENT = "_focusTowns = _snap select WFBE_SNAP_TGTTOWNOBJS;"
FOCUS_POOL_ASSIGNMENT = "_tgtTowns = _focusTowns;"
FOCUS_MEMBERSHIP_GUARD = "&& {_focusTgt in _focusTowns}"


def _focus_gate(source: str) -> str:
    start = source.index('if (!isNil "_focusTgt"')
    end = source.index("_fist = [_focusTgt];", start)
    return source[start:end]


def test_focus_read_requires_current_capturable_town_identity():
    """A captured or replaced focus object must not become the allocator fist."""
    sources = []
    for mission_root in MISSION_ROOTS:
        raw_source = (mission_root / ALLOCATE_PATH).read_bytes()
        source = raw_source.decode("utf-8-sig")
        sources.append(raw_source)

        private_start = source.index("private [")
        private_end = source.index(";", private_start)
        assert '"_focusTowns"' in source[private_start:private_end]
        assert FOCUS_SNAPSHOT_ASSIGNMENT in source
        assert FOCUS_POOL_ASSIGNMENT in source
        assert source.index(FOCUS_SNAPSHOT_ASSIGNMENT) < source.index(FOCUS_POOL_ASSIGNMENT)
        assert source.index(FOCUS_POOL_ASSIGNMENT) < source.index("if (count _tgtTowns == 0)")

        gate = _focus_gate(source)
        assert FOCUS_MEMBERSHIP_GUARD in gate
        assert gate.index('&& {(time - _focusT0)') < gate.index(FOCUS_MEMBERSHIP_GUARD)
        assert gate.index(FOCUS_MEMBERSHIP_GUARD) < gate.index(
            '&& {(_focusTgt getVariable ["sideID", _sideID]) != _sideID}) then {'
        )

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_focus_read_requires_current_capturable_town_identity()
    print("AICOM focus target freshness contract: PASS")
