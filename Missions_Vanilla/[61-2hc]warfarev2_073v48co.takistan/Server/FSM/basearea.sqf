private["_brr","_mbr","_onAreaRemoved","_side","_logik","_buildings","_command","_service","_aar","_areas","_grp","_areas_old","_structure"];

//--- r53: defaulted ranges so nil missionNamespace keys never make distance arithmetic throw.
_brr = missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 0];
_mbr = missionNamespace getVariable ["WFBE_C_BASE_HQ_BUILD_RANGE", 0];

_onAreaRemoved = {
    Private ["_areas", "_center", "_delete", "_objects", "_side", "_unit", "_range"];
    _center = _this select 0;
    _side = _this select 1;
    _areas = _this select 2;
    if (isNil "_areas" || {typeName _areas != "ARRAY"}) then {_areas = []};

    //--- r53: defaulted defense scan range (same keys as outer loop).
    _range = (missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 0]) + (missionNamespace getVariable ["WFBE_C_BASE_HQ_BUILD_RANGE", 0]);
    _objects = nearestObjects [_center, missionNamespace getVariable Format["WFBE_%1DEFENSENAMES", _side], _range];
    {_objects = _objects - (nearestObjects [getPos _x, missionNamespace getVariable Format["WFBE_%1DEFENSENAMES", _side], _range])} forEach _areas;

    sleep 60;

    {
        //--- r53: concurrent cleanup / area churn can null objects during the 60s sleep.
        if (!isNull _x) then {
        if !(isNil {_x getVariable "wfbe_defense"}) then {
            _delete = true;
            if (_x isKindOf "StaticWeapon") then {
                _unit = gunner _x;
                if (!isNull _unit && {alive _unit}) then {
                    if (isNil {(group _unit) getVariable "wfbe_funds"}) then {
                        _unit setPos (getPos _x);
                        if (!isNull _unit) then {deleteVehicle _unit};
                    } else {
                        _delete = false;
                    };
                };
            };
            if (_x isKindOf "CDF_WarfareBVehicleServicePoint" || // Cherno BLU
                _x isKindOf "INS_WarfareBVehicleServicePoint" || // Cherno OPFOR
                _x isKindOf "US_WarfareBVehicleServicePoint_Base_EP1" || // Taki BLU
                _x isKindOf "TK_WarfareBVehicleServicePoint_Base_EP1") // Taki OPFOR
                 then {
                if (!isNull _x) then {deleteVehicle _x};
            } else {
                if (_delete) then {
                    if (!isNull _x) then {deleteVehicle _x};
                };
            };
        };
        };
    } forEach _objects;
};

while {!gameOver} do {
{
_side = _x;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
_buildings = (_side Call WFBE_CO_FNC_GetSideStructures) + [_side Call WFBE_CO_FNC_GetSideHQ];
_command=[_side,missionNamespace getVariable Format["WFBE_%1COMMANDCENTERTYPE",str _side],_buildings] Call GetFactories;
_service=[_side,missionNamespace getVariable Format["WFBE_%1SERVICEPOINTTYPE",str _side],_buildings] Call GetFactories;
_aar = [_side,missionNamespace getVariable Format["WFBE_%1AARADARTYPE",str _side],_buildings] Call GetFactories;
_buildings = _buildings - _command - _service - _aar;
//--- r53: Base Area disabled / pre-init leaves wfbe_basearea nil - bare "-" throws every 20s.
_areas_old = _logik getVariable ["wfbe_basearea", []];
if (isNil "_areas_old" || {typeName _areas_old != "ARRAY"}) then {_areas_old = []};

// Remove the null objects from the array, test to fix the base area bug possibly.
_areas_old = _areas_old - [objNull];

_areas = _areas_old;

{
if (!isNull _x) then {
_structure = [_x, _buildings] Call WFBE_CO_FNC_GetClosestEntity;
if (!isNull _structure) then {
if (_structure distance _x > (_brr + _mbr)) then {
//--- On deletion, remove the statics/defenses later.
[getPos _x, _side, _areas_old] Spawn _onAreaRemoved;
_areas = _areas - [_x] - [objNull];
_grp = group _x;
deleteVehicle _x;
deleteGroup _grp;
};
};
};
} forEach _areas_old;

if (count _areas_old != count _areas) then {
_logik setVariable ["wfbe_basearea", _areas, true];
};
} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER excluded: base-less, no base-area maintenance
sleep 20;
};
