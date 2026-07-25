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
    #--- rebase-1293 note: AI_Commander_DisbandLowTier.sqf, AI_Commander_Teams.sqf, and
    #--- AI_Commander_Produce.sqf are DELIBERATELY excluded here - owner ruling 2026-07-22 20:06
    #--- removed their proximity/combat vetoes entirely (disband/recycle/retire are now always
    #--- destructive and unconditional), so there is no player-proximity check left to harden in
    #--- those three files. Server_USVFlotilla.sqf and Server/Init/Init_NavalHVT.sqf are also
    #--- excluded - master already carries an equivalent inline HC/CIV/name filter there
    #--- (wasp-navalcap-playableunits), so no helper-call hunk applies.
    locations = {
        "Common/Functions/Common_RunCommanderTeam.sqf": ["_uPlayerNear", "_bNear", "_uFootPlayerNear", "_topDefer"],
        "Common/Functions/Common_RunSidePatrol.sqf": ["_pNear"],
        "Common/Functions/Common_TrashObject.sqf": ["_held"],
        "Server/AI/Commander/AI_Commander_MHQReloc.sqf": ["_pNear"],
    }

    for relative, markers in locations.items():
        source = read(relative)
        assert "Call WFBE_CO_FNC_RealPlayersNear" in source, relative
        for marker in markers:
            assert marker in source, f"{relative}:{marker}"


if __name__ == "__main__":
    test_real_players_near_helper_is_registered_and_filters_hcs()
    test_recovery_and_cleanup_vetoes_use_real_players_near()
    print("PASS: RealPlayersNear veto regression checks")
