Private ["_createSide","_lock","_position","_side","_type","_vehicle"];
_vehicle = _this select 0;
//--- b67 faction DECALS: authoritative side id passed by Common_CreateVehicle.sqf (the create path
//--- knows the buying side). REQUIRED because a freshly createVehicle'd hull is still CREWLESS, so
//--- `side _vehicle` here is CIVILIAN -> a self-derived side yields CIV and any per-side block no-ops.
//--- -1 when an older caller passes only [_vehicle] (none currently; CreateVehicle is the sole caller).
_createSide = if (count _this > 1) then {_this select 1} else {-1};
_type = typeof _vehicle;

switch (_type) do {
	case "M2A2_EP1": {
		if (IS_chernarus_map_dependent) then { // Woodland came is required
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\a3_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\ultralp_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [4,""Textures\base_co.paa""]";
		};
		
	};

	case "AAV": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\aav_ext_coD.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\aav_ext2_coD.paa""]";
		};
		
	};

	case "LAV25": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\lavbody_coD.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\lavbody2_coD.paa""]";
		};
		
	};

	case "BMP3": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\bmp3_body_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\bmp3_body2_co.paa""]";
		};
		 
	};


	case "M2A3_EP1": {
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\a3_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\ultralp_co.paa""]";
		};
		
	};

	case "M6_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\a3_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\ultralp_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\base_co.paa""]";
		};
		
	};

	case "BTR90": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\btr_body_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\btr_body2_co.paa""]";
		};
		 
	};

	case "2S6M_Tunguska": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\tunguska_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\tunguska_turret_co.paa""]";
		};
		
	};

	case "M1128_MGS_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\stryker_mgs_1.paa""]";
		};
		
	};

	case "M1129_MC_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "M1135_ATGMV_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "M1126_ICV_mk19_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "M1126_ICV_M2_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "HMMWV_M1151_M2_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\hmmwv_gpk_tower.paa""]";
		};
	};

	case "HMMWV_M998A2_SOV_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
		};
	};

	case "HMMWV_M1035_DES_EP1": {
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\hmmwv_up_1.paa""]";
		};
	};

	case "HMMWV_M998_crows_MK19_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
		};
	};

	case "HMMWV_M998_crows_M2_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
		};
	};

	case "M113Ambul_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\m113a3_01.paa""]";
		};
	};

	case "M113_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\m113a3_01.paa""]";
		};
	};

	case "Mi24_D_TK_EP1":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""\ca\air2\mi35\data\mi24p_001_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""\ca\air2\mi35\data\mi24p_002_co.paa""]";
		};
	
	};

	case "Mi24_V":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""\Ca\Air_E\Data\mi35_001_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""\Ca\Air_E\Data\mi35_002_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""\Ca\Air_E\Data\mi35_mlod_IND_co.paa""]";
		};
 
	};

	case "Mi24_P":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""\Ca\Air_E\Data\mi35_001_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""\Ca\Air_E\Data\mi35_002_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""\Ca\Air_E\Data\mi35_mlod_IND_co.paa""]";
		};

	};

	case "BTR60_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\btr60_body_cw.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\btr60_details_cw.paa""]";
		};

	};
	case "T34_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\t34_body01_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\t34_body02_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\t34_turret_co.paa""]";
		};
	
	};

	case "T90":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\t901_co_des.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\t902_co_des.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\t903_co_des.paa""]";
		};
	};

	case "BVP1_TK_ACR": {
	    if (IS_chernarus_map_dependent) then {
	        _vehicle setVehicleInit "this setObjectTexture [0,""Textures\trup_ext0_co.paa""]";
	    };
	};

	//--- Salvage helicopters: amber tint to distinguish them from standard transport.
	//--- Note: A2 OA helicopters often ignore setObjectTexture on body selections;
	//--- apply best-effort and verify in-engine — selection 0 is the fuselage on most variants.
	//--- NEEDS-IN-ENGINE-VERIFY: confirm the tint is visible on Mi17_medevac_CDF.
	//--- Implementation note: we do NOT use setVehicleInit here because Common_CreateVehicle.sqf
	//--- calls setVehicleInit again (for Init_Unit.sqf) AFTER this function returns, which would
	//--- overwrite the texture command before processInitCommands sees it — killing JIP visibility.
	//--- Instead we store the texture command string on the vehicle; Common_CreateVehicle reads it
	//--- and appends it to the Init_Unit setVehicleInit so both run in one processInitCommands call.
	// Marty: WEST salvage heli (UH1H_EP1) removed - invalid class on live box; re-add with validated airframe (claude-inbox#2 item 1).
	case "Mi17_medevac_CDF": {
		//--- APPEND (was overwrite) so a team-marking string set by Common_AddVehicleMarking.sqf survives.
		Private ["_salvageTex","_pendingSalv"];
		_salvageTex  = "this setObjectTexture [0,'#(argb,8,8,3)color(0.8,0.5,0.0,0.5,ca)']";
		_pendingSalv = _vehicle getVariable ["wfbe_pending_texture", ""];
		if (_pendingSalv != "") then {_pendingSalv = _pendingSalv + "; " + _salvageTex} else {_pendingSalv = _salvageTex};
		_vehicle setVariable ["wfbe_pending_texture", _pendingSalv];
	};


	};

//--- ============================================================================
//--- Miksuu vehicle SKINS (experital). Side-gated body retextures applied as an APPEND to
//--- wfbe_pending_texture (same JIP-safe path as the salvage tint above). _side is resolved from
//--- the authoritative _createSide passed by Common_CreateVehicle (see the side-resolution block
//--- below); the old wfbe_side_id/engine-side read was broken because markings are default-off and
//--- the hull is crewless here. Gate: WFBE_C_VEHICLE_TINTS (decoupled from WFBE_C_VEHICLE_MARKINGS, which gates the #lightpoint markings in Common_AddVehicleMarking.sqf).
//--- NOTE: like the salvage tint, this only reaches clients on the GLOBAL non-defender path
//--- (the path Common_CreateVehicle uses for player/commander vehicles).
//--- ============================================================================
if ((missionNamespace getVariable ["WFBE_C_VEHICLE_TINTS", 0]) > 0) then {
	Private ["_skinCmd","_pendingSkin"];
	//--- B67 side resolution (authoritative; now MIRRORS the DECALS block below). Prefer the side
	//--- PASSED by Common_CreateVehicle (_createSide) — the create path knows the buying side. The old
	//--- B66 path read wfbe_side_id then fell back to (side _vehicle), but BOTH are broken at this point:
	//--- wfbe_side_id is ONLY stamped by Common_AddVehicleMarking.sqf, which exits early when
	//--- WFBE_C_VEHICLE_MARKINGS != 1 (default 0) so it is usually unset; and the hull is still CREWLESS
	//--- here, so (side _vehicle) resolves to CIVILIAN -> WFBE_C_CIV_ID -> no faction case matches -> the
	//--- tints silently no-op. So: _createSide first, then the marking-stamped id, then engine side as a
	//--- last-resort guard only (it can only resolve to a real faction once the hull is crewed).
	_side    = _createSide;
	if (_side < 0) then { _side = _vehicle getVariable ["wfbe_side_id", -1]; };
	if (_side < 0) then { _side = (side _vehicle) Call WFBE_CO_FNC_GetSideID; };
	_skinCmd = "";

	switch (_side) do {
		//--- WEST: matte-black motor-pool finish. Zero art (procedural colour) - ships now.
		//--- NEEDS-IN-ENGINE-VERIFY: body selections vary per class; 0+1 cover most A2 hulls.
		case WFBE_C_WEST_ID: {
			_skinCmd = "this setObjectTexture [0,'#(argb,8,8,3)color(0.04,0.04,0.05,1,ca)']; this setObjectTexture [1,'#(argb,8,8,3)color(0.04,0.04,0.05,1,ca)']";
		};
		//--- EAST: dark olive/forest procedural tint. Zero art (procedural colour) - ships now.
		//--- Mirrors the WEST block: same selection indices (0+1), known-safe on most A2 hulls.
		//--- NEEDS-IN-ENGINE-VERIFY: body selections vary per class; 0+1 cover most A2 hulls.
		case WFBE_C_EAST_ID: {
			_skinCmd = "this setObjectTexture [0,'#(argb,8,8,3)color(0.20,0.24,0.16,1,ca)']; this setObjectTexture [1,'#(argb,8,8,3)color(0.20,0.24,0.16,1,ca)']";
		};
		//--- GUER/resistance: desert tan/brown procedural tint. Zero art (procedural colour) - ships now.
		//--- Mirrors the WEST block: same selection indices (0+1), known-safe on most A2 hulls.
		//--- NEEDS-IN-ENGINE-VERIFY: body selections vary per class; 0+1 cover most A2 hulls.
		case WFBE_C_GUER_ID: {
			_skinCmd = "this setObjectTexture [0,'#(argb,8,8,3)color(0.46,0.40,0.28,1,ca)']; this setObjectTexture [1,'#(argb,8,8,3)color(0.46,0.40,0.28,1,ca)']";
		};
	};

	//--- STUB: clan livery E on the EAST MHQ / flagship class (Chernarus RU MHQ = BTR90_HQ).
	//--- fill Textures\mks_clan_e_co.paa from image-gen.
	//if (_type == "BTR90_HQ") then { _skinCmd = "this setObjectTexture [0,'Textures\mks_clan_e_co.paa']"; }; //--- fill from image-gen

	//--- STUB: medic red-cross decal on the TK ambulance (existing case above textures its body).
	//--- fill Textures\mks_medic_cross_ca.paa from image-gen.
	//if (_type == "M113Ambul_TK_EP1") then { _skinCmd = _skinCmd + "; this setObjectTexture [1,'Textures\mks_medic_cross_ca.paa']"; }; //--- fill from image-gen

	//--- TODO v2: kill-tally livery (needs kill-attribution design).

	if (_skinCmd != "") then {
		_pendingSkin = _vehicle getVariable ["wfbe_pending_texture", ""];
		if (_pendingSkin != "") then {_pendingSkin = _pendingSkin + "; " + _skinCmd} else {_pendingSkin = _skinCmd};
		_vehicle setVariable ["wfbe_pending_texture", _pendingSkin];
	};
};

//--- ============================================================================
//--- FACTION VEHICLE DECALS (WFBE_C_VEHICLE_DECALS, DEFAULT 0 / opt-in, decoupled from
//--- WFBE_C_VEHICLE_TINTS + WFBE_C_VEHICLE_MARKINGS). Reuses STOCK A2/OA flag .paa art
//--- (no new textures) applied to ONE secondary texture selection via setObjectTexture.
//--- Stock paths corroborated in this build's faction Root files:
//---   WEST/USMC flag '\Ca\Data\flag_usa_co.paa'      (Root_USMC.sqf:11, vanilla A2)
//---   EAST/RU   flag '\Ca\Data\flag_rus_co.paa'      (Root_RU.sqf:11,  vanilla A2)
//---   GUER      flag '\ca\ca_e\data\flag_tkg_co.paa' (Root_TKGUE.sqf:11 / Root_PMC.sqf:11, OA)
//--- Absolute paths (NOT the usflag/ruflag .hpp macros, which are unavailable in .sqf and
//--- resolve to flag_us_co under COMBINEDOPS, mismatching the Chernarus USMC faction).
//--- DESIGN: a decal REPLACES a texture SELECTION, so it can only ride a selection the body
//--- model actually exposes. To stay LEAST-DISRUPTIVE we apply the flag ONLY to a per-class
//--- panel index that the class' own texture case above does NOT already paint with a real
//--- body skin, and we apply it to ONE class per side (the most prominent commandable ground
//--- vehicle on Chernarus). Every other class is INTENTIONALLY left undecaled (no safe panel
//--- without overpainting the hull / clobbering its body retexture) and documented below.
//--- JIP-safe: APPEND to wfbe_pending_texture (NEVER overwrite); Common_CreateVehicle.sqf
//--- folds the accumulated string into the single Init_Unit setVehicleInit + processInitCommands.
//--- ============================================================================
if ((missionNamespace getVariable ["WFBE_C_VEHICLE_DECALS", 0]) > 0) then {
	Private ["_decalSide","_flagPaa","_decalSel","_decalCmd","_pendingDecal"];
	//--- Side resolution (authoritative): prefer the side PASSED by Common_CreateVehicle (_createSide),
	//--- then the marking-stamped id, then (last resort) the engine side. The engine-side fallback
	//--- resolves to CIVILIAN on a crewless freshly-created hull and will NOT match a faction case - it
	//--- is only a guard, never the real source. A LOCAL var so we never clobber _side for later code.
	//--- NOTE: the TINTS block above now uses this SAME _createSide-first resolution (B67 follow-up).
	_decalSide = _createSide;
	if (_decalSide < 0) then { _decalSide = _vehicle getVariable ["wfbe_side_id", -1]; };
	if (_decalSide < 0) then { _decalSide = (side _vehicle) Call WFBE_CO_FNC_GetSideID; };

	//--- Resolve the per-side stock flag .paa (string). Empty for CIV/UNKNOWN/no-match -> no-op.
	_flagPaa = "";
	switch (_decalSide) do {
		case WFBE_C_WEST_ID: { _flagPaa = "\Ca\Data\flag_usa_co.paa"; };       //--- USMC (Chernarus WEST)
		case WFBE_C_EAST_ID: { _flagPaa = "\Ca\Data\flag_rus_co.paa"; };       //--- RU (Chernarus EAST)
		case WFBE_C_GUER_ID: { _flagPaa = "\ca\ca_e\data\flag_tkg_co.paa"; };  //--- GUER (Takistani-guerrilla proxy)
	};

	//--- Per-class SAFE secondary panel index (-1 == NO safe slot => skip, document only).
	//--- Indices chosen to AVOID the body skins the texture cases above already set, so the
	//--- decal lands on a spare/secondary panel rather than overpainting the hull.
	//---   M2A3_EP1 (WEST heavy/MHQ): case paints 0,1,2 -> selection 3 is the free panel.  NEEDS-IN-ENGINE-VERIFY.
	//---   T90 (EAST heavy/MHQ):      case paints 0,1,2 -> selection 3 is the free panel.  NEEDS-IN-ENGINE-VERIFY.
	//---   BTR60_TK_EP1 (GUER-usable APC): case paints 0,1 -> selection 2 is the free panel. NEEDS-IN-ENGINE-VERIFY.
	//--- HONEST NO-SLOT classes (left undecaled on purpose): M2A2_EP1 (0-4 all painted),
	//---   HMMWV_M1151_M2_DES_EP1 (0-3 all painted), and any class whose only selections are 0/1
	//---   (AAV/LAV25/BMP3/BTR90/Strykers/most HMMWVs) - those are the hull; a flag there uglifies
	//---   the whole body, so we do NOT decal them. Air (Mi24_*/Mi17) excluded - see heli note below.
	_decalSel = -1;
	switch (_type) do {
		case "M2A3_EP1":     { if (_decalSide == WFBE_C_WEST_ID) then { _decalSel = 3; }; };
		case "T90":          { if (_decalSide == WFBE_C_EAST_ID) then { _decalSel = 3; }; };
		case "BTR60_TK_EP1": { if (_decalSide == WFBE_C_GUER_ID) then { _decalSel = 2; }; };
	};

	//--- Only append when BOTH a flag and a safe panel resolved. A2-OA quoting: this command
	//--- STRING is built by runtime concatenation and APPENDED to wfbe_pending_texture, which
	//--- Common_CreateVehicle.sqf folds into ONE setVehicleInit string whose base path is itself
	//--- SINGLE-quoted ('Common\Init\Init_Unit.sqf'). So the inner .paa literal is wrapped in
	//--- SINGLE quotes - EXACTLY like the proven salvage tint (line 240) and the side TINTS
	//--- (lines 270/276/282) on this same accumulator. (Do NOT use the doubled-double-quote ""
	//--- idiom here; that is only for the source-literal setVehicleInit "..." cases at lines 8-225,
	//--- not for a string assembled by + and re-injected.) str _decalSel yields a bare integer.
	if (_flagPaa != "" && {_decalSel >= 0}) then {
		_decalCmd     = "this setObjectTexture [" + (str _decalSel) + ",'" + _flagPaa + "']";
		_pendingDecal = _vehicle getVariable ["wfbe_pending_texture", ""];
		if (_pendingDecal != "") then {_pendingDecal = _pendingDecal + "; " + _decalCmd} else {_pendingDecal = _decalCmd};
		_vehicle setVariable ["wfbe_pending_texture", _pendingDecal];
	};
	//--- HELI FALLBACK / best-effort: A2-OA helicopters frequently IGNORE setObjectTexture on
	//--- body selections, so NO air class is given a decal slot above (all _decalSel stay -1 ->
	//--- no-op). If a future air decal is wanted, add the class to the switch with selection 0
	//--- (fuselage on most variants) and tag it NEEDS-IN-ENGINE-VERIFY; expect it may not render.
};

processinitcommands;
_vehicle