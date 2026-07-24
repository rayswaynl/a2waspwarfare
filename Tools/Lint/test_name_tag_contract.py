#!/usr/bin/env python3
"""Static contract for the client-local friendly name-tag overlay."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
INIT = MISSION / "Client" / "Init" / "Init_Client.sqf"
MENU = MISSION / "Client" / "GUI" / "GUI_Menu.sqf"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def between(text: str, start: str, end: str) -> str:
    left = text.index(start)
    right = text.index(end, left)
    return text[left:right]


def test_name_tag_overlay_uses_local_state_and_cached_candidates() -> None:
    init = INIT.read_text(encoding="utf-8")
    menu = MENU.read_text(encoding="utf-8")
    overlay = between(init, "//--- qol-polish-pack: friendly name-tag overlay", "// Marty: Show the test build marker")
    toggle = between(menu, "if (MenuAction == 25)", "//--- A1 Commissar Panel")

    assert 'missionNamespace setVariable ["WFBE_NameTagsEnabled", WFBE_NameTagsEnabled];' in toggle, "WF-menu TAGS toggle must refresh the local namespace copy used by Settings"
    assert "_nextCandidateScan = time;" in overlay, "name-tag candidates must have an explicit local cache clock"
    assert "if (time >= _nextCandidateScan) then {" in overlay, "candidate enumeration must be cadence-gated"
    assert "_nextCandidateScan = time + 0.5;" in overlay, "candidate enumeration must run at 2Hz"
    assert "_playerCandidates = player nearEntities [[\"Man\"], 120];" in overlay, "player candidates must be cached locally"
    assert "_aiCandidates = player nearEntities [[\"Man\"], 150];" in overlay, "AI infantry candidates must be cached locally"
    assert "_vehicleCandidates = player nearEntities [[\"LandVehicle\",\"Air\",\"Ship\"], 200];" in overlay, "vehicle candidates must be cached locally"
    assert "} forEach _playerCandidates;" in overlay, "player projection must consume the cached candidates"
    assert "} forEach _crewPlayerCandidates;" in overlay, "mounted-player projection must consume the crew-walk candidates"
    assert "} forEach _aiCandidates;" in overlay, "AI projection must consume the cached candidates"
    assert overlay.count("} forEach _vehicleCandidates;") == 3, "scan crew-walk plus vehicle and tally projections must consume the shared cached candidates"
    assert "} forEach (crew _veh);" in overlay, "2Hz vehicle scan must walk crews for mounted friendly players"
    assert "TAGSTAT|v2|" in overlay, "smoke telemetry must emit TAGSTAT v2"
    for token in ("isPlayerCand=", "crewPlayerCand=", "sideFail=", "offscreen="):
        assert token in overlay, f"TAGSTAT v2 must emit the {token} discovery counter"
    assert "side player" not in overlay, "overlay filters must use sideJoined, never live side player"
    for filter_site in ("side _x == sideJoined", "side _aiunit == sideJoined", "side _vhc == sideJoined"):
        assert filter_site in overlay, f"same-side filter must read sideJoined: {filter_site}"
    assert '_x getVariable ["wfbe_kill_tally", 0]' in overlay, "kill tally must use the double-quoted A2-safe getVariable form"
    assert "private ['_tcnt'" not in overlay, "tally locals must live in the scheduler's outer private[] array"
    assert "publicVariable" not in overlay, "name-tag overlay must remain client-local"
    assert "createMarker" not in overlay and "setMarker" not in overlay, "name-tag overlay must not enter marker families"
    private_block = overlay[: overlay.index("_max = 18;")]
    for local in ("_nextCandidateScan", "_playerCandidates", "_aiCandidates", "_vehicleCandidates", "_crewPlayerCandidates", "_tagStatCycles", "_shownPlayers", "_shownAI", "_shownVehicles", "_shownTallies", "_veh", "_isPlayerCand", "_sideFail", "_offscreen", "_tcnt"):
        assert local in private_block, f"{local} must be declared in the scheduler's private[] array"
    for mirror in MIRRORS:
        assert (mirror / "Client" / "Init" / "Init_Client.sqf").read_bytes() == INIT.read_bytes(), f"Init_Client mirror drift: {mirror.name}"
        assert (mirror / "Client" / "GUI" / "GUI_Menu.sqf").read_bytes() == MENU.read_bytes(), f"GUI_Menu mirror drift: {mirror.name}"


if __name__ == "__main__":
    test_name_tag_overlay_uses_local_state_and_cached_candidates()
    print("test_name_tag_contract: PASS")
