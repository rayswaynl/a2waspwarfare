/*
	fable/awacs-radar: AWACS GROUND PICTURE (moving-target-indicator sweep).
	Parameter 0: the AWACS platform vehicle. Runs on the PILOT's client only
	(launched by awacs_pilot_watch.sqf when the local player takes the driver seat
	of a WFBE_C_AWACS_TYPES airframe; flag WFBE_C_AWACS > 0 checked by the watcher).
	Modeled on Client\Module\UAV\uav_spotter.sqf and reuses its 'uav-reveal' client
	path (HandleSpecial -> WFBE_CL_FNC_Reveal_UAV): fuzzed orange ellipse on the map
	of every client of the pilot's side, sized by AWACS-to-target distance, self-
	deleting. No knowsAbout gate (radar, not optics); instead an MTI speed floor -
	parked hulls stay dark. Crewless hulls resolve side CIVILIAN and are filtered.
	Air contacts are NOT swept here - the air picture rides the AAR marker path
	(see Common_MarkerLoop.sqf), so low flying stays a valid counter to ground MTI.
	Exits when the platform dies or the player leaves the driver seat.
*/
Private ['_awacs','_delay','_minAlt','_minSpeed','_range','_target'];

_awacs = _this select 0;
_delay = missionNamespace getVariable ["WFBE_C_AWACS_GROUND_DELAY", 30];
_range = missionNamespace getVariable ["WFBE_C_AWACS_GROUND_RANGE", 6000];
_minAlt = missionNamespace getVariable ["WFBE_C_AWACS_MINALT", 150];
_minSpeed = missionNamespace getVariable ["WFBE_C_AWACS_GROUND_MINSPEED", 5];

diag_log Format ["AWACS: ground sweep ENGAGED on %1 (range %2m, every %3s, MTI >%4km/h)", typeOf _awacs, _range, _delay, _minSpeed];

while {alive _awacs && {vehicle player == _awacs} && {driver _awacs == player}} do {
	if (((getPosATL _awacs) select 2) > _minAlt) then {
		{
			_target = _x;
			if (!(side _target in [sideJoined, civilian]) && {abs (speed _target) > _minSpeed}) then {
				sleep (0.05 + random 0.05);
				[sideJoined, "HandleSpecial", ["uav-reveal", _awacs, _target]] Call WFBE_CO_FNC_SendToClients;
			};
		} forEach (_awacs nearEntities [["Car","Motorcycle","Tank","Ship"], _range]);
	};
	sleep _delay;
};

diag_log Format ["AWACS: ground sweep ENDED on %1", typeOf _awacs];
