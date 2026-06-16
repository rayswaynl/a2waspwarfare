/* Server_CounterBattery.sqf — WFBE_SE_FNC_CounterBatteryCheck
   Checks whether any CBR on the opposing side detects a given artillery firing.
   Also increments the enemy-fire-mission counter on the FIRING side's opposing logic
   (wfbe_aicom_enemy_arty_fire_count) so the AI commander's threat gate can arm itself
   when >= 3 enemy fire missions are observed (condition b of the CBR reactive spec).

   Locality note (documented from code-reading):
     Common_FireArtillery.sqf is called via Spawn, and the Fired EH it installs fires
     in the locality of the vehicle object. AI arty is local to the server, so the
     server handles it directly. Player-crewed arty is local to the player's client;
     the Fired EH fires on that client. That client routes the event to the server via
     WFBE_CO_FNC_SendToServer → WFBE_PVF_CounterBatteryFired PV → this function runs
     server-side in all paths.

   Parameters (array):
     0 - firing unit (object)
     1 - firing position (array [x,y,z])

   Called as: [_unit, getPos _unit] Call WFBE_SE_FNC_CounterBatteryCheck
     or via PVF dispatch when routed from a client.
*/
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) == 0) exitWith {};

Private ["_unit","_fpos","_firingSide","_opposingSideKey","_cbrs","_i","_cbr","_r","_upgs","_lvl","_lastPing","_d","_t","_h","_tStr","_markerPos","_pkt","_aliveCbrs","_opposingLogik","_fireMissCount","_missWindow","_lastMiss","_detectingSide"];

_unit  = _this select 0;
_fpos  = _this select 1;
_firingSide = side _unit;

//--- Rate-limit: skip if this unit fired a CBR ping within the last 10 s (server-side variable).
_lastPing = _unit getVariable ["wfbe_cbr_lastping", -99];
if ((time - _lastPing) < 10) exitWith {};

//--- Condition (b): count enemy fire missions observed by the opposing side's AI logic.
//--- The OPPOSING side is the one whose AI threat flag we want to arm (they are under fire).
_opposingLogik = (if (_firingSide == west) then {east} else {west}) Call WFBE_CO_FNC_GetSideLogic;
if (!isNil "_opposingLogik") then {
	//--- E6: count distinct fire MISSIONS, not shells/guns. The per-unit wfbe_cbr_lastping limit above only
	//--- triggers when an enemy CBR actually detected (line ~73) and is per-gun, so a multi-gun salvo / any
	//--- fire with no CBR in range bumped this once per shell and armed after ONE mission. Gate to once/side/window.
	_missWindow    = missionNamespace getVariable ["WFBE_C_CBR_FIRE_MISSION_WINDOW", 30];
	_lastMiss      = _opposingLogik getVariable ["wfbe_aicom_enemy_arty_lastmiss", -99];
	_fireMissCount = _opposingLogik getVariable ["wfbe_aicom_enemy_arty_fire_count", 0];
	if ((time - _lastMiss) >= _missWindow) then {
		_opposingLogik setVariable ["wfbe_aicom_enemy_arty_lastmiss", time];
		_fireMissCount = _fireMissCount + 1;
		_opposingLogik setVariable ["wfbe_aicom_enemy_arty_fire_count", _fireMissCount];
	};
	//--- Arm threat flag when >= 3 fire missions observed (condition b).
	if (_fireMissCount >= 3 && {!(_opposingLogik getVariable ["wfbe_aicom_arty_threat", false])}) then {
		_opposingLogik setVariable ["wfbe_aicom_arty_threat", true];
		["INFORMATION", Format ["Server_CounterBattery.sqf: [%1] wfbe_aicom_arty_threat ARMED (cond-b: %2 enemy fire missions observed).", str (if (_firingSide == west) then {east} else {west}), _fireMissCount]] Call WFBE_CO_FNC_LogContent;
		diag_log ("AICOMSTAT|v1|EVENT|" + (str (if (_firingSide == west) then {east} else {west})) + "|" + str (round (time / 60)) + "|ARTY_THREAT_ARMED|cond-b|count=" + str _fireMissCount);
	};
};

//--- Determine the detecting side's CBR registry.
_opposingSideKey = if (_firingSide == west) then {"WFBE_CBR_EAST"} else {"WFBE_CBR_WEST"};
_detectingSide   = if (_firingSide == west) then {east} else {west}; //--- AF3 fix: CBR owner side = the side whose registry we scan; a Land_Antenna static is engine-side CIVILIAN, so side _cbr mis-addressed the contact marker (clients dropped it) and looked up the wrong side upgrade radius.
_cbrs = missionNamespace getVariable [_opposingSideKey, []];
if (count _cbrs == 0) exitWith {};

//--- Scan each registered CBR for range match.
{
    _cbr = _x;
    if !(alive _cbr) then {
        //--- Prune dead CBRs lazily (can't modify array in forEach; mark for removal).
    } else {
        //--- Per-object radius override (for future airfield static CBRs).
        _r = _cbr getVariable ["wfbe_cbr_radius", -1];
        if (_r < 0) then {
            //--- Use upgrade level to pick radius.
            _upgs = (_detectingSide Call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_upgrades", []];
            _lvl = 0;
            if (count _upgs > WFBE_UP_CBRADAR) then {_lvl = _upgs select WFBE_UP_CBRADAR};
            _lvl = _lvl min 2;
            _r = [750, 1500, 2000] select _lvl;
        };

        _d = _fpos distance (getPos _cbr);
        if (_d <= _r) then {
            //--- Mark rate-limit on the firing unit.
            _unit setVariable ["wfbe_cbr_lastping", time];

            //--- Build time string HH:MM from current date.
            _t = date;
            _h   = Format ["%1", _t select 3];
            _tStr = Format ["%1:%2", if ((_t select 3) < 10) then {Format["0%1",_t select 3]} else {Format["%1",_t select 3]},
                                     if ((_t select 4) < 10) then {Format["0%1",_t select 4]} else {Format["%1",_t select 4]}];

            //--- Notify the detecting side via client PVF (side-targeted).
            _markerPos = [_fpos select 0, _fpos select 1, 0];
            _pkt = [_detectingSide, "CounterBatteryContact", [_markerPos, _tStr]];
            _pkt Call WFBE_CO_FNC_SendToClients;

            ["INFORMATION", Format ["Server_CounterBattery.sqf: [%1] CBR detected [%2] at dist %3 m (radius %4 m). Time %5.", str _detectingSide, _unit, round _d, _r, _tStr]] Call WFBE_CO_FNC_LogContent;
        };
    };
} forEach _cbrs;

//--- Prune dead entries from registry (done outside the forEach loop).
//--- A2: select {code} is A3-only; use an explicit filter loop.
_aliveCbrs = [];
{if (!isNull _x && {alive _x}) then {_aliveCbrs set [count _aliveCbrs, _x]}} forEach _cbrs;
missionNamespace setVariable [_opposingSideKey, _aliveCbrs];
