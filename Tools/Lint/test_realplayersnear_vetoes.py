from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8-sig")


def test_real_players_near_helper_is_registered_and_filters_hcs():
    helper = read("Common/Functions/Common_RealPlayersNear.sqf")
    common_init = read("Common/Init/Init_Common.sqf")

    #--- #1493: forward slashes break preprocessFileLineNumbers inside a PBO; the backslash path IS the fix.
    assert 'WFBE_CO_FNC_RealPlayersNear = Compile preprocessFileLineNumbers "Common\\Functions\\Common_RealPlayersNear.sqf";' in common_init
    assert "alive _x" in helper
    assert "isPlayer _x" in helper
    assert 'if ((typeName _this) != "ARRAY") exitWith {0};' in helper
    assert '(count _position) < 2' in helper
    assert '(count _position) > 3' in helper
    assert '(typeName (_position select 0)) != "SCALAR"' in helper
    assert '(typeName (_position select 1)) != "SCALAR"' in helper
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


def test_real_players_near_call_result_is_never_assigned_directly_to_a_boolean():
    # A Call can abort before completing its assignment. The destination boolean must
    # therefore be seeded first, with the scalar result captured and type-checked
    # separately. This rejects the cascade pattern seen in the HC RPT.
    direct_boolean_assignments = []
    pattern = re.compile(
        r"(_[A-Za-z0-9_]+)\s*=\s*\([^\n]+\]\s+Call\s+"
        r"WFBE_CO_FNC_RealPlayersNear\)\s*>\s*0;",
        re.IGNORECASE,
    )

    for source_path in MISSION.rglob("*.sqf"):
        source = source_path.read_text(encoding="utf-8-sig")
        for match in pattern.finditer(source):
            direct_boolean_assignments.append(
                f"{source_path.relative_to(MISSION)}:{match.group(1)}"
            )

    assert not direct_boolean_assignments, (
        "RealPlayersNear results must be seeded and type-checked before deriving "
        f"a boolean: {direct_boolean_assignments}"
    )


if __name__ == "__main__":
    test_real_players_near_helper_is_registered_and_filters_hcs()
    test_recovery_and_cleanup_vetoes_use_real_players_near()
    test_real_players_near_call_result_is_never_assigned_directly_to_a_boolean()
    print("PASS: RealPlayersNear veto regression checks")
