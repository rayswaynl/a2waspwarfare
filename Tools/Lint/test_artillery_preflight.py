from pathlib import Path


SOURCE = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_FireArtillery.sqf"
)


def test_artillery_reservation_follows_preflight_validation():
    text = SOURCE.read_text(encoding="utf-8-sig")
    reservation = text.index('_artillery setVariable ["restricted",true];')
    validations = [
        'if (_index == -1) exitWith',
        'if (isNull _gunner) exitWith',
        'if (isPlayer _gunner) exitWith',
    ]

    for validation in validations:
        assert text.index(validation) < reservation, validation


def test_player_artillery_discards_stale_or_malformed_request():
    source = Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_PlayerArty.sqf"
    ).read_text(encoding="utf-8-sig")
    stale_branch = 'if (!_riArtyFresh) exitWith {'
    assert stale_branch in source
    branch_start = source.index(stale_branch)
    branch_end = source.index('};', branch_start)
    assert 'setVariable ["wfbe_aicom_arty_request", []]' in source[branch_start:branch_end]


def test_player_crew_eject_routes_to_the_unit_owner():
    text = SOURCE.read_text(encoding="utf-8-sig")
    assert '[_x, "HandleSpecial", ["action-perform", _x, "getOut", _artillery]] Call WFBE_CO_FNC_SendToClient;' in text


def test_player_artillery_consumption_stamps_the_side_fire_cadence():
    source = Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_PlayerArty.sqf"
    ).read_text(encoding="utf-8-sig")
    cadence = 'setVariable ["wfbe_aicom_arty_last", time];'
    launch = 'Spawn WFBE_CO_FNC_FireArtillery;'
    gate = 'if ((time - _artyLast) > _artyCooldown && {!_fired}'

    assert cadence in source
    assert gate in source
    assert source.index(cadence) > source.index(launch)


if __name__ == "__main__":
    test_artillery_reservation_follows_preflight_validation()
    test_player_artillery_discards_stale_or_malformed_request()
    test_player_crew_eject_routes_to_the_unit_owner()
    test_player_artillery_consumption_stamps_the_side_fire_cadence()
