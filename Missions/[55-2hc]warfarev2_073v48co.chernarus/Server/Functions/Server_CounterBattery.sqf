/* Server_CounterBattery.sqf — WFBE_SE_FNC_CounterBatteryCheck
   Checks whether any CBR on the opposing side detects a given artillery firing.

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

Private ["_unit","_fpos","_firingSide","_opposingSideKey","_cbrs","_i","_cbr","_r","_upgs","_lvl","_lastPing","_d","_t","_h","_tStr","_markerPos","_pkt"];

_unit  = _this select 0;
_fpos  = _this select 1;
_firingSide = side _unit;

//--- Rate-limit: skip if this unit fired a CBR ping within the last 10 s (server-side variable).
_lastPing = _unit getVariable ["wfbe_cbr_lastping", -99];
if ((time - _lastPing) < 10) exitWith {};

//--- Determine the detecting side's CBR registry.
_opposingSideKey = if (_firingSide == west) then {"WFBE_CBR_EAST"} else {"WFBE_CBR_WEST"};
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
            _upgs = ((side _cbr) Call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_upgrades", []];
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
            _pkt = [side _cbr, "CounterBatteryContact", [_markerPos, _tStr]];
            _pkt Call WFBE_CO_FNC_SendToClients;

            ["INFORMATION", Format ["Server_CounterBattery.sqf: [%1] CBR detected [%2] at dist %3 m (radius %4 m). Time %5.", str (side _cbr), _unit, round _d, _r, _tStr]] Call WFBE_CO_FNC_LogContent;
        };
    };
} forEach _cbrs;

//--- Prune dead entries from registry (done outside the forEach loop).
missionNamespace setVariable [_opposingSideKey, _cbrs select {alive _x}];
