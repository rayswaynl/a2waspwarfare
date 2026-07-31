//--- Nuke launching.
Private ['_cruise','_deadline','_dropPosition','_dropPosX','_dropPosY','_dropPosZ','_misFlare','_nukeMarker','_path','_pathS','_planespawnpos','_target','_type'];
_target = _this select 0;
_nukeMarker = _this select 1;

// Marty : 
_time_before_ICBM_impact = missionNamespace getVariable "WFBE_ICBM_TIME_TO_IMPACT";
//--- pack-missiles: broadcast countdown to all clients before the flight sleep.
[nil, "HandleSpecial", ["icbm-countdown", time, time + (_time_before_ICBM_impact * 60)]] Call WFBE_CO_FNC_SendToClients;

sleep (_time_before_ICBM_impact * 60) ;

// Nuke effects :
_path = "\ca\air2\cruisemissile\"; 
_pathS = _path + "data\scripts\"; 

_dropPosition = getpos _target;
_type = if (WF_A2_Vanilla || WF_A2_CombinedOps) then {'Chukar'} else {'Chukar_EP1'};
_cruise = createVehicle [_type,_dropPosition,[], 0, "FLY"];
//--- FAIL-CLEAN r45: cruise create null must not setVectorDir/setPos/velocity/flyInHeight
if (isNull _cruise) then {
	["WARNING", Format ["nukeincoming.sqf: cruise %1 create failed at %2.", _type, _dropPosition]] Call WFBE_CO_FNC_LogContent;
} else {
	_cruise setVectorDir [ 0.1,- 1,+ 0.5];
	_cruise setPos [(getPos _cruise select 0),(getPos _cruise select 1),570];
	_cruise setVelocity [0,2,0];
	_cruise flyInHeight 570;
	_cruise setSpeedMode "FULL";
};

if (isNull _cruise) exitWith {
	["WARNING", "nukeincoming.sqf: abort ICBM client flight - cruise create failed."] Call WFBE_CO_FNC_LogContent;
};

["RequestSpecial", ["ICBM",sideJoined,_target,_cruise,clientTeam]] Call WFBE_CO_FNC_SendToServer;

sleep 1.5;

[nil, "HandleSpecial", ["icbm-display", _target, _cruise]] Call WFBE_CO_FNC_SendToClients;

_misFlare = objNull;
if (WF_A2_Vanilla || WF_A2_CombinedOps) then {
	_dropPosX = _dropPosition select 0;
	_dropPosY = _dropPosition select 1;
	_dropPosZ = _dropPosition select 2;

	_planespawnpos = [_dropPosX , _dropPosY , _dropPosZ + 600];

	_misFlare = createVehicle ["cruiseMissileFlare1",_planespawnpos,[], 0, "NONE"];
	//--- FAIL-CLEAN r45: misFlare create null must not inflame/execVM pair
	if (isNull _misFlare) then {
		["WARNING", Format ["nukeincoming.sqf: cruiseMissileFlare1 create failed at %1.", _planespawnpos]] Call WFBE_CO_FNC_LogContent;
		_cruise setVariable ["cruisemissile_level", false];
		_cruise setObjectTexture [0, _path + "data\exhaust_flame_ca"];
		[_cruise] execVM (_pathS + "exhaust1.sqf");
	} else {
		_misFlare inflame true;
		_cruise setVariable ["cruisemissile_level", false];
		[_cruise, _misFlare] execVM (_pathS + "cruisemissileflare.sqf");
		_cruise setObjectTexture [0, _path + "data\exhaust_flame_ca"];
		[_cruise] execVM (_pathS + "exhaust1.sqf");
	};
};

sleep 7;

//--- Bounded wait (scheduler-leak audit 2026-07-30, confirmed-high): NOTHING in the tree ever
//--- kills the classic-path cruise (spawned uncrewed, vector +0.5 Z = climbs away forever), so
//--- 'waitUntil {!alive _cruise}' deadlocked this thread AND the server's ICBM handler (which
//--- waits on the same object before Spawn NukeDammage) - classic ICBM never detonated at all.
//--- 180s covers any Chernarus flight; on deadline the delete below fires the server's isNull
//--- escape, so NukeDammage still lands. Same detonate-by-delete idiom as the TEL path
//--- (Init_IcbmTel.sqf), which deliberately avoids this wait.
_deadline = time + 180;
waitUntil {!alive _cruise || {isNull _cruise} || {time > _deadline}};

sleep 5;
if (WF_A2_Vanilla || WF_A2_CombinedOps) then {if !(isNull _misFlare) then {deleteVehicle _misFlare}};
if !(isNull _cruise) then {deleteVehicle _cruise};

//sleep 50;
//deleteMarkerLocal _nukeMarker; 