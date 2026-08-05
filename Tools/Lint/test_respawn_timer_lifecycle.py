"""Regression contract for the asynchronous respawn countdown lifecycle.

The respawn menu clears ``WFBE_RespawnTime`` while its countdown worker may be
sleeping.  The worker must therefore guard both its loop condition and its
post-sleep decrement against the value being cleared before it resumes.

This is intentionally a source contract: the repository has no SQF runtime in
CI.  A fresh client RPT remains the runtime acceptance gate.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RESPAWN_FILES = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_RespawnMenu.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/GUI/GUI_RespawnMenu.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/GUI/GUI_RespawnMenu.sqf"),
)

COUNTDOWN_MARKER = (
    "\t[_respawnTimerToken] Spawn {\n"
    "\t\tprivate [\"_timerToken\"];\n"
)
TOKEN_SETUP = (
    "\t_respawnTimerToken = diag_tickTime;\n"
    "\tWFBE_RespawnTimerToken = _respawnTimerToken;\n"
)
LOOP_GUARD = (
    '\t\twhile {!isNil "WFBE_RespawnTime" && {WFBE_RespawnTime > 0} '
    '&& {!isNil "WFBE_RespawnTimerToken"} '
    '&& {WFBE_RespawnTimerToken == _timerToken}} do {'
)
DECREMENT_GUARD = (
    '\t\t\tif (!isNil "WFBE_RespawnTime" '
    '&& {!isNil "WFBE_RespawnTimerToken"} '
    '&& {WFBE_RespawnTimerToken == _timerToken}) then {\n'
    '\t\t\t\tWFBE_RespawnTime = WFBE_RespawnTime - 1;\n'
    '\t\t\t};'
)


def _countdown_block(source: str) -> str:
    start = source.index(COUNTDOWN_MARKER)
    end = source.index("\n\t};\n};", start) + len("\n\t};\n};")
    return source[start:end]


def test_respawn_countdown_stops_cleanly_when_menu_clears_timer() -> None:
    sources = []
    for relative_path in RESPAWN_FILES:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        block = _countdown_block(source)
        sources.append(source)

        assert TOKEN_SETUP in source
        assert LOOP_GUARD in block
        assert DECREMENT_GUARD in block
        assert "while {WFBE_RespawnTime > 0} do {" not in block

    assert sources[1:] == [sources[0], sources[0]]


if __name__ == "__main__":
    test_respawn_countdown_stops_cleanly_when_menu_clears_timer()
    print("PASS: respawn countdown guards cleared timer state")
