/*
	KA-01 (camp-repair-readout, build council item, owner-accepted 2026-07-21): ambient progress
	feedback for the Wave0721 dead-camp presence-repair mechanic (server_town_camp.sqf's
	WFBE_C_CAMP_REPAIR_PRESENCE branch). That branch already runs a real elapsed-time clock per
	dead camp (wfbe_camp_repair_since, now broadcast public+JIP for this) but never told anyone -
	a player holding the ground could not tell it was working or how close it was. This script is
	read-only: it never touches the repair timer, the completion path, or who counts as "present" -
	it only displays what the server has already decided, once per second, to whichever player is
	standing in that camp's WFBE_C_CAMPS_RANGE_PLAYERS bubble.
	Gated by the caller (Init_Client.sqf) on the SAME flag as the repair mechanic itself
	(WFBE_C_CAMP_REPAIR_PRESENCE) - no separate dark flag: there is nothing to show once the
	mechanic is off.
*/

Private ["_bar","_bunker","_camp","_camps","_filled","_k","_pct","_rangePlayers","_shownPct","_since","_threshold"];

_rangePlayers = missionNamespace getVariable ["WFBE_C_CAMPS_RANGE_PLAYERS", 8];
_threshold = missionNamespace getVariable ["WFBE_C_CAMP_REPAIR_PRESENCE_TIME", 150];
_shownPct = -1; //--- -1 = "nothing currently shown"; only touch hintSilent on a state change so this loop never fights other client hints for the screen every single second.

while {true} do {
	sleep 1;

	_camp = objNull;
	if (alive player && !(isNil "WFBE_Logic_Camp")) then {
		_camps = (getPosATL player) nearEntities [[WFBE_Logic_Camp, "HeliHEmpty"], _rangePlayers];
		{
			_bunker = _x getVariable ["wfbe_camp_bunker", objNull];
			//--- Ally-only (team-lead ruling, camp-repair-exploit concern from the day council): a
			//--- side-agnostic bar hands an attacker a precise countdown ("42% -> interrupt at 2min"),
			//--- free intel the mechanic shouldn't give away. Gate on the camp's OWN persistent owning-
			//--- side field (sideID - the same field + default the repair-completion logic itself reads,
			//--- server_town_camp.sqf line ~187) against WFBE_Client_SideID, the stable side captured
			//--- once at client init - NOT `side player`, which can transiently resolve wrong during
			//--- respawn/JIP/team-switch (same intel-leak-fix idiom as updateaicommarkers.sqf).
			if (isNull _camp && {!(isNull _bunker)} && {!(alive _bunker)} && {(_x getVariable ["sideID", WFBE_DEFENDER_ID]) == WFBE_Client_SideID}) then {_camp = _x};
		} forEach _camps;
	};

	_pct = -1;
	if !(isNull _camp) then {
		_since = _camp getVariable ["wfbe_camp_repair_since", -1];
		if (_since >= 0) then {
			_pct = floor (((time - _since) / _threshold) * 100);
			if (_pct > 100) then {_pct = 100};
			if (_pct < 0) then {_pct = 0};
		};
	};

	if (_pct != _shownPct) then {
		if (_pct < 0) then {
			hintSilent "";
		} else {
			_filled = floor (_pct / 10);
			_bar = "";
			for "_k" from 1 to 10 do {_bar = _bar + (if (_k <= _filled) then {"#"} else {"-"})};
			hintSilent Format ["Camp repairing...\n[%1] %2%3", _bar, _pct, "%"];
		};
		_shownPct = _pct;
	};
};
