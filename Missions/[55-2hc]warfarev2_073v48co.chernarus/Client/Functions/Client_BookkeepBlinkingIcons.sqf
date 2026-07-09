
// Marty: Performance Audit locals.
private ["_blinkRed", "_timeBefore", "_timeAfter", "_dt", "_perfStart", "_perfGroups", "_perfUnits"];

// Marty: The global mission parameter owns this feature; when disabled there is no scan loop.
if ((missionNamespace getVariable ["WFBE_C_MAP_ICON_BLINKING_ENABLED", 0]) != 1) exitWith {};

_blinkRed = true;

while { !WFBE_GameOver } do {

    // Marty: Performance Audit timing for the blinking icon bookkeeping loop.
    _perfStart = diag_tickTime;
    _perfGroups = 0;
    _perfUnits = 0;

    _timeBefore = time;
    {
        // Optimize by skipping crunching the data of enemy groups
        if (side _x != side player) exitWith {};

        // Marty: Performance Audit counters for scanned groups and units.
        _perfGroups = _perfGroups + 1;

        private ["_groupArray"];
        _groupArray = [];

        _groupArray = units _x;
        _perfUnits = _perfUnits + count _groupArray;

        {
            if (side _x == side player) then {
                private ["_isActiveVehicle", "_isActive", "_vehicleUnit"];
                _isActive = _x getVariable "LFTB";
                _vehicleUnit = vehicle _x;
                _isActiveVehicle = _vehicleUnit getVariable "LFTB";
                
                if (!isNil { _isActive }) then {
                    if (_isActive) then {
                        if (side player == west) then {
                            if (BLINKING_UNITS_WEST find _x == -1) then {
                                [BLINKING_UNITS_WEST, _x] call BIS_fnc_arrayPush;
                            };
                        } else {
                            if (side player == east) then {
                                if (BLINKING_UNITS_EAST find _x == -1) then {
                                    [BLINKING_UNITS_EAST, _x] call BIS_fnc_arrayPush;
                                };
                            } else {
                                //--- fable/marker-combat-flash (owner 2026-07-09) GUER-COVERAGE FIX: this
                                //--- branch was WEST/EAST only - a GUER player's LFTB flip queued nowhere,
                                //--- so combat-icon-blink never fired for resistance. Mirrors WEST/EAST.
                                if (side player == resistance) then {
                                    if (BLINKING_UNITS_GUER find _x == -1) then {
                                        [BLINKING_UNITS_GUER, _x] call BIS_fnc_arrayPush;
                                    };
                                };
                            };
                        };
                    } else {
                        if (side player == west) then {
                            {
                                _unitLFTB = _x getVariable "LFTB";
                                if (!(isNil { _unitLFTB })) then {
                                    if(!_unitLFTB) then {
                                        BLINKING_UNITS_WEST = BLINKING_UNITS_WEST - [_x];
                                    };
                                };
                                if (isNull _x) then {
                                    BLINKING_UNITS_WEST = BLINKING_UNITS_WEST - [_x];
                                };
                            } forEach BLINKING_UNITS_WEST;
                        } else {
                            if (side player == east) then {
                                {
                                    _unitLFTB = _x getVariable "LFTB";
                                    if (!(isNil { _unitLFTB })) then {
                                        if(!_unitLFTB) then {
                                            BLINKING_UNITS_EAST = BLINKING_UNITS_EAST - [_x];
                                        };
                                    };
                                    if (isNull _x) then {
                                        BLINKING_UNITS_EAST = BLINKING_UNITS_EAST - [_x];
                                    };
                                } forEach BLINKING_UNITS_EAST;
                            } else {
                                //--- fable/marker-combat-flash GUER-COVERAGE FIX: mirrors WEST/EAST cleanup.
                                if (side player == resistance) then {
                                    {
                                        _unitLFTB = _x getVariable "LFTB";
                                        if (!(isNil { _unitLFTB })) then {
                                            if(!_unitLFTB) then {
                                                BLINKING_UNITS_GUER = BLINKING_UNITS_GUER - [_x];
                                            };
                                        };
                                        if (isNull _x) then {
                                            BLINKING_UNITS_GUER = BLINKING_UNITS_GUER - [_x];
                                        };
                                    } forEach BLINKING_UNITS_GUER;
                                };
                            };
                        };
                    };
                };

                if (!isNil { _isActiveVehicle }) then {
                    if (_isActiveVehicle && _vehicleUnit != _x) then {
                        if (side player == west) then {
                            if (BLINKING_VEHICLES_WEST find _vehicleUnit == -1) then {
                                [BLINKING_VEHICLES_WEST, _vehicleUnit] call BIS_fnc_arrayPush;
                            };
                        };

                        if (side player == east) then {
                            if (BLINKING_VEHICLES_EAST find _vehicleUnit == -1) then {
                                [BLINKING_VEHICLES_EAST, _vehicleUnit] call BIS_fnc_arrayPush;
                            };
                        };

                        //--- fable/marker-combat-flash GUER-COVERAGE FIX: mirrors WEST/EAST above.
                        if (side player == resistance) then {
                            if (BLINKING_VEHICLES_GUER find _vehicleUnit == -1) then {
                                [BLINKING_VEHICLES_GUER, _vehicleUnit] call BIS_fnc_arrayPush;
                            };
                        };

                        // Upstream miksuu/BlinkingMapIconsV2: also blink the mounted player's own
                        // soldier marker, so their map icon blinks alongside the active vehicle's.
                        if (isPlayer _x && (_x == gunner _vehicleUnit || _x == commander _vehicleUnit)) then {
                            if (side player == west) then {
                                if (BLINKING_UNITS_WEST find _x == -1) then {
                                    [BLINKING_UNITS_WEST, _x] call BIS_fnc_arrayPush;
                                };
                            };

                            if (side player == east) then {
                                if (BLINKING_UNITS_EAST find _x == -1) then {
                                    [BLINKING_UNITS_EAST, _x] call BIS_fnc_arrayPush;
                                };
                            };

                            //--- fable/marker-combat-flash GUER-COVERAGE FIX: mirrors WEST/EAST above
                            //--- (crew-member self-marker also blinks alongside its blinking vehicle).
                            if (side player == resistance) then {
                                if (BLINKING_UNITS_GUER find _x == -1) then {
                                    [BLINKING_UNITS_GUER, _x] call BIS_fnc_arrayPush;
                                };
                            };
                        };
                    } else {
                        if (side player == west) then {
                            {
                                _vehicleLFTB = _vehicleUnit getVariable "LFTB";
                                if (!(isNil { _vehicleLFTB }) && !_vehicleLFTB) then {                       
                                    BLINKING_VEHICLES_WEST = BLINKING_VEHICLES_WEST - [_vehicleUnit];
                                };
                                if (isNull _x) then {
                                    BLINKING_VEHICLES_WEST = BLINKING_VEHICLES_WEST - [_x];
                                };
                            } forEach BLINKING_VEHICLES_WEST;
                        } else {
                            if (side player == east) then {
                                {
                                    _vehicleLFTB = _vehicleUnit getVariable "LFTB";
                                    if (!(isNil { _vehicleLFTB }) && !_vehicleLFTB) then {  
                                        BLINKING_VEHICLES_EAST = BLINKING_VEHICLES_EAST - [_vehicleUnit];
                                    };
                                    if (isNull _x) then {
                                        BLINKING_VEHICLES_EAST = BLINKING_VEHICLES_EAST - [_x];
                                    };
                                } forEach BLINKING_VEHICLES_EAST;
                            } else {
                                //--- fable/marker-combat-flash GUER-COVERAGE FIX: mirrors WEST/EAST cleanup.
                                if (side player == resistance) then {
                                    {
                                        _vehicleLFTB = _vehicleUnit getVariable "LFTB";
                                        if (!(isNil { _vehicleLFTB }) && !_vehicleLFTB) then {
                                            BLINKING_VEHICLES_GUER = BLINKING_VEHICLES_GUER - [_vehicleUnit];
                                        };
                                        if (isNull _x) then {
                                            BLINKING_VEHICLES_GUER = BLINKING_VEHICLES_GUER - [_x];
                                        };
                                    } forEach BLINKING_VEHICLES_GUER;
                                };
                            };
                        };
                    };
                }; 
            };
        } forEach _groupArray;

    } forEach clientTeams;

    if (side player == west) then {
        {
            [_x, _blinkRed] call WFBE_CL_FNC_BlinkMapIcon;
        } forEach BLINKING_UNITS_WEST;

        {
            [_x, _blinkRed] call WFBE_CL_FNC_BlinkMapIcon;
        } forEach BLINKING_VEHICLES_WEST;
    };

    if (side player == east) then {
        {
            [_x, _blinkRed] call WFBE_CL_FNC_BlinkMapIcon;
        } forEach BLINKING_UNITS_EAST;

        {
            [_x, _blinkRed] call WFBE_CL_FNC_BlinkMapIcon;
        } forEach BLINKING_VEHICLES_EAST;
    };

    //--- fable/marker-combat-flash (owner 2026-07-09) GUER-COVERAGE FIX: dispatch the GUER-side
    //--- arrays too - this is the tail no side ever reached (dead LFTB writes for resistance).
    if (side player == resistance) then {
        {
            [_x, _blinkRed] call WFBE_CL_FNC_BlinkMapIcon;
        } forEach BLINKING_UNITS_GUER;

        {
            [_x, _blinkRed] call WFBE_CL_FNC_BlinkMapIcon;
        } forEach BLINKING_VEHICLES_GUER;
    };

    _blinkRed = !_blinkRed;

    _timeAfter = time;
    _dt = _timeAfter - _timeBefore;

    if (_dt >= 1) then {
        _dt = 0;
    };

    // Marty: Performance Audit record for the blinking icon bookkeeping loop.
    if !(isNil "PerformanceAudit_Record") then {
        if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
        	["bookkeep_blinking_icons", diag_tickTime - _perfStart, Format["groups:%1;units:%2;westUnits:%3;eastUnits:%4;westVehicles:%5;eastVehicles:%6", _perfGroups, _perfUnits, count BLINKING_UNITS_WEST, count BLINKING_UNITS_EAST, count BLINKING_VEHICLES_WEST, count BLINKING_VEHICLES_EAST], "CLIENT"] Call PerformanceAudit_Record;
        };
    };

    sleep (1 - _dt);
};
