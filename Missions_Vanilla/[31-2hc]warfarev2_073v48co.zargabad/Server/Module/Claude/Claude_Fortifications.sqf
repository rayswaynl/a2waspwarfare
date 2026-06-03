//============================================================================
//  [CLAUDE FEATURE - REMOVABLE]   WDDM Fortifications  -  Zargabad
//  ---------------------------------------------------------------------------
//  Border wall + two fortress-style Starting FOBs, DESIGNED IN WDDM
//  (rayswaynl.github.io/WDDM) and exported as composition templates in the
//  canonical WDDM shape:  ['classname',[x,y,z],relDir]  (+Y front, +X right),
//  spawned by the WASP CreateDefenseTemplate helper (origin modelToWorld +
//  flatten Z + setDir(originDir-relDir)) - the same path Codex's Init_Zargabad
//  already uses, so these drop straight in.
//
//  Templates (load any of these into WDDM via Import to view/edit):
//    WFBE_CLAUDE_WALL_BORDER   - neutral layered obstacle line (wall+wire+teeth+towers)
//    WFBE_CLAUDE_FOB_WEST      - NATO fortress FOB (M2/TOW/Stinger), faces +Y (enemy)
//    WFBE_CLAUDE_FOB_EAST      - WarPac fortress FOB (KORD/Metis/Igla), faces +Y (enemy)
//
//  Toggle: WFBE_C_CLAUDE_FORTS_ENABLED (default 1). Server-only. Arma 2 OA safe.
//  NOTE (coordination): this is the WDDM "fortress" upgrade of the base defenses.
//  If Codex's hand-rolled base perimeter (_baseWalls in Init_Zargabad) is also on,
//  set one of them off to avoid double-stacking. Remove: delete this file + its
//  line in Claude_Features_Init.sqf.
//============================================================================
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLAUDE_FORTS_ENABLED", 1]) <= 0) exitWith {};

waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};

//==================== WDDM-EXPORTED TEMPLATES ====================
//--- Border wall: a ~44 m tileable, faction-neutral fortified line. Solid H-barrier
//--- face, a sandbag firing step + 3 watchtowers + 2 nests behind, and a forward belt
//--- of razor wire, Czech hedgehogs and dragon's-teeth Cnc blocks to channel armour.
missionNamespace setVariable ["WFBE_CLAUDE_WALL_BORDER", [
	["Land_HBarrier_large",[-20,0,0],0],["Land_HBarrier_large",[-15,0,0],0],["Land_HBarrier_large",[-10,0,0],0],
	["Land_HBarrier_large",[-5,0,0],0],["Land_HBarrier_large",[0,0,0],0],["Land_HBarrier_large",[5,0,0],0],
	["Land_HBarrier_large",[10,0,0],0],["Land_HBarrier_large",[15,0,0],0],["Land_HBarrier_large",[20,0,0],0],
	["Land_fort_watchtower_EP1",[-15,-3,0],0],["Land_fort_watchtower_EP1",[0,-3,0],0],["Land_fort_watchtower_EP1",[15,-3,0],0],
	["Land_fortified_nest_small_EP1",[-9,-2.5,0],0],["Land_fortified_nest_small_EP1",[9,-2.5,0],0],
	["Land_fort_bagfence_long",[-6,-1.5,0],0],["Land_fort_bagfence_long",[-3,-1.5,0],0],["Land_fort_bagfence_long",[3,-1.5,0],0],["Land_fort_bagfence_long",[6,-1.5,0],0],
	["Fort_RazorWire",[-16,4,0],0],["Fort_RazorWire",[-8,4,0],0],["Fort_RazorWire",[0,4,0],0],["Fort_RazorWire",[8,4,0],0],["Fort_RazorWire",[16,4,0],0],
	["Hedgehog",[-12,3,0],0],["Hedgehog",[-4,3,0],0],["Hedgehog",[4,3,0],0],["Hedgehog",[12,3,0],0],
	["Land_CncBlock_Stripes",[-14,6,0],0],["Land_CncBlock_Stripes",[-10,6,0],0],["Land_CncBlock_Stripes",[-6,6,0],0],["Land_CncBlock_Stripes",[-2,6,0],0],
	["Land_CncBlock_Stripes",[2,6,0],0],["Land_CncBlock_Stripes",[6,6,0],0],["Land_CncBlock_Stripes",[10,6,0],0],["Land_CncBlock_Stripes",[14,6,0],0]
]];

//--- Fortress FOB - NATO (WEST). 44x44 H-barrier curtain wall with corner towers, a
//--- rear vehicle gate, M2 MGs on each wall, a front TOW + central Stinger, sandbag
//--- weapon pits, camo nets + ammo inside, and a forward wire/hedgehog obstacle belt.
missionNamespace setVariable ["WFBE_CLAUDE_FOB_WEST", [
	// front curtain (faces enemy, +Y)
	["Land_HBarrier_large",[-17.5,20,0],0],["Land_HBarrier_large",[-12.5,20,0],0],["Land_HBarrier_large",[-7.5,20,0],0],["Land_HBarrier_large",[-2.5,20,0],0],["Land_HBarrier_large",[2.5,20,0],0],["Land_HBarrier_large",[7.5,20,0],0],["Land_HBarrier_large",[12.5,20,0],0],["Land_HBarrier_large",[17.5,20,0],0],
	// side walls
	["Land_HBarrier_large",[-20,-15,0],90],["Land_HBarrier_large",[-20,-10,0],90],["Land_HBarrier_large",[-20,-5,0],90],["Land_HBarrier_large",[-20,0,0],90],["Land_HBarrier_large",[-20,5,0],90],["Land_HBarrier_large",[-20,10,0],90],["Land_HBarrier_large",[-20,15,0],90],
	["Land_HBarrier_large",[20,-15,0],90],["Land_HBarrier_large",[20,-10,0],90],["Land_HBarrier_large",[20,-5,0],90],["Land_HBarrier_large",[20,0,0],90],["Land_HBarrier_large",[20,5,0],90],["Land_HBarrier_large",[20,10,0],90],["Land_HBarrier_large",[20,15,0],90],
	// rear wall with central vehicle gate (gap at x=0)
	["Land_HBarrier_large",[-17.5,-20,0],0],["Land_HBarrier_large",[-12.5,-20,0],0],["Land_HBarrier_large",[-7.5,-20,0],0],["Land_HBarrier_large",[7.5,-20,0],0],["Land_HBarrier_large",[12.5,-20,0],0],["Land_HBarrier_large",[17.5,-20,0],0],
	// corners
	// corner closures (Land_HBarrier_corner is NOT a valid A2 OA class -> use large barriers to seal the gaps)
	["Land_HBarrier_large",[-20,17.5,0],90],["Land_HBarrier_large",[20,17.5,0],90],["Land_HBarrier_large",[-20,-17.5,0],90],["Land_HBarrier_large",[20,-17.5,0],90],
	// corner watchtowers
	["Land_fort_watchtower_EP1",[-16,16,0],0],["Land_fort_watchtower_EP1",[16,16,0],0],["Land_fort_watchtower_EP1",[-16,-16,0],0],["Land_fort_watchtower_EP1",[16,-16,0],0],
	// weapons (crewed by the builder): 2 front MG, front TOW, side MGs, central Stinger, rear gate MG
	["M2StaticMG",[-11,17,0],0],["M2StaticMG",[11,17,0],0],["TOW_TriPod_US_EP1",[0,17,0],0],
	["M2StaticMG",[-17,0,0],270],["M2StaticMG",[17,0,0],90],
	["Stinger_Pod_US_EP1",[0,2,0],0],["M2StaticMG",[0,-16,0],180],
	// weapon pits + interior
	["Land_fort_bagfence_round",[-11,17,0],0],["Land_fort_bagfence_round",[11,17,0],0],["Land_fort_bagfence_round",[0,2,0],0],
	["Land_CamoNetVar_NATO_EP1",[-9,9,0],0],["Land_CamoNetVar_NATO_EP1",[9,9,0],0],
	["USBasicAmmunitionBox_EP1",[-4,-2,0],0],["USBasicAmmunitionBox_EP1",[4,-2,0],0],["USLaunchers_EP1",[0,-5,0],0],
	// forward obstacle belt
	["Fort_RazorWire",[-15,25,0],0],["Fort_RazorWire",[-5,25,0],0],["Fort_RazorWire",[5,25,0],0],["Fort_RazorWire",[15,25,0],0],
	["Hedgehog",[-10,24,0],0],["Hedgehog",[0,24,0],0],["Hedgehog",[10,24,0],0]
]];

//--- Fortress FOB - WarPac (EAST): "belted redoubt" doctrine. An inner H-barrier KEEP
//--- (with the AA + ammo) ringed by an outer SANDBAG BELT, a MASSED front gun line
//--- (4 KORD + 2 Metis), outer corner towers, and a deep wire/hedgehog belt. Defence
//--- in depth - reads distinctly different from the NATO single-curtain fort.
missionNamespace setVariable ["WFBE_CLAUDE_FOB_EAST", [
	// --- inner keep (H-barrier square, half-extent 10) ---
	["Land_HBarrier_large",[-7.5,10,0],0],["Land_HBarrier_large",[-2.5,10,0],0],["Land_HBarrier_large",[2.5,10,0],0],["Land_HBarrier_large",[7.5,10,0],0],
	["Land_HBarrier_large",[-7.5,-10,0],0],["Land_HBarrier_large",[-2.5,-10,0],0],["Land_HBarrier_large",[2.5,-10,0],0],["Land_HBarrier_large",[7.5,-10,0],0],
	["Land_HBarrier_large",[-10,-7.5,0],90],["Land_HBarrier_large",[-10,-2.5,0],90],["Land_HBarrier_large",[-10,2.5,0],90],["Land_HBarrier_large",[-10,7.5,0],90],
	["Land_HBarrier_large",[10,-7.5,0],90],["Land_HBarrier_large",[10,-2.5,0],90],["Land_HBarrier_large",[10,2.5,0],90],["Land_HBarrier_large",[10,7.5,0],90],
	// (keep corners are already sealed where the full-span front/rear + side walls meet; no Land_HBarrier_corner - not a valid A2 OA class)
	// keep contents: massed AA + command + ammo
	["ZU23_TK_EP1",[0,0,0],0],["Igla_AA_pod_TK_EP1",[-4,3,0],0],
	["Land_CamoNetVar_EAST_EP1",[-5,-4,0],0],["Land_CamoNetVar_EAST_EP1",[5,-4,0],0],
	["TKVehicleBox_EP1",[-3,-6,0],0],["TKBasicAmmunitionBox_EP1",[3,-6,0],0],
	// --- massed front gun line (between keep and belt) ---
	["KORD_high_TK_EP1",[-12,15,0],0],["KORD_high_TK_EP1",[-4,15,0],0],["KORD_high_TK_EP1",[4,15,0],0],["KORD_high_TK_EP1",[12,15,0],0],
	["Metis_TK_EP1",[-17,14,0],345],["Metis_TK_EP1",[17,14,0],15],
	["Land_fort_bagfence_round",[-12,15,0],0],["Land_fort_bagfence_round",[-4,15,0],0],["Land_fort_bagfence_round",[4,15,0],0],["Land_fort_bagfence_round",[12,15,0],0],
	// --- outer sandbag belt (front + flanks) ---
	["Land_fort_bagfence_long",[-15,20,0],0],["Land_fort_bagfence_long",[-9,20,0],0],["Land_fort_bagfence_long",[-3,20,0],0],["Land_fort_bagfence_long",[3,20,0],0],["Land_fort_bagfence_long",[9,20,0],0],["Land_fort_bagfence_long",[15,20,0],0],
	["Land_fort_bagfence_long",[-20,-9,0],90],["Land_fort_bagfence_long",[-20,-3,0],90],["Land_fort_bagfence_long",[-20,3,0],90],["Land_fort_bagfence_long",[-20,9,0],90],["Land_fort_bagfence_long",[-20,15,0],90],
	["Land_fort_bagfence_long",[20,-9,0],90],["Land_fort_bagfence_long",[20,-3,0],90],["Land_fort_bagfence_long",[20,3,0],90],["Land_fort_bagfence_long",[20,9,0],90],["Land_fort_bagfence_long",[20,15,0],90],
	["KORD_high_TK_EP1",[-20,-13,0],270],["KORD_high_TK_EP1",[20,-13,0],90],   // flank-guard MGs on the belt
	// --- outer corner watchtowers ---
	["Land_fort_watchtower_EP1",[-19,19,0],0],["Land_fort_watchtower_EP1",[19,19,0],0],["Land_fort_watchtower_EP1",[-19,-19,0],0],["Land_fort_watchtower_EP1",[19,-19,0],0],
	// --- deep forward obstacle belt ---
	["Fort_RazorWire",[-15,25,0],0],["Fort_RazorWire",[-5,25,0],0],["Fort_RazorWire",[5,25,0],0],["Fort_RazorWire",[15,25,0],0],
	["Hedgehog",[-12,24,0],0],["Hedgehog",[-4,24,0],0],["Hedgehog",[4,24,0],0],["Hedgehog",[12,24,0],0]
]];

//==================== BUILDER ====================
//--- Spawn a WDDM template at a position+heading (origin modelToWorld, flatten Z).
//--- Crews any static weapon for the given side. A2 OA safe.
WFBE_CLAUDE_FNC_BuildTemplate = {
	private ["_pos","_dir","_tpl","_side","_origin","_o","_world","_cls","_team","_g"];
	_pos = _this select 0; _dir = _this select 1; _tpl = _this select 2; _side = _this select 3;
	_origin = (createGroup sideLogic) createUnit ["Logic", _pos, [], 0, "NONE"];
	_origin setDir _dir;
	_team = grpNull;
	if (_side in [west,east]) then { _team = createGroup _side };
	{
		_cls = _x select 0;
		_world = _origin modelToWorld (_x select 1); _world set [2,0];
		_o = createVehicle [_cls, _world, [], 0, "NONE"];
		_o setDir (_dir - (_x select 2)); _o setPos _world;
		//--- crew static weapons so they actually fight (left destroyable); harden walls/obstacles only
		if (_side in [west,east] && {_cls in ["M2StaticMG","KORD_high_TK_EP1","TOW_TriPod_US_EP1","Metis_TK_EP1","Stinger_Pod_US_EP1","Igla_AA_pod_TK_EP1","ZU23_TK_EP1"]}) then {
			private "_u";
			_u = [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side], _team, _world, _side] call WFBE_CO_FNC_CreateUnit;
			if (!isNull _u) then { _u assignAsGunner _o; _u moveInGunner _o; _u setVariable ["WFBE_IsBaseDefenderAI", true, true] };
		} else {
			_o addEventHandler ["handleDamage", {false}];
		};
	} forEach _tpl;
	deleteVehicle _origin;
};

//==================== PLACEMENT ====================
//--- Build a fortress FOB over each side's starting location, facing the map centre,
//--- and lay the border wall in segments across the central valley line.
[] spawn {
	waitUntil {!isNil "townInitServer" && {townInitServer}};
	sleep 3;
	private ["_centre","_sides","_logic","_pos","_dir","_tpl"];
	_centre = [4096,4096,0];

	//--- FOBs at the two side starting positions, oriented toward map centre
	{
		_logic = (_x select 0) call WFBE_CO_FNC_GetSideLogic;
		if (!isNil "_logic" && {!isNull _logic}) then {
			private ["_startObj","_dx","_dy"];
			_startObj = _logic getVariable ["wfbe_startpos", _logic];
			_pos = getPos _startObj;
			_dx = (_centre select 0) - (_pos select 0); _dy = (_centre select 1) - (_pos select 1);
			_dir = _dx atan2 _dy;   //--- face the map centre (A2-safe heading)
			[_pos, _dir, missionNamespace getVariable (_x select 1), (_x select 0)] call WFBE_CLAUDE_FNC_BuildTemplate;
		};
	} forEach [[west, "WFBE_CLAUDE_FOB_WEST"], [east, "WFBE_CLAUDE_FOB_EAST"]];

	//--- border wall: a belt of E-W segments across the centre of the valley so the two
	//--- bases must breach it (dir 0 = runs along world X). Neutral, unmanned.
	_tpl = missionNamespace getVariable "WFBE_CLAUDE_WALL_BORDER";
	{ [[(_centre select 0) + _x, _centre select 1, 0], 0, _tpl, sideLogic] call WFBE_CLAUDE_FNC_BuildTemplate } forEach [-90,-45,0,45,90];

	["INITIALIZATION", "Claude_Fortifications.sqf: WDDM FOBs + border wall built (2 fortresses + 5 wall segments)."] call WFBE_CO_FNC_LogContent;
};
