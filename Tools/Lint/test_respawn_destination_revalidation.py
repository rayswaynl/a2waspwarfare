from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MENU = MISSION / "Client" / "GUI" / "GUI_RespawnMenu.sqf"
HANDLER = MISSION / "Client" / "Functions" / "Client_OnRespawnHandler.sqf"


def test_respawn_destination_is_revalidated_at_execution_time():
    """A selected spawn must still be in the fresh eligibility list when it executes."""
    menu = MENU.read_text(encoding="utf-8-sig")
    handler = HANDLER.read_text(encoding="utf-8-sig")

    assert menu.count("[player,_this,_deathLoc] Call OnRespawnHandler;") == 1
    assert menu.count("[player,_spawn_at_current,_deathLoc] Call OnRespawnHandler;") == 1
    assert (
        '_deathLoc = if (count _this > 2 && {typeName (_this select 2) == "ARRAY"}) '
        'then {_this select 2} else {getPos _unit};'
    ) in handler
    assert "_respawnAvailable = [sideJoined, _deathLoc] Call GetRespawnAvailable;" in handler
    assert "if !(_spawn in _respawnAvailable) then {_spawn = objNull};" in handler
