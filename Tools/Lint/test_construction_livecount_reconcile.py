"""Regression contract for the non-superseded #1676 construction fixes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = Path("Missions/[55-2hc]warfarev2_073v48co.chernarus")


def read_source(relative: Path) -> str:
    return (ROOT / MISSION / relative).read_text(encoding="utf-8-sig")


def test_request_passes_placer_and_construction_rolls_back_after_accept():
    request = read_source(Path("Server/PVFunctions/RequestStructure.sqf"))
    assert (
        '["StructureBuildFailed", _refundPrice]' not in request
    ), "the post-accept failure belongs to the construction worker, not the accept gate"
    assert (
        '[_structureType,_side,_pos,_dir,_index,"","",_reqPlayer,_capToken] ExecVM '
        '(Format["Server\\Construction\\Construction_%1.sqf",_script])'
    ) in request

    for relative in (
        Path("Server/Construction/Construction_SmallSite.sqf"),
        Path("Server/Construction/Construction_MediumSite.sqf"),
    ):
        source = read_source(relative)
        assert '_reqPlayer = if ((count _this) > 7) then {_this select 7} else {objNull};' in source
        assert "_onConstructionAbort = {" in source
        assert "_onConstructionSuccessLive = {" in source
        assert source.count("Call _onConstructionAbort;") == 4
        assert source.count("Call _onConstructionSuccessLive;") == 1

        abort = source[source.index("_onConstructionAbort = {") : source.index("_onConstructionSuccessLive = {")]
        assert "Call _releasePending;" in abort
        assert "Call _releaseCapPending;" in abort
        assert '"wfbe_structures_live", _live, true' in abort
        assert '"StructureBuildFailed", _refundPrice' in abort

        success = source[source.index("_onConstructionSuccessLive = {") : source.index("_group = createGroup sideLogic;")]
        assert "if (!isNull _reqPlayer && {isPlayer _reqPlayer}) exitWith {};" in success
        assert "if (_side == resistance) exitWith {};" in success
        assert "_slot = _rlIdx - 1;" in success
        assert "_live set [_slot, _cur + 1];" in success


def test_failure_message_and_existing_building_killed_guard_are_present():
    localize = read_source(Path("Client/PVFunctions/LocalizeMessage.sqf"))
    assert (
        'case "StructureBuildFailed": {if (count _this > 1) then {(_this select 1) Call WFBE_STRUCT_REFUND}; '
        '_txt = Localize "StructureBuildFailed"};'
    ) in localize

    stringtable = read_source(Path("stringtable.xml"))
    assert '<Key ID="StructureBuildFailed">' in stringtable
    assert "Your structure cost has been refunded and the build slot freed." in stringtable

    killed = read_source(Path("Server/Functions/Server_BuildingKilled.sqf"))
    assert "r63: bounds-guard live-count slot" in killed
    assert "{(_find - 1) >= 0}" in killed
    assert "((_current select (_find - 1)) - 1) max 0" in killed


if __name__ == "__main__":
    test_request_passes_placer_and_construction_rolls_back_after_accept()
    test_failure_message_and_existing_building_killed_guard_are_present()
    print("Construction live-count reconciliation contract: PASS")
