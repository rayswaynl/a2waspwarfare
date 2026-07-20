Private["_add","_bunker","_camp","_camps","_count","_friendlyCamps","_lives","_side","_sideID","_town"];

_town = _this Select 0;
_side = _this Select 1;
_lives = if (count _this > 2) then {_this select 2} else {false};

_sideID = _side Call GetSideID;
_friendlyCamps = [];

//--- kimi/bughunt-mission-core (2026-07-20): nil/deleted-camp guards, same loss class as #1164
//--- (GetTotalCamps) and cmdcon44q (server_town_camp). A camp logic DELETED mid-match stays in the
//--- town's "camps" array; getVariable on the null object returns nil and the (nil == _sideID)
//--- comparison errors, killing the whole Call - and with it every caller's camp lookup for that
//--- town (fast-travel gates in GUI_Menu_Tactical, classic camp respawn in Common_GetRespawnCamps).
//--- A mid-init camp can also briefly lack sideID/wfbe_camp_bunker (Init_Town publishes "camps"
//--- up to ~1s before it seeds them), so those reads get 2-arg defaults too.
_camps = _town getVariable "camps";
_camps = if (isNil "_camps") then {[]} else {_camps};

{
	if (!isNull _x) then {
		if ((_x getVariable ["sideID", -1]) == _sideID) then {
			_add = true;
			if (_lives) then {
				_bunker = _x getVariable "wfbe_camp_bunker";
				_bunker = if (isNil "_bunker") then {objNull} else {_bunker};
				if !(alive _bunker) then {_add = false};
			};
			if (_add) then {_friendlyCamps = _friendlyCamps + [_x]};
		};
	};
} forEach _camps;

_friendlyCamps