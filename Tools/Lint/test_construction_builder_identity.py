"""Regression contract for structure-builder leaderboard attribution.

Player construction requests already thread the verified requester object into
the SmallSite/MediumSite workers, while AICOM invokes the same workers with the
legacy five-argument form and therefore receives the workers' objNull default.
Completion credit must follow that explicit identity instead of whichever
same-side human happens to be nearest an AI-built structure.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
WORKERS = ("Construction_SmallSite.sqf", "Construction_MediumSite.sqf")

REQUESTER_GUARD = "if (!isNull _reqPlayer && {isPlayer _reqPlayer}) then {"
REQUESTER_UID = "_bUid = getPlayerUID _reqPlayer;"
RECORD_BUILD = (
    "[_bUid, WFBE_STAT_STRUCTURES_BUILT, 1] call WFBE_SE_FNC_RecordStat"
)


def test_completed_structure_credit_uses_only_the_verified_requester():
    by_worker = {worker: [] for worker in WORKERS}

    for terrain in TERRAINS:
        for worker in WORKERS:
            path = ROOT / terrain / "Server" / "Construction" / worker
            source = path.read_text(encoding="utf-8-sig")
            by_worker[worker].append(path.read_bytes())

            completion = source.index("has been constructed.")
            tail = source[completion:]
            guard = tail.index(REQUESTER_GUARD)
            uid = tail.index(REQUESTER_UID, guard)
            record = tail.index(RECORD_BUILD, uid)

            assert guard < uid < record
            assert "forEach playableUnits" not in tail
            assert "WFBE_C_STATS_BUILD_ATTR_RANGE" not in source

    for copies in by_worker.values():
        assert copies[0] == copies[1] == copies[2]


def test_aicom_and_player_callers_preserve_distinct_identity_contracts():
    chernarus = TERRAINS[0]
    aicom = (
        ROOT
        / chernarus
        / "Server"
        / "AI"
        / "Commander"
        / "AI_Commander_Base.sqf"
    ).read_text(encoding="utf-8-sig")
    request = (
        ROOT / chernarus / "Server" / "PVFunctions" / "RequestStructure.sqf"
    ).read_text(encoding="utf-8-sig")

    assert (
        '[_class, _side, _pos, _facDir, _idx] ExecVM (Format '
        '["Server\\Construction\\Construction_%1.sqf", _script]);'
    ) in aicom
    assert (
        '[_fwdClass, _side, _fwdFacP, _fwdDir, _fwdIdx] ExecVM (Format '
        '["Server\\Construction\\Construction_%1.sqf", _fwdScript]);'
    ) in aicom
    assert (
        '[_structureType,_side,_pos,_dir,_index,"","",_reqPlayer] ExecVM '
        '(Format["Server\\Construction\\Construction_%1.sqf",_script]);'
    ) in request


if __name__ == "__main__":
    test_completed_structure_credit_uses_only_the_verified_requester()
    test_aicom_and_player_callers_preserve_distinct_identity_contracts()
    print("Construction builder identity attribution contract: PASS")
