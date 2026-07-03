/* CIV Configuration */
Private ['_c','_get','_i','_p','_z'];

_c = [];
_i = [];

/* Infantry */
_c = _c + ['Worker1'];
_i = _i + [['','',375,4,-1,0,0,0.4,'Civilians',[]]];

_c = _c + ['Worker2'];
_i = _i + [['','',375,4,-1,0,0,0.4,'Civilians',[]]];

_c = _c + ['Worker3'];
_i = _i + [['','',375,4,-1,0,0,0.4,'Civilians',[]]];

_c = _c + ['Worker4'];
_i = _i + [['','',375,4,-1,0,0,0.4,'Civilians',[]]];

/* Light Vehicles */
_c = _c + ['MMT_Civ'];
_i = _i + [['','',50,8,-2,0,1,0,'Civilians',[]]];

_c = _c + ['TT650_Civ'];
_i = _i + [['','',100,12,-2,0,1,0,'Civilians',[]]];

_c = _c + ['Tractor'];
_i = _i + [['','',150,15,-2,0,1,0,'Civilians',[]]];

_c = _c + ['Lada1'];
_i = _i + [['','',175,18,-2,0,1,0,'Civilians',[]]];

_c = _c + ['Lada2'];
_i = _i + [['','',175,18,-2,0,1,0,'Civilians',[]]];

_c = _c + ['LadaLM'];
_i = _i + [['','',180,20,-2,0,1,0,'Civilians',[]]];

_c = _c + ['SkodaBlue'];
_i = _i + [['','',190,17,-2,0,1,0,'Civilians',[]]];

_c = _c + ['SkodaRed'];
_i = _i + [['','',190,17,-2,0,1,0,'Civilians',[]]];

_c = _c + ['car_sedan'];
_i = _i + [['','',200,20,-2,0,1,0,'Civilians',[]]];

_c = _c + ['car_hatchback'];
_i = _i + [['','',220,20,-2,0,1,0,'Civilians',[]]];

_c = _c + ['datsun1_civil_1_open'];
_i = _i + [['','',250,22,-2,0,1,0,'Civilians',[]]];

_c = _c + ['datsun1_civil_2_covered'];
_i = _i + [['','',400,22,-2,0,1,0,'Civilians',[]]]; //--- C1: canonical price (GUER VBIED uses this on Takistan; Core_GUE dup dropped, first-wins).

_c = _c + ['datsun1_civil_3_open'];
_i = _i + [['','',250,22,-2,0,1,0,'Civilians',[]]];

_c = _c + ['VWGolf'];
_i = _i + [['','',270,23,-2,0,1,0,'Civilians',[]]];

_c = _c + ['hilux1_civil_1_open'];
_i = _i + [['','',340,25,-2,0,1,0,'Civilians',[]]];

_c = _c + ['hilux1_civil_2_covered'];
_i = _i + [['','',400,25,-2,0,1,0,'Civilians',[]]]; //--- C1: canonical price (GUER VBIED uses this on Chernarus; Core_GUE dup dropped, first-wins).

_c = _c + ['V3S_Civ'];
_i = _i + [['','',380,22,-2,0,1,0,'Civilians',[]]];

_c = _c + ['UralCivil'];
_i = _i + [['','',390,25,-2,0,1,0,'Civilians',[]]];

_c = _c + ['Ikarus'];
_i = _i + [['','',420,25,-2,0,1,0,'Civilians',[]]];

_c = _c + ['Smallboat_1'];
_i = _i + [['','',350,30,-2,0,1,0,'Civilians',[]]];

_c = _c + ['Smallboat_2'];
_i = _i + [['','',350,30,-2,0,1,0,'Civilians',[]]];

_c = _c + ['Fishing_Boat'];
_i = _i + [['','',800,30,-2,0,1,0,'Civilians',[]]];

/* Air Vehicles */
_c = _c + ['Mi17_Civilian'];
_i = _i + [['','',6000,35,-2,0,3,0,'Civilians',[]]]; //--- C1: canonical price (shared with GUER air; Core_GUE dup dropped, first-wins).
/* Defense Structures */
_c = _c + ['Land_HBarrier3'];
_i = _i + [['','',30,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_HBarrier5'];
_i = _i + [['','',50,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_HBarrier_large'];
_i = _i + [['','',80,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_fort_bagfence_long'];
_i = _i + [['','',10,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_fort_bagfence_corner'];
_i = _i + [['','',8,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_fort_bagfence_round'];
_i = _i + [['','',12,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Hhedgehog_concreteBig'];
_i = _i + [['','',95,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Hedgehog'];
_i = _i + [['','',5,0,0,0,'Fortification',0,'Civilians',[]]];

//__________SPAWNMARKER NOW____________________

_c = _c + ['Sr_border'];
_i = _i + [['B SPAWNPOINT','',15,0,0,0,'Strategic',0,'Civilians',[]]];

_c = _c + ['HeliH'];
_i = _i + [['LF SPAWNPOINT','',15,0,0,0,'Strategic',0,'Civilians',[]]];

_c = _c + ['HeliHRescue'];
_i = _i + [['HF SPAWNPOINT','',15,0,0,0,'Strategic',0,'Civilians',[]]];

_c = _c + ['HeliHCivil'];
_i = _i + [['AF SPAWNPOINT','',15,0,0,0,'Strategic',0,'Civilians',[]]];

//______________________________________________

_c = _c + ['MASH'];
_i = _i + [['','',30,0,0,0,'Strategic',0,'Civilians',[]]];

_c = _c + ['Land_Ind_SawMillPen'];
_i = _i + [['Roof','',150,0,0,0,'Strategic',0,'Civilians',[]]];
_c = _c + ['Land_Campfire'];
_i = _i + [['','',3,0,0,0,'Strategic',0,'Civilians',[]]];

_c = _c + ['Base_WarfareBBarrier5x'];
_i = _i + [['','',15,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Base_WarfareBBarrier10x'];
_i = _i + [['','',25,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Base_WarfareBBarrier10xTall'];
_i = _i + [['','',50,0,0,0,'Fortification',0,'Civilians',[]]];



_c = _c + ['Land_fortified_nest_small'];
_i = _i + [['','',40,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_fortified_nest_big'];
_i = _i + [['','',100,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_Fort_Watchtower'];
_i = _i + [['','',125,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_fort_rampart'];
_i = _i + [['','',30,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_fort_artillery_nest'];
_i = _i + [['','',65,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Sign_Danger'];
_i = _i + [[localize 'STR_WF_Minefield','',1200,0,0,0,'Strategic',0,'Civilians',[]]];

_c = _c + ['Fort_RazorWire'];
_i = _i + [['','',25,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_Ind_IlluminantTower'];
_i = _i + [['','',200,0,0,0,'Fortification',0,'Civilians',[]]];

//--- WDDM commander positions (Stage 1): anchor placeholders for composition buildables.
//--- Label/price/category only; the anchor model is just the placement ghost (the composition
//--- itself is spawned by Server\Functions\Server_ConstructPosition.sqf). Price is a flat MVP value.
//--- cmdcon44-a (Build 89): WFBE_C_DEFMENU_V2_POSITIONS ON = reworked positions -> relabel the six rows so
//--- the change is visible in the menu text (the weapon + role are named). Flag OFF = exact legacy labels.
//--- The composition rework itself lives in Init_Defenses.sqf under the same flag.
private "_defPosV2";
_defPosV2 = ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2_POSITIONS", 1]) > 0);

_c = _c + ['Land_Ind_BoardsPack1'];
_i = _i + [[(if (_defPosV2) then {'AA Nest — Stinger/ZU-23 (Light, 2 AI)'} else {'AA Position (Light, 2 AI)'}),'',2500,0,0,0,'Defense',0,'Civilians',[]]];

_c = _c + ['Land_CncBlock_Stripes'];
_i = _i + [[(if (_defPosV2) then {'AA Battery — SAM/flak (Heavy, 4 AI)'} else {'AA Position (Heavy, 4 AI)'}),'',4500,0,0,0,'Defense',0,'Civilians',[]]];

_c = _c + ['Land_Barrel_sand'];
_i = _i + [[(if (_defPosV2) then {'Artillery Pit — howitzer (Light, 1 AI)'} else {'Artillery (Light, 1 AI)'}),'',2500,0,0,0,'Defense',0,'Civilians',[]]];

_c = _c + ['Land_Ind_BoardsPack2'];
_i = _i + [[(if (_defPosV2) then {'Artillery Battery — 3 guns (Heavy, 4 AI)'} else {'Artillery (Heavy, 4 AI)'}),'',5000,0,0,0,'Defense',0,'Civilians',[]]];

_c = _c + ['Land_WoodenRamp'];
_i = _i + [[(if (_defPosV2) then {'Mixed Post — MG/AT/AA (Light, 2 AI)'} else {'Mixed Position (Light, 2 AI)'}),'',2500,0,0,0,'Defense',0,'Civilians',[]]];

_c = _c + ['RoadCone'];
_i = _i + [[(if (_defPosV2) then {'Mixed Strongpoint — MG/ATGM/AA (Heavy, 4 AI)'} else {'Mixed Position (Heavy, 4 AI)'}),'',5000,0,0,0,'Defense',0,'Civilians',[]]];

_c = _c + ['Paleta1'];
_i = _i + [['Base Wall - Straight','',250,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Paleta2'];
_i = _i + [['Base Wall - Corner','',300,0,0,0,'Fortification',0,'Civilians',[]]];

_c = _c + ['Land_Ind_Timbers'];
_i = _i + [['Base Wall - Gate','',300,0,0,0,'Fortification',0,'Civilians',[]]];

//======================================================================================
//--- cmdcon42-g: DEFENSES/FORTIFICATIONS MENU v2 — shared (side-neutral) buildables.
//--- These data arrays are always registered (harmless if a side's DEFENSENAMES list does
//--- not reference them; the menu only shows classes present in that side's list). The names
//--- lists gate visibility per side + per flag (Structures_CO_*.sqf v2 blocks).
//======================================================================================
//--- Watchtower (OA variant, IN-TREE = WFBE_C_CAMP). Elevated overwatch buildable, Fortification/Utility.
_c = _c + ['Land_Fort_Watchtower_EP1'];
_i = _i + [['Watchtower','',150,0,0,0,'Fortification',0,'Civilians',[]]];

//--- Hedgehog Line anchor (Misc_cargo_cont_small ghost -> WFBE_NEURODEF_HEDGEHOGLINE = 4x Hedgehog_EP1).
//--- One-click AT obstacle line. Category Fortification.
_c = _c + ['Misc_cargo_cont_small'];
_i = _i + [['Hedgehog Line (AT obstacle)','',30,0,0,0,'Fortification',0,'Civilians',[]]];

//--- Flak Tower anchor (Land_Ind_TankSmall ghost -> WFBE_NEURODEF_FLAKTOWER_WEST/EAST = tower + AA @ deck).
//--- Elevated AA + pooled AI gunner. Category Defense. Sub-flag WFBE_C_DEF_FLAKTOWER gates its NAME entry.
_c = _c + ['Land_Ind_TankSmall'];
_i = _i + [['Flak Tower (elevated AA, 1 AI)','',1400,0,0,0,'Defense',0,'Civilians',[]]];

//--- Site Clearance (commander build-menu only; cost is dynamic server-side; label carries the per-tree price).
if ((missionNamespace getVariable ["WFBE_C_UNITS_BULLDOZER", 0]) > 0) then {
	_c = _c + ['Land_Pneu'];
	_i = _i + [['Site Clearance (10/tree)','',0,0,0,0,'Strategic',0,'Civilians',[]]];
};

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
			diag_log Format ["[WFBE (INIT)][frameno:%2 | ticktime:%3] Core_CIV: Duplicated Element found '%1'",(_c select _z),diag_frameno,diag_tickTime];
		};
	} else {
		diag_log Format ["[WFBE (ERROR)][frameno:%2 | ticktime:%3] Core_CIV: Element '%1' is not a valid class.",(_c select _z),diag_frameno,diag_tickTime];
	};
};

diag_log Format ["[WFBE (INIT)][frameno:%2 | ticktime:%3] Core_CIV: Initialization (%1 Elements) - [Done]",count _c,diag_frameno,diag_tickTime];