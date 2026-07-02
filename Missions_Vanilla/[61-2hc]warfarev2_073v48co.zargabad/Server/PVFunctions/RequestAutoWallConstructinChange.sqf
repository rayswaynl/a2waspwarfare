Private ['_isAutoWallConstructingEnabled','_player','_side'];

_isAutoWallConstructingEnabled = _this select 0;
_player = _this select 1;

//--- wiki-wins: scope the toggle to the requester's side (was a single global affecting every side + the AI),
//--- and notify the whole side so all that side's commanders' HUDs stay in sync (was sent only to the toggler).
_side = side _player;
missionNamespace setVariable [Format["WFBE_AUTOWALL_%1", _side], _isAutoWallConstructingEnabled];
isAutoWallConstructingEnabled = _isAutoWallConstructingEnabled; //--- keep the legacy global in step for any stray reader
[_side, "HandleSpecial", ["auto-wall-constructing-changed", _isAutoWallConstructingEnabled]] Call WFBE_CO_FNC_SendToClients;