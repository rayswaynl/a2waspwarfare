from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Functions"
    / "Client_HandleMapSingleClick.sqf"
)

SPECIAL_SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "Functions"
    / "Server_HandleSpecial.sqf"
)


def test_map_click_rejects_non_live_or_spectating_players_before_stateful_commands():
    text = SOURCE.read_text(encoding="utf-8")
    guard = (
        'if (isNull player || {!alive player} || {lifeState player == "UNCONSCIOUS"} '
        '|| {missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]}) exitWith {false};'
    )

    assert guard in text
    assert text.index(guard) < text.index("_ctrlPressed =")


def test_guer_heli_bomb_requires_a_live_requester_before_debiting_funds():
    text = SPECIAL_SOURCE.read_text(encoding="utf-8")
    case = text[text.index('case "guer-heli-bomb": {') : text.index('case "guer-heli-bomb": {') + 3500]

    assert "{alive _player}" in case
    assert case.index("{alive _player}") < case.index("Call WFBE_CO_FNC_ChangeTeamFunds")


def test_vbied_detonation_requires_a_live_driver_before_acceptance():
    text = SPECIAL_SOURCE.read_text(encoding="utf-8")
    case = text[text.index('case "guer-vbied-detonate": {') : text.index('case "guer-vbied-detonate": {') + 2400]

    assert "{alive _driver}" in case
    assert case.index("{alive _driver}") < case.index('_vbiedOK = true;')
