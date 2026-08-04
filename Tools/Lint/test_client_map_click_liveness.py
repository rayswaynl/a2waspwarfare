from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Functions"
    / "Client_HandleMapSingleClick.sqf"
)


def test_map_click_rejects_non_live_or_spectating_players_before_stateful_commands():
    text = SOURCE.read_text(encoding="utf-8")
    guard = (
        'if (isNull player || {!alive player} || {lifeState player == "UNCONSCIOUS"} '
        '|| {missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]}) exitWith {false};'
    )

    assert guard in text
    assert text.index(guard) < text.index("_ctrlPressed =")
