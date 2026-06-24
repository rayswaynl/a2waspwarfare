/* GUE Configuration */
Private ['_c','_get','_i','_p','_z'];

_c = [];
_i = [];

/* Infantry */
_c = _c + ['GUE_Soldier_1'];
_i = _i + [['','',150,4,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_2'];
_i = _i + [['','',120,4,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_3'];
_i = _i + [['','',140,4,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_GL'];
_i = _i + [['','',150,5,-1,1,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_AT'];
_i = _i + [['','',220,5,-1,1,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_AA'];
_i = _i + [['','',250,4,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_AR'];
_i = _i + [['','',150,4,-1,1,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_MG'];
_i = _i + [['','',190,4,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_Sniper'];
_i = _i + [['','',175,6,-1,1,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_Medic'];
_i = _i + [['','',160,6,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_Crew'];
_i = _i + [['','',120,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_Pilot'];
_i = _i + [['','',120,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_Scout'];
_i = _i + [['','',260,5,-1,3,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_CO'];
_i = _i + [['','',300,5,-1,1,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Soldier_Sab'];
_i = _i + [['','',220,5,-1,2,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Commander'];
_i = _i + [['','',240,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Worker2'];
_i = _i + [['','',100,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Woodlander3'];
_i = _i + [['','',100,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Villager3'];
_i = _i + [['','',100,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Woodlander2'];
_i = _i + [['','',100,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Woodlander1'];
_i = _i + [['','',100,5,-1,0,0,1,'Guerilla',[]]];

_c = _c + ['GUE_Villager4'];
_i = _i + [['','',100,5,-1,0,0,1,'Guerilla',[]]];

/* Light Vehicles */
_c = _c + ['TT650_Gue'];
_i = _i + [['','',150,15,-2,0,1,0,'Guerilla',[]]];

_c = _c + ['V3S_Gue'];
_i = _i + [['','',175,15,-2,0,1,0,'Guerilla',[]]];

_c = _c + ['Pickup_PK_GUE'];
_i = _i + [['','',250,17,-2,0,1,0,'Guerilla',[]]];

_c = _c + ['Offroad_DSHKM_Gue'];
_i = _i + [['','',550,25,-2,1,1,0,'Guerilla',[]]];

_c = _c + ['Offroad_SPG9_Gue'];
_i = _i + [['','',750,20,-2,2,1,0,'Guerilla',[]]];
_c = _c + ['WarfareRepairTruck_Gue'];
_i = _i + [['','',425,17,-2,2,1,0,'Guerilla',[]]];

_c = _c + ['WarfareSalvageTruck_Gue'];
_i = _i + [['','',450,17,-2,1,1,0,'Guerilla',[]]];

_c = _c + ['WarfareReammoTruck_Gue'];
_i = _i + [['','',450,18,-2,1,1,0,'Guerilla',[]]];

_c = _c + ['WarfareSupplyTruck_Gue'];
_i = _i + [['','',450,21,-2,0,1,0,'Guerilla',[]]];

_c = _c + ['BRDM2_Gue'];
_i = _i + [['','',1200,25,-2,2,1,0,'Guerilla',[]]];

_c = _c + ['Ural_ZU23_Gue'];
_i = _i + [['','',1100,20,-2,2,1,0,'Guerilla',[]]];

/* Heavy Vehicles */
_c = _c + ['M113_UN_EP1'];
_i = _i + [['','',1100,30,-2,0,2,0,'Takistani Guerilla',[]]];

_c = _c + ['BMP2_Gue'];
_i = _i + [['','',3400,28,-2,1,2,0,'Guerilla',[]]];

_c = _c + ['T72_Gue'];
_i = _i + [['','',5200,35,-2,3,2,0,'Guerilla',[]]];

/* GUER player faction additions (Warlord roster) - not in the base GUE buy config */
//--- C1 (price-collision fix): T34/T55/BTR40_TK_GUE_EP1, An2_1/2_TK_CIV_EP1, UH1H_TK_GUE_EP1 are
//--- registered canonically by Core_TKGUE/Core_TKCIV (which load AFTER Core_GUE). Their Core_GUE copies
//--- here only won the first-registration race with WRONG prices and spammed "Duplicated Element" in the
//--- TK files - dropped so the canonical TK prices stand. hilux1_civil_2_covered / datsun1_civil_2_covered /
//--- Mi17_Civilian are registered by Core_CIV (loads BEFORE Core_GUE -> Core_GUE copies were already dead
//--- dups); their GUER-intended prices (400/400/6000) now live on the canonical Core_CIV entries. Ka137_MG_PMC
//--- and Mi24_P are KEPT here on purpose: Core_GUE loads before Core_PMC/Core_RU, so these correctly win and
//--- set the GUER-intended prices (6000 / 18000).
_c = _c + ['Ka137_MG_PMC'];
_i = _i + [['','',6000,40,-2,1,1,0,'Guerilla',[]]];   //--- B66 (Ray 2026-06-21): air-upgrade(idx5) 0->1. SAME registration-race as the B60 Mi24_P fix below: Core_GUE loads before Core_PMC, so this entry wins the Ka137_MG_PMC registration (keeps the GUER price 6000) but it ALSO stamped air-level 0 onto the GLOBAL Ka137_MG_PMC, which Squads_GetFactionGroups feeds to the AICOM founding/produce air-gate -> the classname read as air-level 0 (ungated/mis-gated). Price 6000 still wins; only the air-level is corrected to PMC's canonical 1 (Core_PMC.sqf: ['','',3500,35,-2,1,3,0,'PMC',[]]). GUER is base-less (no founding gate) so unaffected; the fix is for the global classname the air-gate keys on. Rollback: ...,0,1,0,...
_c = _c + ['Mi24_P'];
_i = _i + [['','',18000,60,-2,3,3,0,'Guerilla',[]]];   //--- B60 (Ray 2026-06-21): air-upgrade(idx5) 0->3. Core_GUE wins the Mi24_P registration race over Core_RU (load order) - the comment above keeps it to win the GUER PRICE (18000), but it also stamped air-level 0 onto the GLOBAL Mi24_P, which Squads_GetFactionGroups feeds to the AICOM founding/produce air-gate -> EAST/RU could field ungated Mi24_P (only B59's town-strip still blocked it). Price 18000 still wins; only the air-level is corrected to RU's canonical 3. GUER is base-less (no founding gate) so unaffected. Rollback: ...,0,3,0,...

/* Static Defenses */
_c = _c + ['GUE_WarfareBMGNest_PK'];
_i = _i + [['','',300,0,1,0,'Defense',0,'Guerilla',[]]];

_c = _c + ['DSHKM_Gue'];
_i = _i + [['','',225,0,1,0,'Defense',0,'Guerilla',[]]];

_c = _c + ['SPG9_Gue'];
_i = _i + [['','',675,0,1,0,'Defense',0,'Guerilla',[]]];

_c = _c + ['ZU23_Gue'];
_i = _i + [['','',700,0,1,0,'Defense',0,'Guerilla',[]]];
_c = _c + ['2b14_82mm_GUE'];
_i = _i + [['Podnos 2B14','',1025,0,1,0,'Defense',0,'Guerilla',[]]];

for '_z' from 0 to (count _c)-1 do {
	if (isClass (configFile >> 'CfgVehicles' >> (_c select _z))) then {
		_get = missionNamespace getVariable (_c select _z);
		if (isNil '_get') then {
			if ((_i select _z) select 0 == '') then {(_i select _z) set [0, [_c select _z,'displayName'] Call GetConfigInfo]};
			if (typeName ((_i select _z) select 4) == 'SCALAR') then {
				if (((_i select _z) select 4) == -2) then {
					_ret = (_c select _z) Call Compile preprocessFile "Common\Functions\Common_GetConfigVehicleCrewSlot.sqf";
					(_i select _z) set [4, _ret select 0];
					(_i select _z) set [9, _ret select 1];
				};
			};
			if (WF_Debug) then {(_i select _z) set [3,1]};
			_p = if ((_c select _z) isKindOf 'Man') then {'portrait'} else {'picture'};
			(_i select _z) set [1, [_c select _z,_p] Call GetConfigInfo];
			missionNamespace setVariable [_c select _z, _i select _z];
		} else {
			diag_log Format ["[WFBE (INIT)][frameno:%2 | ticktime:%3] Core_GUE: Duplicated Element found '%1'",(_c select _z),diag_frameno,diag_tickTime];
		};
	} else {
		diag_log Format ["[WFBE (ERROR)][frameno:%2 | ticktime:%3] Core_GUE: Element '%1' is not a valid class.",(_c select _z),diag_frameno,diag_tickTime];
	};
};

diag_log Format ["[WFBE (INIT)][frameno:%2 | ticktime:%3] Core_GUE: Initialization (%1 Elements) - [Done]",count _c,diag_frameno,diag_tickTime];