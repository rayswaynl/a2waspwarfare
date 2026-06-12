// Server-side empty-group garbage collector. A2 has a hard ~144 groups/side cap;
// empty groups are not auto-reclaimed, so leaks accumulate until createGroup returns
// grpNull and AI silently stops spawning. This sweeps zero-living-unit, non-persistent
// groups every 60s, making the cap unreachable in normal play.
if (!isServer) exitWith {};

while {!WFBE_GameOver} do {
	sleep 60;
	{
		private "_grp";
		_grp = _x;
		if (!isNull _grp && {!(_grp getVariable ["wfbe_persistent", false])} && {(count (units _grp)) == 0}) then {
			deleteGroup _grp;
		};
	} forEach allGroups;
};
