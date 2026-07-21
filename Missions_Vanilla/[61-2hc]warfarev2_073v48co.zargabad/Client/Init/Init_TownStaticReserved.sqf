/*
	KA-02: per-object init for a town-defense static, run on every client (and
	JIP) via setVehicleInit from Server_SpawnTownDefense.sqf - the same idiom
	Common_CreateUnit.sqf/Support_Paratroopers.sqf/uav.sqf use for repair trucks,
	UAVs and paradropped vehicles. Adds a standing action so the wheel offers
	feedback instead of nothing while the static is locked for its AI gunner;
	the action is only visible while locked and never touches the lock itself
	(owned by Server_SpawnTownDefense.sqf / Server_OperateTownDefensesUnits.sqf).
*/
Private ["_entitie"];
_entitie = _this;

if (isServer && !hasInterface) exitWith {}; //--- dedicated server has no action menu to populate.
if (!isNil "isHeadLessClient" && {isHeadLessClient}) exitWith {}; //--- HC has no player watching either.

_entitie addAction ["Reserved (AI-Manned)", "Client\Action\Action_LockedStaticHint.sqf", [], 0, false, true, '', 'locked _target'];