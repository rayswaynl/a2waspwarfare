"""Regression contract for SkinSelector old-body cleanup and squad-cap counting."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
SKIN_RELATIVE = Path("WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
BUY_RELATIVE = Path("Client/GUI/GUI_Menu_BuyUnits.sqf")
SERVER_INIT = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf"
)
GHOST_TAG = '"wasp_skinswap_ghost", true, true'
REQUEST_NAME = "WFBE_SkinSwapGhostDeleteRequest"


def test_skinswap_ghost_cleanup_is_bounded_and_escalates_to_server() -> None:
    for mission_root in MISSION_ROOTS:
        source = (ROOT / mission_root / SKIN_RELATIVE).read_text(encoding="utf-8")

        assert GHOST_TAG in source, f"old body is not ghost-tagged in {mission_root}"
        assert "_ghostRetries < 60" in source, f"cleanup is not bounded to 120 seconds in {mission_root}"
        assert "sleep 2;" in source, f"cleanup retry cadence is missing in {mission_root}"
        assert f'publicVariableServer "{REQUEST_NAME}"' in source, (
            f"surviving old body is not escalated to the server in {mission_root}"
        )

    server_source = (ROOT / SERVER_INIT).read_text(encoding="utf-8")
    assert f'"{REQUEST_NAME}" addPublicVariableEventHandler' in server_source
    assert 'getVariable ["wasp_skinswap_ghost", false]' in server_source
    assert "while {!isNull _ghost && {isPlayer _ghost} && {_serverRetries < 15}} do {" in server_source
    assert "if (isPlayer _ghost) exitWith {" in server_source


def test_buy_units_excludes_tagged_ghosts_from_both_squad_cap_reads() -> None:
    guard = 'getVariable ["wasp_skinswap_ghost", false]'
    for mission_root in MISSION_ROOTS:
        source = (ROOT / mission_root / BUY_RELATIVE).read_text(encoding="utf-8")

        assert source.count(guard) >= 2, (
            f"purchase gate and squad display do not both exclude ghosts in {mission_root}"
        )
        assert "_size = _size +" in source
        assert "_capAlive = _capAlive +" in source
