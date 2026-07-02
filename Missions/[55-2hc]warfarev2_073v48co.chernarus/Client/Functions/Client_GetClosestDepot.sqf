/*	Return the closest depot of the given entitie.	 Parameters:		- Object*/
//--- cmdcon43-n2 (2026-07-03) GUER TOWN-CENTER BUY FIX. The base-less GUER "Insurgents" faction has no
//--- factories/service points; the town-center DEPOT is their ONLY vehicle economy, and the buy menu funnels
//--- every GUER purchase through THIS getter (GUI_Menu_BuyUnits.sqf:376 -> _closest; a null _closest means the
//--- purchase resolves against objNull in Client_BuildUnit -> nothing spawns, then the BUYFAIL guard refunds).
//---
//--- The canonical GUER design (wiki "GUER Insurgents Faction Overview") is that GUER operates at FRIENDLY town
//--- centers = ANY town NOT held by WEST and NOT held by EAST (i.e. GUER-held OR neutral) - the exact idiom the
//--- other two GUER town-center paths already use: Client_CanUseTownCenterEASA.sqf:23 and the GUER initial-spawn/
//--- respawn town pick (Init_Client.sqf:983, Client_GetRespawnAvailable.sqf). The stock gate below instead keyed
//--- on the strict numeric `sideID == sideID`. That happens to match neutral+GUER towns for a GUER buyer (all
//--- carry sideID 2), but it is (a) INCONSISTENT with the documented friendly-town rule and (b) FRAGILE: a town
//--- whose "sideID" is momentarily unset (freshly created / mid-flip / a just-contested logic that has not yet
//--- re-published) is silently dropped by the `!isNil` pre-guard, stranding a GUER buyer standing right at a
//--- genuinely-friendly town centre. This is the "GUER players cant buy cars at towncenters" report.
//---
//--- Fix: when the buyer is GUER (playable-GUER gate on + resistance) and WFBE_C_GUER_DEPOT_NEUTRAL_BUY > 0,
//--- select any depot that is NOT WEST-held and NOT EAST-held, reading sideID with a -1 default (an unset/contested
//--- friendly town then reads -1, which is neither WEST nor EAST, so it stays eligible). WEST/EAST buyers are
//--- UNCHANGED - they keep the strict own-side gate (byte-for-byte stock behaviour). A2-OA-1.64 safe: nearEntities,
//--- getVariable [name,default], explicit numeric == / != (never on booleans), private decls, no A3 commands.
Private ["_closest","_near","_pos","_range","_guerFriendly","_sid","_westId","_eastId"];
_closest = objNull;
_pos = _this select 0;
_range = _this select 1;
_near = _pos nearEntities [WFBE_Logic_Depot, _range];
_guerFriendly = (sideJoined == resistance) && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0} && {(missionNamespace getVariable ["WFBE_C_GUER_DEPOT_NEUTRAL_BUY", 1]) > 0};
_westId = missionNamespace getVariable ["WFBE_C_WEST_ID", 0];
_eastId = missionNamespace getVariable ["WFBE_C_EAST_ID", 1];
{
	if (isNil {_x getVariable "wfbe_inactive"}) then {
		if (_guerFriendly) then {
			//--- GUER buyer: accept GUER-held OR neutral (any town not WEST-held, not EAST-held).
			_sid = _x getVariable ["sideID", -1];
			if ((_sid != _westId) && {_sid != _eastId}) then {_closest = _x};
		} else {
			//--- WEST/EAST buyer (or GUER with the widening flag off): strict own-side depot only (stock behaviour).
			if (!(isNil {_x getVariable "sideID"}) && {(_x getVariable "sideID") == sideID}) then {_closest = _x};
		};
	};
} forEach _near;
_closest
