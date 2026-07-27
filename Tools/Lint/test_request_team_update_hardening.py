"""Static contracts for the RequestTeamUpdate capability-bound hardening lane."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
    Path("Modded_Missions/[55-2hc]warfarev2_073v48co.eden"),
    Path("Modded_Missions/[55-2hc]warfarev2_073v48co.Napf"),
    Path("Modded_Missions/[55-2hc]warfarev2_073v48co.lingor"),
)

CANONICAL_ROOTS = MISSION_ROOTS[:3]
MODDED_ROOTS = MISSION_ROOTS[3:]


def read(root: Path, relative: str) -> str:
    return (ROOT / root / relative).read_text(encoding="utf-8-sig")


def test_server_handler_binds_requester_to_commander_and_consumes_before_effects():
    for root in MISSION_ROOTS:
        source = read(root, "Server/PVFunctions/RequestTeamUpdate.sqf")

        for required in (
            'missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]',
            "WFBE_SE_FNC_MintCapability",
            "WFBE_SE_FNC_ConsumeCapability",
            "WFBE_CO_FNC_GetCommanderTeam",
            "group _requester",
            "leader _commanderTeam",
            "isPlayer _requester",
            "alive _requester",
            '"team-update"',
            '"team-update-capability"',
            "setBehaviour",
            "setCombatMode",
            "setFormation",
            "setSpeedMode",
            'typeName _team == "SIDE"',
            "_team != _requesterSide",
        ):
            assert required in source, f"{root}: missing {required!r}"

        consume = source.index("WFBE_SE_FNC_ConsumeCapability")
        first_effect = source.index("setBehaviour")
        assert consume < first_effect

        assert "side _x != _requesterSide" in source
        assert "typeName _x != \"GROUP\"" in source
        assert '"ECH  RIGHT"' in source
        assert "if (_rejected) exitWith {};" in source


def test_all_honest_menu_callers_use_the_two_phase_request_when_armed():
    for root in MODDED_ROOTS:
        source = read(root, "Client/GUI/GUI_Menu_Command.sqf")

        assert "MenuAction == 303" in source
        assert "WFBE_C_SEC_HARDENING" in source
        assert "getPlayerUID player" in source
        assert "wfbe_team_update_pending" in source
        assert '"RequestTeamUpdate"' in source
        assert "_teamChallenge" in source
        assert "player,\"\",_teamChallenge" in source or "player,\"\", _teamChallenge" in source


def test_private_capability_reply_is_checked_against_pending_menu_request():
    for root in MISSION_ROOTS:
        source = read(root, "Client/PVFunctions/HandleSpecial.sqf")

        for required in (
            'case "team-update-capability"',
            '"team-update"',
            "wfbe_team_update_pending",
            "_teamChallenge != _teamExpectedChallenge",
            '"RequestTeamUpdate"',
            "_teamToken",
            "_teamPending set [6, _teamToken]",
        ):
            assert required in source, f"{root}: missing {required!r}"


def test_capability_helper_is_registered_and_mirrored_for_every_runtime_root():
    mint_bytes = []
    consume_bytes = []
    for root in MISSION_ROOTS:
        mint = ROOT / root / "Server/Functions/Server_MintCapability.sqf"
        consume = ROOT / root / "Server/Functions/Server_ConsumeCapability.sqf"
        init = ROOT / root / "Server/Init/Init_Server.sqf"

        assert mint.exists(), root
        assert consume.exists(), root
        assert 'Server\\Functions\\Server_MintCapability.sqf' in init.read_text(encoding="utf-8-sig")
        assert 'Server\\Functions\\Server_ConsumeCapability.sqf' in init.read_text(encoding="utf-8-sig")

        mint_bytes.append(mint.read_bytes())
        consume_bytes.append(consume.read_bytes())

    assert all(blob == mint_bytes[0] for blob in mint_bytes)
    assert all(blob == consume_bytes[0] for blob in consume_bytes)


def test_hardening_default_remains_zero_in_every_runtime_root():
    for root in MISSION_ROOTS:
        constants = read(root, "Common/Init/Init_CommonConstants.sqf")
        assert "WFBE_C_SEC_HARDENING" in constants
        assert "WFBE_C_SEC_HARDENING               = 0" in constants


if __name__ == "__main__":
    test_server_handler_binds_requester_to_commander_and_consumes_before_effects()
    test_all_honest_menu_callers_use_the_two_phase_request_when_armed()
    test_private_capability_reply_is_checked_against_pending_menu_request()
    test_capability_helper_is_registered_and_mirrored_for_every_runtime_root()
    test_hardening_default_remains_zero_in_every_runtime_root()
    print("RequestTeamUpdate capability-binding contract: PASS")
