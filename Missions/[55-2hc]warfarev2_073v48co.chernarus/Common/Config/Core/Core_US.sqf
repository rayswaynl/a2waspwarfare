/* US Configuration */
Private ['_c','_get','_i','_p','_wfbeCoastalUtility','_wfbeProbe','_z'];

_c = [];
_i = [];

/* Infantry */
_c = _c + ['US_Soldier_Light_EP1'];
_i = _i + [['','',130,4,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_EP1'];
_i = _i + [['','',150,4,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_B_EP1'];
_i = _i + [['','',155,4,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_LAT_EP1'];
_i = _i + [['','',225,5,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_AT_EP1'];
_i = _i + [['','',350,5,-1,2,0,1,'US',[]]];

_c = _c + ['US_Soldier_HAT_EP1'];
_i = _i + [['','',1050,6,-1,3,0,1,'US',[]]];

_c = _c + ['US_Soldier_AA_EP1'];
_i = _i + [['','',400,6,-1,2,0,1,'US',[]]];

_c = _c + ['US_Soldier_AR_EP1'];
_i = _i + [['','',210,5,-1,1,0,1,'US',[]]];

_c = _c + ['US_Soldier_MG_EP1'];
_i = _i + [['','',220,5,-1,1,0,1,'US',[]]];

_c = _c + ['US_Soldier_GL_EP1'];
_i = _i + [['','',160,5,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_Sniper_EP1'];
_i = _i + [['','',320,6,-1,2,0,1,'US',[]]];

_c = _c + ['US_Soldier_SniperH_EP1'];
_i = _i + [['','',350,6,-1,3,0,1,'US',[]]];

_c = _c + ['US_Soldier_Sniper_NV_EP1'];
_i = _i + [['','',370,6,-1,3,0,1,'US',[]]];

_c = _c + ['US_Soldier_Marksman_EP1'];
_i = _i + [['','',330,6,-1,2,0,1,'US',[]]];

_c = _c + ['US_Soldier_Medic_EP1'];
_i = _i + [['','',190,4,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_Engineer_EP1'];
_i = _i + [['','',225,5,-1,1,0,1,'US',[]]];

_c = _c + ['US_Soldier_AMG_EP1'];
_i = _i + [['','',185,6,-1,2,0,1,'US',[]]];

_c = _c + ['US_Soldier_AAR_EP1'];
_i = _i + [['','',185,6,-1,3,0,1,'US',[]]];

_c = _c + ['US_Soldier_AHAT_EP1'];
_i = _i + [['','',185,6,-1,3,0,1,'US',[]]];

_c = _c + ['US_Soldier_AAT_EP1'];
_i = _i + [['','',320,6,-1,3,0,1,'US',[]]];

_c = _c + ['US_Soldier_Spotter_EP1'];
_i = _i + [['','',320,6,-1,3,0,1,'US',[]]];

_c = _c + ['US_Soldier_Crew_EP1'];
_i = _i + [['','',120,4,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_Pilot_EP1'];
_i = _i + [['','',120,4,-1,0,0,1,'US',[]]];

_c = _c + ['US_Soldier_TL_EP1'];
_i = _i + [['','',240,5,-1,1,0,1,'US',[]]];

_c = _c + ['US_Soldier_SL_EP1'];
_i = _i + [['','',220,5,-1,2,0,1,'US',[]]];

_c = _c + ['US_Soldier_Officer_EP1'];
_i = _i + [['','',250,5,-1,1,0,1,'US',[]]];

/* Light Vehicles */
_c = _c + ['M1030_US_DES_EP1'];
_i = _i + [['','',150,12,-2,0,1,0,'US',[]]];

_c = _c + ['ATV_US_EP1'];
_i = _i + [['','',175,14,-2,0,1,0,'US',[]]];

_c = _c + ['HMMWV_DES_EP1'];
_i = _i + [['','',300,15,-2,0,1,0,'US',[]]];

_c = _c + ['HMMWV_M1035_DES_EP1'];
_i = _i + [['','',350,15,-2,2,1,0,'US',[]]];

_c = _c + ['HMMWV_Terminal_EP1'];
_i = _i + [['','',400,15,-2,1,1,0,'US',[]]];

_c = _c + ['HMMWV_MK19_DES_EP1'];
_i = _i + [['','',720,18,-2,1,1,0,'US',[]]];

_c = _c + ['HMMWV_M998A2_SOV_DES_EP1'];
_i = _i + [['','',950,20,-2,1,1,0,'US',[]]];

_c = _c + ['HMMWV_M1151_M2_DES_EP1'];
_i = _i + [['','',680,20,-2,2,1,0,'US',[]]];

_c = _c + ['HMMWV_M998_crows_M2_DES_EP1'];
_i = _i + [['','',900,22,-2,2,1,0,'US',[]]];

_c = _c + ['HMMWV_M998_crows_MK19_DES_EP1'];
_i = _i + [['','',1050,22,-2,2,1,0,'US',[]]];

_c = _c + ['HMMWV_TOW_DES_EP1'];
_i = _i + [['','',1450,20,-2,3,1,0,'US',[]]];

_c = _c + ['HMMWV_Avenger_DES_EP1'];
_i = _i + [['','',1750,25,-2,4,1,0,'US',[]]];

_c = _c + ['HMMWV_Ambulance_DES_EP1'];
_i = _i + [['','',4000,22,-2,2,1,0,'US',[]]];

_c = _c + ['MTVR_DES_EP1'];
_i = _i + [['','',500,20,-2,1,1,0,'US',[]]];

_c = _c + ['MtvrSalvage_DES_EP1'];
_i = _i + [['','',750,21,-2,1,1,0,'US',[]]];

_c = _c + ['MtvrRepair_DES_EP1'];
_i = _i + [['','',2500,22,-2,2,1,0,'US',[]]];

_c = _c + ['MtvrReammo_DES_EP1'];
_i = _i + [['','',1750,22,-2,1,1,0,'US',[]]];

_c = _c + ['MtvrRefuel_DES_EP1'];
_i = _i + [['','',500,22,-2,1,1,0,'US',[]]];

_c = _c + ['MtvrSupply_DES_EP1'];
_i = _i + [['','',550,25,-2,0,1,0,'US',[]]];

//--- Lane 184: default-off coastal utility boat. Units_CO_US already has RHIB in the Light-factory roster;
//--- this first-wins row makes it cheap/tier-0 only when a configured probe confirms coastal water.
if ((missionNamespace getVariable ["WFBE_C_COASTAL_UTILITY_BOATS", 0]) > 0) then {
	_wfbeCoastalUtility = false;
	{
		_wfbeProbe = _x;
		if (surfaceIsWater _wfbeProbe) exitWith {_wfbeCoastalUtility = true};
	} forEach (missionNamespace getVariable ["WFBE_C_COASTAL_UTILITY_BOAT_WATER_PROBES", []]);
	if (_wfbeCoastalUtility) then {
		_c = _c + ['RHIB'];
		_i = _i + [['Utility RHIB','',300,15,-2,0,1,0,'USMC',[]]];
	};
};

_c = _c + ['M1126_ICV_M2_EP1'];
_i = _i + [['','',1200,25,[false,true,2,0],3,2,0,'US',[]]];

_c = _c + ['M1126_ICV_mk19_EP1'];
_i = _i + [['','',1450,25,[false,true,2,0],3,2,0,'US',[]]];

_c = _c + ['M1129_MC_EP1'];
_i = _i + [['','',4800,25,-2,4,2,0,'US',[]]];

_c = _c + ['M1135_ATGMV_EP1'];
_i = _i + [['','',1850,25,-2,3,2,0,'US',[]]];

_c = _c + ['M1128_MGS_EP1'];
_i = _i + [['','',2800,25,-2,4,2,0,'US',[]]];

_c = _c + ['M1133_MEV_EP1'];
_i = _i + [['','',4500,25,-2,3,2,0,'US',[]]];

/* Heavy Vehicles */

_c = _c + ['M2A2_EP1'];
_i = _i + [['','',if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {2800} else {3800},22,-2,1,2,0,'US',[]]];

_c = _c + ['M2A3_EP1'];
_i = _i + [['','',3800,28,-2,2,2,0,'US',[]]];

_c = _c + ['M1A1_US_DES_EP1'];
_i = _i + [['','',5600,40,-2,3,2,0,'US',[]]];

_c = _c + ['MLRS_DES_EP1'];
_i = _i + [['','',8500,40,-2,3,2,0,'US',[]]];

_c = _c + ['M1A2_US_TUSK_MG_EP1'];
_i = _i + [['','',6500,40,-2,4,2,0,'US',[]]];

_c = _c + ['M6_EP1'];
_i = _i + [['','',7500,35,-2,4,2,0,'US',[]]];

//--- Lane 45: dormant USMC AAV metadata hook for a future WEST naval beach-assault lane.
//--- Flag 0 keeps current US/US_Camo heavy-factory behavior unchanged.
if ((missionNamespace getVariable ["WFBE_C_NAVAL_WEST_AAV", 0]) > 0) then {
	_c = _c + ['AAV'];
	_i = _i + [['AAV Amphibious APC','',1300,18,-2,0,2,0,'USMC',[]]];
};

//--- cmdcon42-j (Ray 2026-07-02): PRODUCIBLE SCUD (conventional) buy-row metadata — TAKISTAN ONLY (WEST/US). Price + tier
//--- from flags (default 28000 / HEAVY level 3). Fields: [label,picture,PRICE,TIME,CREW(-2=auto),UPGRADE,FACTORY(2=Heavy),SKILL,faction,turrets].
//--- Registered only when the master flag is on AND worldName=="Takistan". Explicit label so the menu shows the friendly name.
if ((missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) > 0 && {worldName == "Takistan"}) then {
	_c = _c + [missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"]];
	_i = _i + [['SCUD Launcher (conventional)','',(missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_COST", 28000]),40,-2,(missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_LEVEL", 3]),2,0,'US',[]]];
};

/* Air Vehicles */
_c = _c + ['MH6J_EP1'];
_i = _i + [['','',4928,25,-2,1,3,0,'US',[]]];   //--- B59 (Ray 2026-06-20): MH6J_EP1 air-upgrade 0->1. Was a tier-0 heli, so the strict-> tech gate passed it at air-research 0; aircraft must require an air factory (AIR-1). Rollback: ...,0,3,0,...

_c = _c + ['UH60M_EP1'];
_i = _i + [['','',7168,30,-2,1,3,0,'US',[]]];

_c = _c + ['UH60M_MEV_EP1'];
_i = _i + [['','',8168,30,-2,2,3,0,'US',[]]];

_c = _c + ['CH_47F_EP1'];
_i = _i + [['','',8976,30,-2,1,3,0,'US',[]]];

_c = _c + ['C130J_US_EP1'];
_i = _i + [['','',9440,30,-2,1,3,0,'US',[]]];

_c = _c + ['AH6X_EP1'];
_i = _i + [['AH-6X Scout','',3500,50,-2,0,3,0,'US',[]]];   //--- cmdcon42 Option C Row 1: unarmed FLIR scout Little Bird at Aircraft-Factory research level 0, 3500. Gate 0 is SAFE: the player Aircraft menu only opens with a live aircraft factory in range (updateavailableactions.fsm aircraftInRange -> Common_BuildingInRange), so the row's upgrade field is a research gate, NOT the factory-existence gate. The pre-B59 hole was the AI FOUNDING path, since independently hardened (AI_Commander_Teams.sqf air-strip until AICOM_AIR_MIN_TOWNS). Rollback to gated: ...,1,3,0,...

_c = _c + ['AH6J_EP1'];
_i = _i + [['','',9119,35,-2,2,3,0,'US',[]]];

_c = _c + ['AH64D_EP1'];
_i = _i + [['AH-64D (Hellfire)','',34707,45,-2,4,3,0,'USMC',[]]];

// A10C //
_c = _c + ['A10_US_EP1'];
_i = _i + [['A-10C','',32320,45,-2,4,3,0,'US',[]]];


/* Special */
_c = _c + ['MQ9PredatorB_US_EP1'];
_i = _i + [['','',30000,35,-2,2,3,0,'US',[]]];

/* Static Defenses */
_c = _c + ['WarfareBMGNest_M240_US_EP1'];
_i = _i + [['','',300,0,1,0,'Defense',0,'US',[]]];

_c = _c + ['M2HD_mini_TriPod_US_EP1'];
_i = _i + [['','',200,0,1,0,'Defense',0,'US',[]]];

_c = _c + ['M2StaticMG_US_EP1'];
_i = _i + [['','',225,0,1,0,'Defense',0,'US',[]]];

_c = _c + ['SearchLight_US_EP1'];
_i = _i + [['','',125,0,1,0,'Defense',0,'US',[]]];

_c = _c + ['MK19_TriPod_US_EP1'];
_i = _i + [['','',700,0,1,0,'Defense',0,'US',[]]];

_c = _c + ['TOW_TriPod_US_EP1'];
//--- cmdcon42-g: WFBE_C_DEFMENU_V2 drops the WEST AT price cliff (2000 -> 900; EAST SPG-9 = 475).
//--- Legacy price 2000 kept when the flag is off. No new class (A2-OA has no cheaper US static AT).
_i = _i + [['','',(if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2", 1]) > 0) then {900} else {2000}),0,1,0,'Defense',0,'US',[]]];

_c = _c + ['Stinger_Pod_US_EP1'];
_i = _i + [['','',3000,0,1,0,'Defense',0,'US',[]]];

_c = _c + ['M252_US_EP1'];
_i = _i + [['','',1150,0,1,0,'Defense',0,'US',[]]];

_c = _c + ['M119_US_EP1'];
_i = _i + [['','',2800,0,1,0,'Defense',0,'US',[]]];

/* Defense Structures */
_c = _c + ['US_WarfareBBarrier5x_EP1'];
_i = _i + [['','',50,0,0,0,'Fortification',0,'US',[]]];

_c = _c + ['US_WarfareBBarrier10x_EP1'];
_i = _i + [['','',100,0,0,0,'Fortification',0,'US',[]]];

_c = _c + ['US_WarfareBBarrier10xTall_EP1'];
_i = _i + [['','',200,0,0,0,'Fortification',0,'US',[]]];

//--- cmdcon42-g: WFBE_C_DEFMENU_V2 recategorises camo nets Strategic -> Fortification (findability).
//--- Legacy 'Strategic' kept when the flag is off.
_c = _c + ['Land_CamoNet_NATO_EP1'];
_i = _i + [['','',35,0,0,0,(if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2", 1]) > 0) then {'Fortification'} else {'Strategic'}),0,'US',[]]];

_c = _c + ['Land_CamoNetVar_NATO_EP1'];
_i = _i + [['','',45,0,0,0,(if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2", 1]) > 0) then {'Fortification'} else {'Strategic'}),0,'US',[]]];

_c = _c + ['Land_CamoNetB_NATO_EP1'];
_i = _i + [['','',55,0,0,0,(if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2", 1]) > 0) then {'Fortification'} else {'Strategic'}),0,'US',[]]];

_c = _c + ['USOrdnanceBox_EP1'];
_i = _i + [['','',850,0,0,0,'Ammo',0,'US',[]]];

_c = _c + ['USVehicleBox_EP1'];
_i = _i + [['','',1200,0,0,0,'Ammo',0,'US',[]]];

_c = _c + ['USBasicAmmunitionBox_EP1'];
_i = _i + [['','',1950,0,0,0,'Ammo',0,'US',[]]];

_c = _c + ['USBasicWeapons_EP1'];
_i = _i + [['','',2975,0,0,0,'Ammo',0,'US',[]]];

_c = _c + ['USLaunchers_EP1'];
_i = _i + [['','',6250,0,0,0,'Ammo',0,'US',[]]];

_c = _c + ['USSpecialWeapons_EP1'];
_i = _i + [['','',7200,0,0,0,'Ammo',0,'US',[]]];

/* Service point */

_c = _c + ['US_WarfareBVehicleServicePoint_Base_EP1'];
_i = _i + [['','',5500,0,0,0,'Strategic',0,'US',[]]];

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
			diag_log Format ["[WFBE (INIT)][frameno:%2 | ticktime:%3] Core_US: Duplicated Element found '%1'",(_c select _z),diag_frameno,diag_tickTime];
		};
	} else {
		diag_log Format ["[WFBE (ERROR)][frameno:%2 | ticktime:%3] Core_US: Element '%1' is not a valid class.",(_c select _z),diag_frameno,diag_tickTime];
	};
};

//--- cmdcon42 Option C Row 2: SYNTHETIC buy token "AH6X_M134" ("AH-6X (M134)").
//--- The buy pipeline (GUI_Menu_BuyUnits -> Client_BuildUnit) keys a purchase entirely on its
//--- classname STRING, both as the metadata-registry key AND as the createVehicle class, and the
//--- row's index/label are discarded. So two buy rows that spawn the SAME hull with DIFFERENT
//--- loadouts are impossible unless the second row carries a distinct registry key. "AH6X_M134"
//--- is that distinct key: it is NOT a CfgVehicles class (so it is registered here MANUALLY, after
//--- the isClass-guarded loop above that would reject it), and it is remapped to the real hull
//--- AH6X_EP1 inside Client_BuildUnit.sqf BEFORE createVehicle, which then arms it with a TwinM134.
//--- We register by DEEP-COPYing the already-resolved AH6X_EP1 tuple so the crew-slot [4], turret
//--- list [9] and portrait [1] are byte-identical to the real hull (the buy dialog crew icons and
//--- Client_BuildUnit moveInTurret read [4]/[9] straight from the tuple), then override name [0]
//--- and price [2]. isNil-guarded so a missing base registration only drops the row (never errors).
if (!isNil {missionNamespace getVariable "AH6X_EP1"}) then {
	private "_ah6xM134";
	_ah6xM134 = +(missionNamespace getVariable "AH6X_EP1");   //--- deep copy: inherits [1] picture, [4] crew, [5] gate=0, [6] air, [9] turrets
	_ah6xM134 set [QUERYUNITLABEL, "AH-6X (M134)"];           //--- [0] display name
	_ah6xM134 set [QUERYUNITPRICE, 5500];                     //--- [2] price
	missionNamespace setVariable ["AH6X_M134", _ah6xM134];
	diag_log Format ["[WFBE (INIT)][frameno:%1 | ticktime:%2] Core_US: Registered synthetic buy token 'AH6X_M134' (AH-6X M134) as a copy of AH6X_EP1.",diag_frameno,diag_tickTime];
} else {
	diag_log "[WFBE (WARNING)] Core_US: AH6X_EP1 not registered - cannot create synthetic AH6X_M134 token; the AH-6X (M134) buy row will be hidden.";
};

//--- cmdcon42-i: Takistan-only EASA-loadout air variant roster (WEST/US rows).
//--- Each synthetic buy token is registered as a DEEP COPY of its already-resolved base-hull buy tuple
//--- (so crew [4]/turrets [9]/picture [1] are byte-identical to the real hull the buy dialog + Client_BuildUnit
//--- read), then name [0], price [2] and air-research level [5] (QUERYUNITUPGRADE) are overridden. The token
//--- is remapped to its base hull in Client_BuildUnit BEFORE createVehicle and armed with the kit there.
//--- Mirrors the AH6X_M134 precedent (PR #151 / commit a6a61a098). Catalog is TAKISTAN + flag gated internally
//--- (returns [] on Chernarus or when WFBE_C_TK_EASA_ROSTER <= 0), so this whole block is a no-op on Chernarus.
private ["_tkEasaRoster","_tkeRow","_tkeBase","_tkeTuple"];
_tkEasaRoster = Call Compile preprocessFile "Common\Functions\Common_TKEasaRoster.sqf";
{
	_tkeRow = _x;
	if ((_tkeRow select 2) == "US") then {
		_tkeBase = missionNamespace getVariable (_tkeRow select 1); //--- resolved base-hull tuple (registered above)
		if (!isNil "_tkeBase") then {
			_tkeTuple = +_tkeBase;                                   //--- deep copy: inherits [1] picture, [4] crew, [6] factory, [9] turrets
			_tkeTuple set [QUERYUNITLABEL,   _tkeRow select 3];      //--- [0] display name
			_tkeTuple set [QUERYUNITPRICE,   _tkeRow select 4];      //--- [2] price
			_tkeTuple set [QUERYUNITUPGRADE, _tkeRow select 5];      //--- [5] air-research level gate
			missionNamespace setVariable [(_tkeRow select 0), _tkeTuple];
			diag_log Format ["[WFBE (INIT)][frameno:%2 | ticktime:%3] Core_US: Registered TK-EASA variant token '%1' (base %4).",(_tkeRow select 0),diag_frameno,diag_tickTime,(_tkeRow select 1)];
		} else {
			diag_log Format ["[WFBE (WARNING)] Core_US: TK-EASA base hull '%1' not registered - variant '%2' hidden.",(_tkeRow select 1),(_tkeRow select 0)];
		};
	};
} forEach _tkEasaRoster;

diag_log Format ["[WFBE (INIT)][frameno:%2 | ticktime:%3] Core_US: Initialization (%1 Elements) - [Done]",count _c,diag_frameno,diag_tickTime];
