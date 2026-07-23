from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8-sig")


def test_real_players_near_helper_is_registered_and_filters_hcs():
    helper = read("Common/Functions/Common_RealPlayersNear.sqf")
    common_init = read("Common/Init/Init_Common.sqf")

    assert 'WFBE_CO_FNC_RealPlayersNear = Compile preprocessFileLineNumbers "Common/Functions/Common_RealPlayersNear.sqf";' in common_init
    assert "alive _x" in helper
    assert "isPlayer _x" in helper
    assert '"WFBE_HEADLESSCLIENTS_ID"' in helper
    assert '"HC-AI-Control-1"' in helper
    assert "_excludeCivilian" in helper
    assert "!_excludeCivilian || {(side _x) != civilian}" in helper


def test_recovery_and_cleanup_vetoes_use_real_players_near():
    locations = {
        "Common/Functions/Common_RunCommanderTeam.sqf": [1168, 1223, 1237, 2818],
        "Common/Functions/Common_RunSidePatrol.sqf": [364],
        "Common/Functions/Common_TrashObject.sqf": [31],
        "Server/Server_USVFlotilla.sqf": [239],
        "Server/AI/Commander/AI_Commander_MHQReloc.sqf": [408, 409, 427, 428],
        "Server/AI/Commander/AI_Commander_Produce.sqf": [132],
        "Server/AI/Commander/AI_Commander_Teams.sqf": [337],
        "Server/AI/Commander/AI_Commander_DisbandLowTier.sqf": [70],
    }

    for relative, old_lines in locations.items():
        source = read(relative)
        assert "Call WFBE_CO_FNC_RealPlayersNear" in source, f"{relative}:{old_lines}"

    usv = read("Server/Server_USVFlotilla.sqf")
    assert "[_cPos, _approachRadius, true] Call WFBE_CO_FNC_RealPlayersNear" in usv
    assert "[getPos _eBoat, 100, true] Call WFBE_CO_FNC_RealPlayersNear" in usv


if __name__ == "__main__":
    test_real_players_near_helper_is_registered_and_filters_hcs()
    test_recovery_and_cleanup_vetoes_use_real_players_near()
    print("PASS: RealPlayersNear veto regression checks")
