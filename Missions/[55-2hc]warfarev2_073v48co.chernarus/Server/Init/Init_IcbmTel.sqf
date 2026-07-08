//--- Init_IcbmTel.sqf — LAND ICBM TEL (Transporter-Erector-Launcher) with counterplay + selectable munitions.
//--- cmdcon41 SCUD PACKAGE feature 3 (Ray 2026-07-02). Launched once from Init_Server.sqf, guarded by
//--- WFBE_C_ICBM_TEL. Server-authoritative throughout (isServer). A2-OA-1.64 safe: no isEqualType/isEqualTo,
//--- ==/!= only on non-Boolean operands (if/else for bools), plain group getVariable + isNil, setPosASL for
//--- sea-safe (N/A here — land), exact-case mode/action strings, no A3 string ops.
//---
//--- WHAT IT DOES
//---   • On a side completing the ICBM upgrade (WFBE_UP_ICBM), spawn ONE MAZ_543_SCUD_TK_EP1 near that side's
//---     HQ, EMPTY + LOCKED (empty vehicle => side CIVILIAN: no red blip, AI ignores it; teammates never see it
//---     hostile — Ray's explicit side-safety concern). It IS destroyable (allowDamage true) = the counterplay.
//---   • A FRIENDLY-ONLY map marker (mil_triangle, side colour, "ICBM TEL") via a side-scoped HandleSpecial send.
//---   • The commander's ICBM fire is INTERCEPTED (GUI_Menu_Tactical.sqf) and routed here (WFBE_SE_FNC_IcbmTelFire):
//---       - munition "NUKE"       : the classic ICBM. 5-min countdown at the TEL (erect+smoke), owning side warned,
//---                                 ENEMY side gets a FUZZY intel ping (offset by PING_FUZZ). At T-0 the ORIGINAL
//---                                 warhead fires (we call the existing NukeIncoming path — NOT reimplemented).
//---                                 If the TEL is DESTROYED before T-0: strike CANCELED (funds NOT refunded), big
//---                                 local secondary at the TEL, BOTH sides announced. UNLIMITED range.
//---       - "SATURATION"          : the ScudStrike MIRV barrage at the target (cheaper). Fires PROMPTLY (erect+FX),
//---                                 NO countdown; instead a GLOBAL "SCUD LAUNCH DETECTED" marker at the TEL for 60s
//---                                 (everyone: both sides + GUER). Range-limited to WFBE_C_ICBM_TEL_RANGE.
//---       - "RECON"               : a high airburst over the target reveals ENEMY within RECON_R for RECON_SECS —
//---                                 an AI reveal pass for the firing side + side-scoped map dots for its players.
//---                                 Fires PROMPTLY, same 60s global launch marker, range-limited.
//---     If the TEL is DEAD at fire time (flag on): the call is REFUSED (side message), a replacement TEL respawns
//---     after WFBE_C_ICBM_TEL_RESPAWN. SHARED cooldown across ALL munitions (WFBE_C_ICBM_TEL_COOLDOWN).
//---   • AICOM SYMMETRY: an AI side that researches ICBM gets a TEL too (same spawn hook). NOTE: in THIS build the
//---     AI commander never FIRES ICBM (the ICBM fire path is 100% the human commander's Tactical menu — there is
//---     no AI ICBM launch code anywhere), so there is no AI fire to gate. The TEL is still spawned + destroyable
//---     for the AI side so the mechanic is symmetric if an AI fire path is ever added.

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_ICBM_TEL", 1]) != 1) exitWith {
	["INFORMATION", "Init_IcbmTel.sqf : WFBE_C_ICBM_TEL=0 — land ICBM TEL feature OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Init_IcbmTel.sqf : land ICBM TEL feature ENABLED."] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- HELPER: erect + backblast smoke on a TEL launcher (shared feature-1 idiom: the VERIFIED in-tree
//--- action "scudLaunch" raises the MAZ_543 launcher — Init_NavalHVT.sqf:348 proves it present; SmokeShellWhite
//--- is confirmed in-tree). No config animate with a guessed name (would no-op/error); no Land_Fire (absent).
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelTheatrics = {
	private ["_tel"];
	_tel = _this select 0;
	if (isNull _tel) exitWith {};
	_tel action ["scudLaunch", _tel];
	private ["_sp","_i","_ang","_r"];
	_sp = getPosASL _tel;
	for "_i" from 0 to 3 do {
		_ang = random 360; _r = random 4;
		(createVehicle ["SmokeShellWhite", [(_sp select 0) + _r * sin _ang, (_sp select 1) + _r * cos _ang, (_sp select 2)], [], 0, "NONE"]);
	};
};

//------------------------------------------------------------------------------------
//--- SPAWN (or respawn) a side's TEL. side -> object (also stored on missionNamespace, broadcast).
//------------------------------------------------------------------------------------
WFBE_SE_FNC_SpawnIcbmTel = {
	private ["_side","_sideText","_hq","_hqPos","_pos","_tel","_key","_existing"];
	_side = _this select 0;
	if !(_side in [west, east, resistance]) exitWith {
		["WARNING", Format ["Init_IcbmTel.sqf : SpawnIcbmTel called with invalid side %1 — no TEL registered.", _side]] Call WFBE_CO_FNC_LogContent;
		objNull
	};
	_sideText = str _side;
	_key = Format ["WFBE_ICBM_TEL_%1", _sideText];

	//--- Don't double-spawn a live TEL.
	_existing = missionNamespace getVariable [_key, objNull];
	if (!isNull _existing && {alive _existing}) exitWith {
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL already alive — skip respawn.", _sideText]] Call WFBE_CO_FNC_LogContent;
		_existing
	};

	_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
	if (isNull _hq) exitWith {
		["WARNING", Format ["Init_IcbmTel.sqf : [%1] no HQ — cannot place TEL.", _sideText]] Call WFBE_CO_FNC_LogContent;
		objNull
	};
	_hqPos = getPos _hq;

	//--- STRUCT_SPACING-aware empty spot off the HQ (WFBE_CO_FNC_GetEmptyPosition uses isFlatEmpty, same helper the
	//--- MHQ/base builder uses). Radius ~60m so it sits at the base edge, not on the flag.
	_pos = [_hqPos, 60] Call WFBE_CO_FNC_GetEmptyPosition;
	if (typeName _pos != "ARRAY" || {count _pos < 2}) then {_pos = [(_hqPos select 0) + 45, (_hqPos select 1) + 45, 0]};

	//--- EMPTY + LOCKED: an empty vehicle is side CIVILIAN (no red blip, AI ignores it). Do NOT crew it.
	_tel = createVehicle ["MAZ_543_SCUD_TK_EP1", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
	if (isNull _tel) exitWith {
		diag_log (Format ["ICBMTEL-SPAWNFAIL: [%1] MAZ_543_SCUD_TK_EP1 failed to createVehicle at %2.", _sideText, _pos]);
		["WARNING", Format ["Init_IcbmTel.sqf : [%1] TEL createVehicle FAILED at %2.", _sideText, _pos]] Call WFBE_CO_FNC_LogContent;
		objNull
	};
	_tel setPos [_pos select 0, _pos select 1, 0];
	_tel setVehicleLock "LOCKED";
	_tel setDir (random 360);
	_tel allowDamage true;   //--- destroyable = the counterplay (destroy-to-cancel an in-flight NUKE; else it just respawns).
	_tel setVariable ["wfbe_icbm_tel_side", _side, true];
	_tel setVariable ["wfbe_is_icbm_tel", true, true];

	//--- Erect it (thematic; also makes it a visible landmark to hunt). Reuse the shared theatrics helper.
	[_tel] Call WFBE_SE_FNC_IcbmTelTheatrics;

	missionNamespace setVariable [_key, _tel];
	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL registered in missionNamespace (%2) — isNull=%3.", _sideText, _key, isNull _tel]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["ICBMTEL|v1|REGISTER|%1|key=%2|isNull=%3", _sideText, _key, isNull _tel]);
	//--- Clear any stale countdown latch on (re)spawn.
	missionNamespace setVariable [Format ["WFBE_ICBM_TEL_CD_%1", _sideText], -1];

	//--- KILLED EH: on death, either CANCEL an in-flight NUKE (big secondary + both-sides announce, no refund) or
	//--- just schedule a respawn. Runs server-side (the TEL is server-local; it was createVehicle'd here).
	_tel addEventHandler ["Killed", {
		private ["_dead","_dSide","_dSideText","_cdEnd","_secHE","_i"];
		_dead = _this select 0;
		_dSide = _dead getVariable ["wfbe_icbm_tel_side", sideUnknown];
		if !(_dSide in [west, east, resistance]) exitWith {};
		_dSideText = str _dSide;
		//--- Clear the stored ref if it points at this corpse.
		if ((missionNamespace getVariable [Format ["WFBE_ICBM_TEL_%1", _dSideText], objNull]) == _dead) then {
			missionNamespace setVariable [Format ["WFBE_ICBM_TEL_%1", _dSideText], objNull];
		};
		//--- Was a NUKE counting down? (only NUKE arms a countdown latch.) If so -> CANCEL.
		_cdEnd = missionNamespace getVariable [Format ["WFBE_ICBM_TEL_CD_%1", _dSideText], -1];
		if (_cdEnd > time) then {
			missionNamespace setVariable [Format ["WFBE_ICBM_TEL_CD_%1", _dSideText], -1];
			//--- big LOCAL secondary at the TEL: 3x the SAME large HE the ScudStrike uses (Sh_125_HE, in-tree).
			_secHE = missionNamespace getVariable ["WFBE_C_SCUD_WARHEAD_HE", "Sh_125_HE"];
			for "_i" from 0 to 2 do { _secHE createVehicle (getPosATL _dead) };
			//--- announce to BOTH sides (side-scoped systemChat via the icbm-tel-msg HandleSpecial case). No kbTell/CfgRadio.
			[_dSide, "HandleSpecial", ["icbm-tel-msg", "Your ICBM TEL was DESTROYED before launch! The strike is aborted."]] Call WFBE_CO_FNC_SendToClients;
			{ [_x, "HandleSpecial", ["icbm-tel-msg", "Enemy ICBM TEL destroyed - their strike was aborted!"]] Call WFBE_CO_FNC_SendToClients } forEach (WFBE_PRESENTSIDES - [_dSide]);
			diag_log (Format ["ICBMTEL|v1|CANCEL-ON-DESTROY|%1|countdown aborted, no refund.", _dSideText]);
		};
		//--- schedule respawn.
		[_dSide] spawn {
			private ["_rs","_delay"];
			_rs = _this select 0;
			_delay = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RESPAWN", 600];
			sleep _delay;
			if (!WFBE_GameOver) then { [_rs] Call WFBE_SE_FNC_SpawnIcbmTel };
		};
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL destroyed — respawn in %2s.", _dSideText, (missionNamespace getVariable ["WFBE_C_ICBM_TEL_RESPAWN", 600])]] Call WFBE_CO_FNC_LogContent;
	}];

	//--- FRIENDLY-ONLY map marker: side-scoped send -> Client_HandlePVF delivers only to owning-side clients, which
	//--- createMarkerLocal a mil_triangle in side colour labelled "ICBM TEL".
	[_side, "HandleSpecial", ["icbm-tel-marker", _tel, str _side]] Call WFBE_CO_FNC_SendToClients;

	["INITIALIZATION", Format ["Init_IcbmTel.sqf : [%1] TEL spawned (empty+locked, destroyable) at %2.", _sideText, _pos]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["ICBMTEL|v1|SPAWN|%1|pos=%2", _sideText, [round (_pos select 0), round (_pos select 1)]]);
	_tel
};

//------------------------------------------------------------------------------------
//--- cmdcon42-j (Ray 2026-07-02) PRODUCIBLE SCUD (Takistan): bought SCUDs are side launch PLATFORMS. Registered
//--- server-side into a side-keyed missionNamespace array (WFBE_TK_SCUD_PLATFORMS_<side>) at purchase (client sends
//--- "tk-scud-register"). Platforms are pruned lazily (dead/deleted refs dropped) wherever the array is read. A bought
//--- SCUD is a CONVENTIONAL platform only — it can NEVER nuke (NUKE stays research-TEL-only, gated in the fire path).
//------------------------------------------------------------------------------------

//--- Return the compacted (alive-only) bought-SCUD platform list for a side; also writes the compacted list back.
WFBE_SE_FNC_TkScudPlatforms = {
	private ["_side","_key","_arr","_live","_x"];
	_side = _this select 0;
	if !(_side in [west, east, resistance]) exitWith {[]};
	_key = Format ["WFBE_TK_SCUD_PLATFORMS_%1", str _side];
	_arr = missionNamespace getVariable [_key, []];
	if (typeName _arr != "ARRAY") then {_arr = []};
	_live = [];
	{ if (!isNull _x && {alive _x}) then {_live set [count _live, _x]} } forEach _arr;
	//--- write back only if it shrank (avoid needless broadcasts).
	if (count _live != count _arr) then { missionNamespace setVariable [_key, _live] };
	_live
};

//--- Register a freshly-bought SCUD as a side platform. Enforces the per-side live cap (WFBE_C_TK_SCUD_HF_MAX):
//--- at/over cap the vehicle is DELETED and the buyer refunded, and the caller is told (refused-at-cap message).
//--- Returns true if registered, false if refused. Server-authoritative.
WFBE_SE_FNC_TkScudRegister = {
	private ["_veh","_side","_team","_paid","_key","_live","_max","_arr","_refund"];
	_veh  = _this select 0;
	_side = _this select 1;
	_team = if (count _this > 2) then {_this select 2} else {grpNull};
	_paid = if (count _this > 3) then {_this select 3} else {-1};   //--- actual price paid (for an exact over-cap refund); <0 => fall back to the flag cost.
	if (isNull _veh) exitWith {false};
	if !(_side in [west, east, resistance]) exitWith {false};
	if ((missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) <= 0) exitWith {false};
	if (worldName != "Takistan" && {(missionNamespace getVariable ["WFBE_C_SCUD_DRIVABLE_ALLMAPS", 1]) <= 0}) exitWith {false};
	_key = Format ["WFBE_TK_SCUD_PLATFORMS_%1", str _side];
	_live = [_side] Call WFBE_SE_FNC_TkScudPlatforms;   //--- compacted current list.
	//--- already registered? (idempotent — a double send must not double-count).
	if (_veh in _live) exitWith {true};
	_max = missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_MAX", 2];
	if (count _live >= _max) exitWith {
		//--- refuse: destroy the surplus purchase + refund the buying team the EXACT amount paid (flag cost fallback), tell the side.
		_refund = if (_paid >= 0) then {_paid} else {missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_COST", 28000]};
		if (!isNull _team) then { [_team, _refund] Call WFBE_CO_FNC_ChangeTeamFunds };
		deleteVehicle _veh;
		[_side, "HandleSpecial", ["icbm-tel-msg", Format ["SCUD refused: your side already fields %1 SCUD launchers (max %2). Refunded.", count _live, _max]]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] bought-SCUD REFUSED at cap (%2/%3) - deleted + refunded.", str _side, count _live, _max]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|SCUDBUY-REFUSE-CAP|%1|live=%2|max=%3", str _side, count _live, _max]);
		false
	};
	//--- register: tag the hull (side + platform marker + no-respawn), append to the side array, broadcast.
	_veh setVariable ["wfbe_tk_scud_side", _side, true];
	_veh setVariable ["wfbe_is_tk_scud", true, true];
	_arr = _live + [_veh];
	missionNamespace setVariable [_key, _arr];
	//--- KILLED EH: drop from the registry on death. NO respawn (it's a purchase). Server-side (hull is a shared object).
	_veh addEventHandler ["Killed", {
		private ["_dead","_dSide","_dKey","_dArr","_dLive","_x"];
		_dead = _this select 0;
		_dSide = _dead getVariable ["wfbe_tk_scud_side", sideUnknown];
		if !(_dSide in [west, east, resistance]) exitWith {};
		_dKey = Format ["WFBE_TK_SCUD_PLATFORMS_%1", str _dSide];
		_dArr = missionNamespace getVariable [_dKey, []];
		if (typeName _dArr != "ARRAY") then {_dArr = []};
		_dLive = [];
		{ if (!isNull _x && {alive _x} && {_x != _dead}) then {_dLive set [count _dLive, _x]} } forEach _dArr;
		missionNamespace setVariable [_dKey, _dLive];
		diag_log (Format ["ICBMTEL|v1|SCUD-DESTROYED|%1|remaining=%2 (no respawn)", str _dSide, count _dLive]);
	}];
	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] bought-SCUD REGISTERED as platform (%2/%3 live).", str _side, count _arr, _max]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["ICBMTEL|v1|SCUDBUY|%1|live=%2|max=%3", str _side, count _arr, _max]);
	true
};

//--- Return ALL alive conventional launch platforms for a side = the research TEL (if alive) + every alive bought SCUD.
//--- Used by the fire path (nearest-to-target selection) and the menu-enable gate (side has ANY platform).
WFBE_SE_FNC_TkScudAllPlatforms = {
	private ["_side","_out","_tel"];
	_side = _this select 0;
	if !(_side in [west, east, resistance]) exitWith {[]};
	_out = [];
	_tel = missionNamespace getVariable [Format ["WFBE_ICBM_TEL_%1", str _side], objNull];
	if (!isNull _tel && {alive _tel}) then {_out set [count _out, _tel]};
	{ _out set [count _out, _x] } forEach ([_side] Call WFBE_SE_FNC_TkScudPlatforms);
	_out
};

//--- Pick the alive platform NEAREST to a target position (research TEL or bought SCUD). objNull if none.
WFBE_SE_FNC_TkScudNearestPlatform = {
	private ["_side","_tgtPos","_plats","_best","_bestD","_ref","_x","_d"];
	_side   = _this select 0;
	_tgtPos = _this select 1;
	_plats  = [_side] Call WFBE_SE_FNC_TkScudAllPlatforms;
	_best  = objNull;
	_bestD = 999999999;
	_ref = [_tgtPos select 0, _tgtPos select 1, 0];
	{
		_d = (getPosATL _x) distance _ref;
		if (_d < _bestD) then {_bestD = _d; _best = _x};
	} forEach _plats;
	_best
};

//------------------------------------------------------------------------------------
//--- FIRE: routed here from GUI_Menu_Tactical (via Server_HandleSpecial case "icbm-tel-fire").
//--- Payload: [_side, _target(pos/obj), _munition(STRING), _playerTeam, _fee(SCALAR), _platformHint(OBJECT|objNull), _aiTreasury(SIDE|sideUnknown)].
//--- Server re-validates TEL alive + cooldown + range (non-NUKE) + funds, then executes.
//--- cmdcon42-n (Ray 2026-07-02): when the 7th param is a real side the fire is an AI COMMANDER launch — funds are read/charged
//--- against that side's AI treasury (wfbe_aicom_funds) instead of a player team, and the null-team guard is bypassed. All other
//--- validation (platform selection, level, cooldown, range, cap) is IDENTICAL to a human fire. NUKE is never an AI munition (v1).
//--- cmdcon42-j (Ray 2026-07-02): for CONVENTIONAL munitions the launch platform is the NEAREST ALIVE side platform
//--- (research TEL OR bought SCUD) to the target; range is measured from THAT platform; per-platform cooldown. NUKE is
//--- research-TEL-only (a bought SCUD can never nuke) and keeps the side-shared cooldown/countdown/counterplay unchanged.
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelFire = {
	private ["_side","_target","_muni","_playerTeam","_fee","_platformHint","_aiTreasury","_isAiFire","_sideText","_telKey","_tel","_now","_cdKey","_last","_cool",
	         "_tgtPos","_range","_dist","_cost","_funds","_platform"];
	_side         = _this select 0;
	_target       = _this select 1;
	_muni         = _this select 2;
	_playerTeam   = _this select 3;
	_fee          = if (count _this > 4) then {_this select 4} else {0};
	//--- cmdcon42-j (Ray 2026-07-02): OPTIONAL platform hint (the specific bought SCUD whose vehicle-action fired). The
	//--- server IGNORES it for NUKE and only HONOURS it for conventional munitions if it is an alive side platform; otherwise
	//--- (or when nil) the nearest-to-target platform is chosen. Never trusted blindly — always re-validated below.
	_platformHint = if (count _this > 5) then {_this select 5} else {objNull};
	if (typeName _platformHint != "OBJECT") then {_platformHint = objNull};
	//--- cmdcon42-n (Ray 2026-07-02): OPTIONAL AI-treasury flag (7th param). When it is a real side, this fire is an AI
	//--- COMMANDER launch: funds are read/charged against the SEPARATE AI treasury (wfbe_aicom_funds via GetAICommanderFunds /
	//--- ChangeAICommanderFunds) instead of a player team's wfbe_funds, and the null-team guard is bypassed (an AI fire carries
	//--- no player team). Every other check (platform selection, level gate, cooldown, range, cap) is IDENTICAL to a human fire —
	//--- the AI plays by the same launch rules; only the wallet differs. A2-OA-safe: a plain side test (no isEqualType/isNil abuse).
	_aiTreasury = if (count _this > 6) then {_this select 6} else {sideUnknown};
	_isAiFire = (_aiTreasury in [west, east, resistance]);

	if !(_side in [west, east, resistance]) exitWith {};
	_sideText = str _side;
	//--- exact-case munition whitelist (no isEqualType); default any unknown to NUKE (safe classic behaviour).
	//--- cmdcon41-w3i (Ray 2026-07-02): +FASCAM (scatter AT mines), +STEELRAIN (airburst anti-infantry), +BUSTER (bunker-buster
	//--- + guaranteed nearest-enemy-structure kill). All conventional (level >= 1, like SATURATION/RECON), shared cooldown/range/funds.
	if !(_muni in ["NUKE","SATURATION","RECON","FASCAM","STEELRAIN","BUSTER"]) then {_muni = "NUKE"};

	//--- Read THIS side's SCUD/ICBM research level up front (used by the level gate below).
	private ["_telLevel"];
	_telLevel = 0;
	if (!isNil "WFBE_UP_ICBM") then {
		private ["_upg"];
		_upg = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
		if (typeName _upg == "ARRAY" && {WFBE_UP_ICBM < count _upg}) then {_telLevel = _upg select WFBE_UP_ICBM};
	};

	//--- Resolve target position (accept an OBJECT or a position array).
	_tgtPos = _target;
	if (typeName _target == "OBJECT") then {_tgtPos = getPosATL _target};
	if (typeName _tgtPos != "ARRAY" || {count _tgtPos < 2}) exitWith {
		["WARNING", Format ["Init_IcbmTel.sqf : [%1] TEL fire — bad target.", _sideText]] Call WFBE_CO_FNC_LogContent;
	};

	//--- PLATFORM SELECTION (cmdcon42-j) — done BEFORE the level gate so a bought SCUD can WAIVE the conventional research
	//--- requirement (the 28000 purchase IS the unlock). NUKE still uses the research TEL only.
	//---   NUKE       : research TEL ONLY (a bought SCUD can never nuke). Uses the classic WFBE_ICBM_TEL_<side> ref.
	//---   CONVENTIONAL: the NEAREST alive side platform (research TEL OR bought SCUD) to the target — UNLESS a valid hint
	//---                 (an alive side platform) was passed by the SCUD vehicle-action, in which case that specific hull
	//---                 fires. Range is measured FROM THE CHOSEN PLATFORM (drive closer to reach further).
	_telKey = Format ["WFBE_ICBM_TEL_%1", _sideText];
	_tel = missionNamespace getVariable [_telKey, objNull];   //--- the research TEL (may be null/dead for a SCUD-only side).
	if (_muni == "NUKE") then {
		_platform = _tel;
	} else {
		//--- honour a valid hint (alive + registered platform for THIS side), else nearest-to-target.
		private ["_allPlats"];
		_allPlats = [_side] Call WFBE_SE_FNC_TkScudAllPlatforms;
		if (!isNull _platformHint && {alive _platformHint} && {_platformHint in _allPlats}) then {
			_platform = _platformHint;
		} else {
			_platform = [_side, _tgtPos] Call WFBE_SE_FNC_TkScudNearestPlatform;
		};
	};

	//--- TWO-LEVEL "SCUD" UPGRADE GATE (cmdcon41). NUKE requires research level >= 2 (research TEL only). CONVENTIONAL
	//--- normally requires research level >= 1 — BUT a bought SCUD launch platform WAIVES that (a purchased SCUD can fire
	//--- conventional munitions with no research). Server-authoritative; the NUKE gate is never waivable.
	private ["_isBoughtScud"];
	_isBoughtScud = (!isNull _platform && {_platform getVariable ["wfbe_is_tk_scud", false]});
	if (_muni == "NUKE" && {_telLevel < 2}) exitWith {
		[_side, "HandleSpecial", ["icbm-tel-msg", "The NUKE needs the ICBM tech (SCUD level 2). Research it to arm the nuclear warhead."]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] NUKE REFUSED — SCUD level %2 < 2.", _sideText, _telLevel]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|REFUSE-LEVEL|%1|muni=NUKE|level=%2", _sideText, _telLevel]);
	};
	if (_muni != "NUKE" && {_telLevel < 1} && {!_isBoughtScud}) exitWith {
		[_side, "HandleSpecial", ["icbm-tel-msg", "That munition needs the SCUD platform (research level 1) or a bought SCUD launcher."]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] %2 REFUSED — SCUD level %3 < 1 and no bought SCUD.", _sideText, _muni, _telLevel]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|REFUSE-LEVEL|%1|muni=%2|level=%3", _sideText, _muni, _telLevel]);
	};

	if (isNull _platform || {!alive _platform}) exitWith {
		//--- No launch platform. NUKE: refuse + ensure a research-TEL replacement is scheduled. Conventional: no platform at all.
		if (_muni == "NUKE") then {
			[_side, "HandleSpecial", ["icbm-tel-msg", "ICBM refused: your TEL is destroyed. A replacement is inbound."]] Call WFBE_CO_FNC_SendToClients;
			if (isNull _tel) then { [_side] spawn { sleep (missionNamespace getVariable ["WFBE_C_ICBM_TEL_RESPAWN", 600]); if (!WFBE_GameOver) then {[_this select 0] Call WFBE_SE_FNC_SpawnIcbmTel} } };
		} else {
			[_side, "HandleSpecial", ["icbm-tel-msg", "That munition refused: no launch platform (TEL or SCUD) is alive."]] Call WFBE_CO_FNC_SendToClients;
		};
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] fire REFUSED — no alive platform (munition %2).", _sideText, _muni]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|REFUSE-NOPLATFORM|%1|muni=%2", _sideText, _muni]);
	};

	_now = time;
	//--- COOLDOWN.
	//---   NUKE / research-TEL semantics: SHARED per-side clock (WFBE_ICBM_TEL_LASTFIRE_<side>) — UNCHANGED.
	//---   CONVENTIONAL from a bought SCUD: PER-PLATFORM clock stored on the hull (multiple launchers fire in parallel).
	//---   CONVENTIONAL from the research TEL: keep the side-shared clock so a single research TEL can't rapid-fire.
	//--- Same duration (WFBE_C_ICBM_TEL_COOLDOWN) either way.
	_cool  = missionNamespace getVariable ["WFBE_C_ICBM_TEL_COOLDOWN", 300];
	private ["_perPlatform"];
	_perPlatform = (_muni != "NUKE" && {_platform getVariable ["wfbe_is_tk_scud", false]});
	if (_perPlatform) then {
		_last = _platform getVariable ["wfbe_tk_scud_lastfire", -99999];
		_cdKey = "";   //--- (per-platform: stamped on the hull below).
	} else {
		_cdKey = Format ["WFBE_ICBM_TEL_LASTFIRE_%1", _sideText];
		_last  = missionNamespace getVariable [_cdKey, -99999];
	};
	if ((_now - _last) < _cool) exitWith {
		[_side, "HandleSpecial", ["icbm-tel-msg", Format ["%1 on cooldown - %2s until the next launch.", (if (_perPlatform) then {"That SCUD"} else {"TEL"}), round (_cool - (_now - _last))]]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] fire on cooldown (%2s left, perPlatform=%3).", _sideText, round (_cool - (_now - _last)), _perPlatform]] Call WFBE_CO_FNC_LogContent;
	};

	//--- RANGE: NUKE unlimited; conventional limited to WFBE_C_ICBM_TEL_RANGE, measured FROM THE CHOSEN PLATFORM.
	//--- A2-OA gotcha (per the FASCAM-cap note below): an `exitWith` nested inside a `then {}` exits only that block, not the
	//--- function — so a nested range refusal would fall through and FIRE anyway. Compute the out-of-range flag inside the
	//--- non-NUKE `then {}`, then refuse with a TOP-LEVEL `if ... exitWith` so it truly aborts the fire.
	_range = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RANGE", 10350];
	_dist  = -1;
	private ["_outOfRange"];
	_outOfRange = false;
	if (_muni != "NUKE") then {
		_dist = (getPosATL _platform) distance [_tgtPos select 0, _tgtPos select 1, 0];
		if (_dist > _range) then {_outOfRange = true};
	};
	if (_outOfRange) exitWith {
		[_side, "HandleSpecial", ["icbm-tel-msg", Format ["Target out of launcher range (%1m > %2m). Drive a SCUD closer, or only the NUKE has unlimited range.", round _dist, _range]]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] %2 fire REFUSED — out of range (%3 > %4).", _sideText, _muni, round _dist, _range]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|REFUSE-RANGE|%1|muni=%2|dist=%3|max=%4", _sideText, _muni, round _dist, _range]);
	};

	//--- FUNDS (server-authoritative; the client does NOT deduct when the TEL flag is on). Cost by munition:
	//---   NUKE       = the classic ICBM fee the caller passed (_fee, the tactical-menu ICBM cost).
	//---   SATURATION = WFBE_C_ICBM_TEL_SAT_COST (cheaper).
	//---   RECON      = WFBE_C_ICBM_TEL_RECON_COST.
	_cost = switch (_muni) do {
		case "SATURATION": {missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000]};
		case "RECON":      {missionNamespace getVariable ["WFBE_C_ICBM_TEL_RECON_COST", 10000]};
		//--- cmdcon41-w3i (Ray 2026-07-02) conventional munition costs.
		case "FASCAM":     {missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_COST", 14000]};
		case "STEELRAIN":  {missionNamespace getVariable ["WFBE_C_ICBM_TEL_RAIN_COST", 9000]};
		case "BUSTER":     {missionNamespace getVariable ["WFBE_C_ICBM_TEL_BUSTER_COST", 18000]};
		default            {_fee};
	};
	//--- cmdcon42-n (Ray 2026-07-02): AI fire reads/charges the AI treasury (wfbe_aicom_funds), not a player team; the null-team
	//--- guard only applies to a human fire (an AI fire legitimately carries no player team). Human path is byte-unchanged.
	//--- A2-OA gotcha (the FASCAM-cap note above): an `exitWith` nested inside a `then/else {}` exits ONLY that block, not the
	//--- function — so the null-team refusal MUST be a TOP-LEVEL `if ... exitWith` (compute the flag first, then refuse) or a
	//--- human fire with a null team would fall through and continue. AI fires carry no team, so the guard is human-only.
	private ["_badTeam"];
	_badTeam = (!_isAiFire) && {isNull _playerTeam};
	if (_badTeam) exitWith {["WARNING", Format ["Init_IcbmTel.sqf : [%1] TEL fire — null team.", _sideText]] Call WFBE_CO_FNC_LogContent};
	if (_isAiFire) then {
		_funds = _aiTreasury Call GetAICommanderFunds;
	} else {
		//--- A2-OA rule: read team funds via the canonical getter (plain group getVariable + isNil inside), NOT a [name,default]
		//--- group getVariable. Deduct via the canonical changer (broadcasts + keeps team-funds bookkeeping consistent).
		_funds = _playerTeam Call WFBE_CO_FNC_GetTeamFunds;
	};
	if (_funds < _cost) exitWith {
		//--- AI fire refusals are logged only (no client message — there is no human commander to inform).
		if (!_isAiFire) then {[_side, "HandleSpecial", ["icbm-tel-msg", Format ["Not enough funds for that TEL munition ($%1 needed).", _cost]]] Call WFBE_CO_FNC_SendToClients};
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL %2 fire REFUSED — funds (%3 < %4, ai=%5).", _sideText, _muni, _funds, _cost, _isAiFire]] Call WFBE_CO_FNC_LogContent;
	};

	//--- cmdcon41-w3i (Ray 2026-07-02) FASCAM FIELD CAP: at most WFBE_C_ICBM_TEL_FASCAM_MAX (2) LIVE mine fields per side.
	//--- Checked HERE — AFTER funds, BEFORE the charge — so a refused-at-cap fire never spends money (Ray's explicit
	//--- "refuse before charging"). The field registry is a side-keyed missionNamespace array the delivery fn appends to
	//--- and the 20-min self-clear waiter prunes; we compact stale/empty entries as we count so the cap is accurate.
	//--- A2-OA gotcha guard: the refusal is a TOP-LEVEL `if ... exitWith` on the function (an exitWith inside a `then {}`
	//--- would exit only that block and fall through to the charge). We pre-compact into _live, then gate on its count.
	private ["_fascamAtCap","_fascamLiveN"];
	_fascamAtCap = false;
	_fascamLiveN = 0;
	if (_muni == "FASCAM") then {
		private ["_fKey","_fields","_live","_fMax","_fx"];
		_fMax = missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_MAX", 2];
		_fKey = Format ["WFBE_ICBM_TEL_FASCAM_FIELDS_%1", _sideText];
		_fields = missionNamespace getVariable [_fKey, []];
		if (typeName _fields != "ARRAY") then {_fields = []};
		//--- compact: keep only field-entries that still hold >=1 live mine (each entry is an array of mine objects).
		_live = [];
		{
			_fx = _x;
			if (typeName _fx == "ARRAY" && {({!isNull _x} count _fx) > 0}) then {_live set [count _live, _fx]};
		} forEach _fields;
		missionNamespace setVariable [_fKey, _live];
		_fascamLiveN = count _live;
		if (_fascamLiveN >= _fMax) then {_fascamAtCap = true};
	};
	if (_fascamAtCap) exitWith {
		private ["_fMaxMsg"];
		_fMaxMsg = missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_MAX", 2];
		[_side, "HandleSpecial", ["icbm-tel-msg", Format ["FASCAM refused: your side already has %1 active mine fields (max %2). Wait for one to clear.", _fascamLiveN, _fMaxMsg]]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] FASCAM REFUSED — at field cap (%2/%3).", _sideText, _fascamLiveN, _fMaxMsg]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|REFUSE-FASCAMCAP|%1|live=%2|max=%3", _sideText, _fascamLiveN, _fMaxMsg]);
	};

	//--- All checks pass: charge + stamp the cooldown BEFORE firing (anti double-fire race). Per-platform (bought SCUD) =
	//--- stamp the hull; otherwise (NUKE / research-TEL conventional) = stamp the side-shared clock.
	//--- cmdcon42-n: an AI fire debits the AI treasury; a human fire debits the player team (byte-unchanged path).
	if (_isAiFire) then {
		[_aiTreasury, -_cost] Call ChangeAICommanderFunds;
	} else {
		[_playerTeam, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds;
	};
	if (_perPlatform) then {
		_platform setVariable ["wfbe_tk_scud_lastfire", _now, true];
	} else {
		missionNamespace setVariable [_cdKey, _now];
	};

	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] LAUNCH AUTHORISED — munition %2 at %3 (cost %4, platform %5, perPlatformCD %6, ai=%7).", _sideText, _muni, [round (_tgtPos select 0), round (_tgtPos select 1)], _cost, typeOf _platform, _perPlatform, _isAiFire]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["ICBMTEL|v1|FIRE|%1|muni=%2|cost=%3|scudPlatform=%4|ai=%5", _sideText, _muni, _cost, _perPlatform, _isAiFire]);

	if (_muni == "NUKE") then {
		[_side, _platform, _tgtPos] Spawn WFBE_SE_FNC_IcbmTelNuke;
	} else {
		//--- PROMPT munitions (SATURATION / RECON / cmdcon41-w3i FASCAM / STEELRAIN / BUSTER): erect+FX now on THE CHOSEN
		//--- PLATFORM, GLOBAL 60s launch marker AT THAT PLATFORM, then deliver. Marks whichever launcher fired.
		[_platform] Call WFBE_SE_FNC_IcbmTelTheatrics;
		[_platform] Call WFBE_SE_FNC_IcbmTelLaunchMarker;   //--- everyone sees "SCUD LAUNCH DETECTED" at the firing platform for 60s.
		switch (_muni) do {
			case "SATURATION": {[_side, _tgtPos] Spawn WFBE_SE_FNC_IcbmTelSaturation};
			case "RECON":      {[_side, _tgtPos] Spawn WFBE_SE_FNC_IcbmTelRecon};
			case "FASCAM":     {[_side, _tgtPos] Spawn WFBE_SE_FNC_IcbmTelFascam};
			case "STEELRAIN":  {[_side, _tgtPos] Spawn WFBE_SE_FNC_IcbmTelSteelRain};
			case "BUSTER":     {[_side, _tgtPos] Spawn WFBE_SE_FNC_IcbmTelBuster};
			default            {[_side, _tgtPos] Spawn WFBE_SE_FNC_IcbmTelSaturation};
		};
	};
};

//------------------------------------------------------------------------------------
//--- GLOBAL 60s "SCUD LAUNCH DETECTED" marker at the TEL (both sides + GUER) — for prompt munitions only.
//--- Plain createMarker on the server replicates to ALL clients (incl. JIP). A server-side timed spawn deletes
//--- it (survives the caller disconnecting; mirrors the guer-mortar-strike + ArtyMarkerCleanup idiom).
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelLaunchMarker = {
	private ["_tel","_mname","_p"];
	_tel = _this select 0;
	if (isNull _tel) exitWith {};
	_p = getPosATL _tel;
	_mname = Format ["wfbe_icbmtel_launch_%1", round (diag_tickTime * 1000)];
	createMarker [_mname, [_p select 0, _p select 1, 0]];
	_mname setMarkerType "mil_destroy";
	_mname setMarkerColor "ColorBlack";
	_mname setMarkerText "SCUD LAUNCH DETECTED";
	_mname setMarkerSize [1, 1];
	[_mname] spawn { sleep 60; deleteMarker (_this select 0) };
};

//------------------------------------------------------------------------------------
//--- NUKE: 5-min countdown at the TEL, owning-side warning + FUZZY enemy intel ping, then the CLASSIC warhead.
//--- We DO NOT reimplement the warhead: at T-0 we call the EXISTING server-side NukeDammage (the exact fn the classic
//--- ICBM impact runs — Server_HandleSpecial case "ICBM":148) on a HeliHEmpty target, and broadcast the classic
//--- icbm-display cinematic + a global klaxon for the visual. Deterministic server-side (no fragile client-pick).
//--- If the TEL is destroyed mid-countdown the killed-EH clears the latch and this bails (cancel handled there).
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelNuke = {
	private ["_side","_tel","_tgtPos","_sideText","_cdKey","_secs","_fuzz","_enemySides","_pingPos","_ang","_r","_steps"];
	_side   = _this select 0;
	_tel    = _this select 1;
	_tgtPos = _this select 2;
	_sideText = str _side;
	_cdKey = Format ["WFBE_ICBM_TEL_CD_%1", _sideText];
	_secs = missionNamespace getVariable ["WFBE_C_ICBM_TEL_COUNTDOWN", 300];
	_fuzz = missionNamespace getVariable ["WFBE_C_ICBM_TEL_PING_FUZZ", 400];

	//--- Arm the countdown latch (the killed-EH reads this to know a NUKE is in flight -> destroy = cancel).
	missionNamespace setVariable [_cdKey, time + _secs];
	//--- pack-missiles: broadcast [launchTime, impactTime] to all clients for the countdown/warning HUD.
	[nil, "HandleSpecial", ["icbm-countdown", time, time + _secs]] Call WFBE_CO_FNC_SendToClients;


	//--- Theatrics at the TEL (erect + smoke) for the whole countdown feel.
	[_tel] Call WFBE_SE_FNC_IcbmTelTheatrics;

	//--- Announce: owning side warned (their own launch); enemy side gets a FUZZY ping marker offset by PING_FUZZ.
	[_side, "HandleSpecial", ["icbm-tel-msg", Format ["ICBM launch sequence started - impact in ~%1s. Defend the TEL: if it is destroyed, the strike aborts.", _secs]]] Call WFBE_CO_FNC_SendToClients;
	_enemySides = WFBE_PRESENTSIDES - [_side];
	_ang = random 360; _r = random _fuzz;
	_pingPos = [(_tgtPos select 0) + _r * sin _ang, (_tgtPos select 1) + _r * cos _ang, 0];
	{
		//--- side-scoped fuzzy enemy ping (createMarkerLocal on enemy clients; auto-deletes after the countdown).
		[_x, "HandleSpecial", ["icbm-tel-enemy-ping", _pingPos, _secs]] Call WFBE_CO_FNC_SendToClients;
		[_x, "HandleSpecial", ["icbm-tel-msg", "WARNING: enemy ICBM launch detected - approximate impact area marked."]] Call WFBE_CO_FNC_SendToClients;
	} forEach _enemySides;

	//--- COUNTDOWN. Poll so a mid-count destroy (killed EH clears the latch) aborts cleanly.
	_steps = 0;
	while {_steps < _secs} do {
		sleep 1;
		_steps = _steps + 1;
		if (isNull _tel || {!alive _tel}) exitWith {};
		if ((missionNamespace getVariable [_cdKey, -1]) <= 0) exitWith {};   //--- latch cleared => canceled (destroyed).
	};

	//--- If the latch was cleared or the TEL died, the killed-EH already handled cancel/secondary/announce. Bail.
	if (isNull _tel || {!alive _tel} || {(missionNamespace getVariable [_cdKey, -1]) <= 0}) exitWith {
		diag_log (Format ["ICBMTEL|v1|NUKE-ABORTED|%1", _sideText]);
	};

	//--- Clear the latch (fired successfully).
	missionNamespace setVariable [_cdKey, -1];

	//--- FIRE the CLASSIC warhead via the EXISTING server-side path — DETERMINISTIC, no client-pick (A2-OA has no
	//--- reliable server-side "is this a real player, not an HC" test, and picking a client risks the wrong one / an
	//--- HC that cannot run it). The classic tactical-menu ICBM ultimately detonates via NukeDammage at the target
	//--- (Server_HandleSpecial case "ICBM":148 -> [_base] Spawn NukeDammage). We call that same NukeDammage here on a
	//--- HeliHEmpty target marker (its exact input), so the warhead is NOT reimplemented. We ALSO broadcast the
	//--- icbm-display cinematic + a klaxon to all clients for the visual (the same icbm-display client fn the classic
	//--- path uses, given a cruise missile object). Impact is immediate at T-0 (the countdown already elapsed).
	private ["_obj","_cruise"];
	_obj = "HeliHEmpty" createVehicle [_tgtPos select 0, _tgtPos select 1, 0];
	//--- cruise missile visual (Chukar_EP1 confirmed in-tree; ballistic, no pilot) diving onto the target for the cinematic.
	_cruise = createVehicle ["Chukar_EP1", [_tgtPos select 0, _tgtPos select 1, 400], [], 0, "FLY"];
	_cruise setPosASL [_tgtPos select 0, _tgtPos select 1, 400];
	_cruise setVectorDir [0, 0, -1];
	_cruise setVelocity [0, 0, -120];
	//--- everyone hears the alarm + sees the classic icbm-display cinematic (WFBE_CL_FNC_Display_ICBM, given the cruise obj).
	[nil, "HandleSpecial", ["scud-klaxon-all"]] Call WFBE_CO_FNC_SendToClients;
	[nil, "HandleSpecial", ["icbm-display", _obj, _cruise]] Call WFBE_CO_FNC_SendToClients;
	//--- SERVER warhead at the target (the exact NukeDammage the classic ICBM impact runs). Small delay so the cruise
	//--- visual reads before the flash; then clean up the cruise object.
	[_obj, _cruise] spawn {
		private ["_o","_c"];
		_o = _this select 0; _c = _this select 1;
		sleep 2;
		if (!isNull _c) then {deleteVehicle _c};
		if (!isNil "NukeDammage") then { [_o] Spawn NukeDammage };
	};
	diag_log (Format ["ICBMTEL|v1|NUKE-FIRE|%1|server warhead + global cinematic", _sideText]);
};

//------------------------------------------------------------------------------------
//--- SATURATION: the ScudStrike MIRV warhead loop at the target (cheaper). We reuse the EXACT warhead classnames
//--- + phased pattern Support_ScudStrike uses (HE x3 / SADARM x2 / WP x3) so behaviour matches the carrier strike.
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelSaturation = {
	private ["_side","_dest","_zoneR","_warHE","_warSADARM","_warWP","_enemySides","_armour","_i","_ang","_r","_veh"];
	_side = _this select 0;
	_dest = _this select 1;
	_zoneR     = missionNamespace getVariable ["WFBE_C_SCUD_ZONE_RADIUS", 300];
	_warHE     = missionNamespace getVariable ["WFBE_C_SCUD_WARHEAD_HE", "Sh_125_HE"];
	_warSADARM = missionNamespace getVariable ["WFBE_C_SCUD_WARHEAD_SADARM", "Bo_GBU12_LGB"];
	_warWP     = missionNamespace getVariable ["WFBE_C_SCUD_WARHEAD_WP", "SmokeShellWhite"];
	_enemySides = (WFBE_PRESENTSIDES - [_side]) + [resistance];

	//--- brief flight feel before impact (the missile is notional; keep it snappy).
	sleep 6;

	//--- SADARM x2 top-attack on the two best enemy armour/static targets, scatter if none.
	_armour = [];
	{
		if (alive _x && {(side _x) in _enemySides} && {!(_x isKindOf "Air")} && {(_x isKindOf "LandVehicle") || (_x isKindOf "StaticWeapon")}) then {
			_armour set [count _armour, _x];
		};
	} forEach (nearestObjects [_dest, ["LandVehicle","StaticWeapon"], _zoneR]);
	for "_i" from 0 to 1 do {
		if (_i < count _armour) then {
			_veh = _armour select _i;
			_warSADARM createVehicle [getPos _veh select 0, getPos _veh select 1, 120];
		} else {
			_ang = random 360; _r = random (_zoneR * 0.6);
			_warSADARM createVehicle [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang, 120];
		};
		sleep 0.4;
	};
	//--- HE x3 scattered bursts.
	for "_i" from 0 to 2 do {
		_ang = random 360; _r = random _zoneR;
		_warHE createVehicle [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang, 0];
		sleep 0.3;
	};
	//--- WP x3 burn layer.
	for "_i" from 0 to 2 do {
		_ang = random 360; _r = random (_zoneR * 0.7);
		_warWP createVehicle [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang, 0];
		sleep 0.2;
	};
	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL SATURATION delivered at %2 (%3 armour targets).", str _side, [round (_dest select 0), round (_dest select 1)], count _armour]] Call WFBE_CO_FNC_LogContent;
};

//------------------------------------------------------------------------------------
//--- RECON FLASH: high airburst over the target that reveals ENEMY within RECON_R for RECON_SECS.
//---   (a) AI reveal: the firing side's AI group LEADERS reveal each detected enemy (2-operand reveal, A2-safe).
//---   (b) player markers: side-scoped map dots for the firing side's players (createMarkerLocal, auto-delete).
//--- Loops are BOUNDED (nearestObjects radius + a marker cap). Garnish: a high flare + small HE airburst.
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelRecon = {
	private ["_side","_dest","_r","_secs","_cap","_enemySides","_enemies","_grp","_ldr","_flare","_markerData","_i","_e"];
	_side = _this select 0;
	_dest = _this select 1;
	_r    = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RECON_R", 800];
	_secs = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RECON_SECS", 45];
	_cap  = 40;   //--- hard cap on markers (bounded).
	_enemySides = (WFBE_PRESENTSIDES - [_side]) + [resistance];

	sleep 4;   //--- short time-of-flight to the airburst.

	//--- Garnish: a high airburst over the target. cruiseMissileFlare1 is confirmed in-tree (nukeincoming.sqf) as a
	//--- bright flare; plus one small HE at altitude for a visible pop (Sh_125_HE, in-tree, reused from ScudStrike).
	_flare = createVehicle ["cruiseMissileFlare1", [(_dest select 0), (_dest select 1), 220], [], 0, "NONE"];
	if (!isNull _flare) then {_flare inflame true};
	(missionNamespace getVariable ["WFBE_C_SCUD_WARHEAD_HE", "Sh_125_HE"]) createVehicle [(_dest select 0), (_dest select 1), 200];

	//--- Gather living enemy MEN + crewed vehicles in radius (bounded by nearestObjects radius).
	_enemies = [];
	{
		if (alive _x && {(side _x) in _enemySides}) then {
			if (_x isKindOf "Man") then {
				_enemies set [count _enemies, _x];
			} else {
				if (({alive _x} count (crew _x)) > 0) then {_enemies set [count _enemies, _x]};
			};
		};
	} forEach (nearestObjects [_dest, ["Man","LandVehicle","Air"], _r]);

	//--- (a) AI reveal: each firing-side AI leader reveals each detected enemy (2-operand reveal — A2-OA-safe).
	//--- Bound the outer loop to AI-led same-side groups; inner loop already bounded by _enemies.
	{
		_grp = _x;
		if (side _grp == _side) then {
			_ldr = leader _grp;
			if (!isNull _ldr && {alive _ldr} && {!isPlayer _ldr}) then {
				{ _ldr reveal _x } forEach _enemies;
			};
		};
	} forEach allGroups;

	//--- (b) player map dots: side-scoped send of the enemy positions (capped) -> owning-side clients createMarkerLocal.
	_markerData = [];
	_i = 0;
	{
		if (_i < _cap) then {
			_e = _x;
			_markerData set [count _markerData, [getPosATL _e select 0, getPosATL _e select 1]];
			_i = _i + 1;
		};
	} forEach _enemies;
	[_side, "HandleSpecial", ["icbm-tel-recon-markers", _markerData, _secs]] Call WFBE_CO_FNC_SendToClients;

	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL RECON revealed %2 enemy (radius %3, %4s).", str _side, count _enemies, _r, _secs]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["ICBMTEL|v1|RECON|%1|enemies=%2|markers=%3", str _side, count _enemies, count _markerData]);
};

//------------------------------------------------------------------------------------
//--- cmdcon41-w3i (Ray 2026-07-02) SHARED HELPER: BOTH-SIDE impact announcement — "<thing> reported near <closest town
//--- name if cheap, else map coords>". Uses the canonical GetClosestLocation (nearest towns[] logic) + its "name" var
//--- (the SAME idiom every server log/message uses: `_town getVariable "name"`). Fallback when NO town is near = rounded
//--- world X/Y (A2-OA-trivially-safe: no mapGridPosition dependency). Announces to ALL present sides via the existing
//--- side-scoped icbm-tel-msg case (no new client plumbing).
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelImpactAnnounce = {
	private ["_headline","_dest","_closest","_where","_name"];
	_headline = _this select 0;
	_dest     = _this select 1;
	_where = Format ["map coords %1 / %2", round (_dest select 0), round (_dest select 1)];
	if (!isNil "GetClosestLocation") then {
		_closest = [_dest] Call GetClosestLocation;
		if (!isNull _closest) then {
			_name = _closest getVariable ["name", ""];
			if (typeName _name == "STRING" && {_name != ""}) then {_where = _name};
		};
	};
	{
		[_x, "HandleSpecial", ["icbm-tel-msg", Format ["%1 reported near %2.", _headline, _where]]] Call WFBE_CO_FNC_SendToClients;
	} forEach WFBE_PRESENTSIDES;
};

//------------------------------------------------------------------------------------
//--- cmdcon41-w3i (Ray 2026-07-02) FASCAM: scatter WFBE_C_ICBM_TEL_FASCAM_MINES (24) AT mines uniformly in a disc of
//--- WFBE_C_ICBM_TEL_FASCAM_R (150)m around dest, then SELF-CLEAR after WFBE_C_ICBM_TEL_FASCAM_MINS (20) minutes.
//--- MINE PLACEMENT is the VERIFIED in-tree idiom (Construction_StationaryDefense.sqf:46-53): createMine with the placed
//--- AT-mine class 'MineMine' (west) / 'MineMineE' (east) — NOT the loadout magazine "Mine"/"MineE". createMine is the
//--- A2-OA command that arms + activates a live mine (createVehicle would drop an inert prop). GUER fires east's mine.
//--- The field is pushed onto a SIDE-KEYED missionNamespace array (the fire-path cap counts live fields off this); a
//--- spawned waiter deleteVehicles the survivors at T+MINS. Garnish: a SmokeShellWhite puff at each impact (confirmed
//--- in-tree; the base minefield has no HE crater and neither do we — an AT mine is not an explosion at drop).
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelFascam = {
	private ["_side","_dest","_n","_rad","_mins","_mineType","_fKey","_fields","_field","_i","_ang","_r","_mp","_mine"];
	_side = _this select 0;
	_dest = _this select 1;
	_n    = missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_MINES", 24];
	_rad  = missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_R", 150];
	_mins = missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_MINS", 20];
	//--- placed-AT-mine class by side (GUER lays the eastern pattern). Flag-overridable, defaults = the base-minefield classes.
	if (_side == west) then {
		_mineType = missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_MINE_W", "MineMine"];
	} else {
		_mineType = missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_MINE_E", "MineMineE"];
	};

	//--- short time-of-flight before the mines rain down (matches the SATURATION/RECON snappy feel).
	sleep 5;

	_field = [];
	for "_i" from 1 to _n do {
		//--- UNIFORM-IN-DISC: r = R * sqrt(random 1), theta = random 360 (even area density, not centre-biased).
		_ang = random 360;
		_r   = _rad * sqrt (random 1);
		_mp  = [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang, 0];
		_mine = createMine [_mineType, _mp, [], 0];
		if (!isNull _mine) then {_field set [count _field, _mine]};
		//--- small dust/smoke garnish at the drop (verified in-tree; visually reads the scatter without a fake HE crater).
		(createVehicle ["SmokeShellWhite", [_mp select 0, _mp select 1, 0], [], 0, "NONE"]);
	};

	//--- register this field on the side-keyed registry (the fire-path FASCAM cap counts live fields off this array).
	_fKey = Format ["WFBE_ICBM_TEL_FASCAM_FIELDS_%1", str _side];
	_fields = missionNamespace getVariable [_fKey, []];
	if (typeName _fields != "ARRAY") then {_fields = []};
	_fields set [count _fields, _field];
	missionNamespace setVariable [_fKey, _fields];

	//--- SELF-CLEAR waiter: at T+MINS deleteVehicle the survivors + drop this field entry from the registry.
	[_side, _field, _mins] spawn {
		private ["_wSide","_wField","_wMins","_wKey","_wFields"];
		_wSide  = _this select 0;
		_wField = _this select 1;
		_wMins  = _this select 2;
		sleep (_wMins * 60);
		{ if (!isNull _x) then {deleteVehicle _x} } forEach _wField;
		_wKey = Format ["WFBE_ICBM_TEL_FASCAM_FIELDS_%1", str _wSide];
		_wFields = missionNamespace getVariable [_wKey, []];
		if (typeName _wFields == "ARRAY") then {
			_wFields = _wFields - [_wField];
			missionNamespace setVariable [_wKey, _wFields];
		};
		diag_log (Format ["ICBMTEL|v1|FASCAM-CLEAR|%1|field cleared after %2min", str _wSide, _wMins]);
	};

	//--- BOTH-SIDE announce (mine barrage). count _field = mines that actually placed.
	["mine barrage", _dest] Call WFBE_SE_FNC_IcbmTelImpactAnnounce;
	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL FASCAM laid %2/%3 mines (r=%4, clears in %5min).", str _side, count _field, _n, _rad, _mins]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["ICBMTEL|v1|FASCAM|%1|mines=%2|r=%3|clearMin=%4", str _side, count _field, _rad, _mins]);
};

//------------------------------------------------------------------------------------
//--- cmdcon41-w3i (Ray 2026-07-02) STEELRAIN: ~WFBE_C_ICBM_TEL_RAIN_BURSTS (18) flak-like AIRBURSTS over a
//--- WFBE_C_ICBM_TEL_RAIN_R (300)m disc, rolling over ~20s. Per burst: createVehicle a small HE shell at 25-35m
//--- altitude over a uniform-in-disc point (the shell's own tiny splash is acceptable garnish), then SCRIPTED falloff
//--- damage to EXPOSED (on-foot) infantry within WFBE_C_ICBM_TEL_RAIN_BURST_R (40)m: 0.9 <10m, 0.5 <25m, 0.2 <40m
//--- (added to current damage, capped at 1). Vehicles/structures are NOT scripted-damaged. The per-burst scan is BOUNDED
//--- (nearEntities [["Man"], BURST_R]) and on-foot-tested with the in-tree `vehicle _x == _x` idiom. HE class = the same
//--- WFBE_C_SCUD_WARHEAD_HE (Sh_125_HE) the sibling SATURATION/RECON + the live carrier SCUD use (proven mission ammo).
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelSteelRain = {
	private ["_side","_dest","_bursts","_rad","_burstR","_he","_span","_gap","_i","_ang","_r","_bx","_alt","_bp","_dmgKilled","_u","_d","_add","_cur"];
	_side    = _this select 0;
	_dest    = _this select 1;
	_bursts  = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RAIN_BURSTS", 18];
	_rad     = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RAIN_R", 300];
	_burstR  = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RAIN_BURST_R", 40];
	_he      = missionNamespace getVariable ["WFBE_C_SCUD_WARHEAD_HE", "Sh_125_HE"];
	_span    = 20;   //--- roll the barrage over ~20s.
	_gap     = if (_bursts > 0) then {_span / _bursts} else {1};

	//--- short time-of-flight before the first airburst.
	sleep 4;

	_dmgKilled = 0;
	for "_i" from 1 to _bursts do {
		//--- uniform-in-disc burst point; airburst altitude 25-35m over it.
		_ang = random 360;
		_r   = _rad * sqrt (random 1);
		_bx  = [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang];
		_alt = 25 + (random 10);
		_bp  = [_bx select 0, _bx select 1, 0];   //--- ground reference for the infantry scan (2D distance).
		_he createVehicle [_bx select 0, _bx select 1, _alt];
		//--- SCRIPTED anti-infantry falloff: EXPOSED (on-foot) men only, bounded scan.
		{
			_u = _x;
			if (alive _u && {vehicle _u == _u}) then {
				_d = _u distance _bp;
				_add = 0;
				if (_d < 10) then {_add = 0.9} else {
					if (_d < 25) then {_add = 0.5} else {
						if (_d < _burstR) then {_add = 0.2};
					};
				};
				if (_add > 0) then {
					_cur = damage _u;
					_u setDamage ((_cur + _add) min 1);
					if ((_cur + _add) >= 1) then {_dmgKilled = _dmgKilled + 1};
				};
			};
		} forEach (_bp nearEntities [["Man"], _burstR]);
		sleep _gap;
	};

	["airburst artillery", _dest] Call WFBE_SE_FNC_IcbmTelImpactAnnounce;
	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL STEELRAIN delivered %2 airbursts (r=%3, ~%4 infantry cut down).", str _side, _bursts, _rad, _dmgKilled]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["ICBMTEL|v1|STEELRAIN|%1|bursts=%2|r=%3|killed=%4", str _side, _bursts, _rad, _dmgKilled]);
};

//------------------------------------------------------------------------------------
//--- cmdcon41-w3i (Ray 2026-07-02) BUSTER: 3x Bo_GBU12_LGB (VERIFIED in-tree — the SCUD/drone-strike SADARM warhead)
//--- created sequentially ~0.6s apart at ~120m directly above dest (they fall + detonate on the point). Then GUARANTEE
//--- the kill: after the last impact (sleep ~3) find the NEAREST enemy-side STRUCTURE within WFBE_C_ICBM_TEL_BUSTER_R
//--- (30)m of dest and setDamage 1 it. Enemy structures are identified via WFBE_CO_FNC_GetSideStructures — the SAME
//--- registry the base-assault/victory razing reads (AI_Commander_Strategy.sqf:903: setDamage 1 forEach GetSideStructures
//--- within radius). We take only the single NEAREST via WFBE_CO_FNC_GetClosestEntity + a radius gate — never touch any
//--- other structure. GUER is included in the enemy set. No enemy structure in radius -> bombs still fell, log NO_TARGET.
//------------------------------------------------------------------------------------
WFBE_SE_FNC_IcbmTelBuster = {
	private ["_side","_dest","_r","_bomb","_i","_enemySides","_cands","_es","_closest","_d","_hit"];
	_side = _this select 0;
	_dest = _this select 1;
	_r    = missionNamespace getVariable ["WFBE_C_ICBM_TEL_BUSTER_R", 30];
	_bomb = missionNamespace getVariable ["WFBE_C_SCUD_WARHEAD_SADARM", "Bo_GBU12_LGB"];

	//--- short time-of-flight, then 3 guided bombs onto the point, ~0.6s apart, from ~120m up.
	sleep 4;
	for "_i" from 1 to 3 do {
		_bomb createVehicle [_dest select 0, _dest select 1, 120];
		sleep 0.6;
	};

	//--- let the last bomb resolve, then GUARANTEE the nearest enemy structure.
	sleep 3;
	//--- enemy set = all present sides EXCEPT the firing side (resistance already lives in WFBE_PRESENTSIDES when GUER is
	//--- in play; subtracting _side last guarantees we never target our OWN structures even if the firer is GUER).
	_enemySides = (WFBE_PRESENTSIDES + [resistance]) - [_side];
	//--- gather enemy-side structures (each side's placed structure objects), then pick the nearest to dest.
	_cands = [];
	{
		_es = _x;
		{ if (!isNull _x && {alive _x}) then {_cands set [count _cands, _x]} } forEach (_es Call WFBE_CO_FNC_GetSideStructures);
	} forEach _enemySides;

	_closest = objNull;
	if (count _cands > 0) then {_closest = [_dest, _cands] Call WFBE_CO_FNC_GetClosestEntity};
	_hit = false;
	if (!isNull _closest) then {
		_d = _closest distance [_dest select 0, _dest select 1, getPosATL _closest select 2];
		if (_d <= _r) then {
			_closest setDamage 1;
			_hit = true;
		};
	};

	["bunker-buster strike", _dest] Call WFBE_SE_FNC_IcbmTelImpactAnnounce;
	if (_hit) then {
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL BUSTER destroyed the nearest enemy structure (%2) within %3m.", str _side, typeOf _closest, _r]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|BUSTER|%1|struct=%2|kill=1", str _side, typeOf _closest]);
	} else {
		["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] TEL BUSTER — no enemy structure within %2m of the point (bombs fell, no refund).", str _side, _r]] Call WFBE_CO_FNC_LogContent;
		diag_log (Format ["ICBMTEL|v1|BUSTER_NO_TARGET|%1|r=%2", str _side, _r]);
	};
};

//====================================================================================
//--- cmdcon42-n (Ray 2026-07-02) AI COMMANDER SCUD (Takistan only). Ray: "allow AI commanders on Takistan to use the
//--- SCUD, just not spam it at enemy base." Builds on the #174 plumbing above: it reuses WFBE_SE_FNC_IcbmTelFire (with the
//--- new AI-treasury 7th param), the side platform registry, nearest-platform selection and per-platform cooldowns UNCHANGED.
//---
//--- WHAT IT DOES (per AI-commanded side, low cadence ~120s):
//---   • Skips a side a HUMAN commands (same isPlayer-leader-of-commander-team idiom AI_Commander.sqf uses) — humans keep the
//---     Tactical menu; the AI never fires for a human-led side.
//---   • Requires SCUD research level >= 1 AND at least one alive launch platform (research TEL or a bought SCUD).
//---   • Picks a TACTICAL target = the LARGEST cluster of ENEMY units. Anchors are bounded to the top ~6 candidate points
//---     (enemy-held town centres + this side's own CONTESTED towns) — a 300m nearEntities cluster scan around each, keeping
//---     the biggest cluster with >= MIN_CLUSTER (8) enemy units that is IN RANGE of some side platform.
//---   • ANTI-BASE RULE (Ray's explicit constraint): HARD-EXCLUDE any candidate within HQ_EXCLUSION (900m) of the enemy
//---     HQ/base centre — the AI never SCUDs the enemy base area. (A rare-base-strike variant is one flag away: drop the
//---     exclusion test / add a chance gate — intentionally NOT enabled per Ray.)
//---   • Fires "SATURATION" (v1 keeps the proven munition) via WFBE_SE_FNC_IcbmTelFire, paying the AI treasury; skips when
//---     side funds < 2x the SAT cost so the AI never bankrupts itself.
//---   • CADENCE guards on top of the per-platform cooldown: a per-side minimum interval (AI_INTERVAL, 600s) AND a
//---     2-tick confirmation — a cluster must PERSIST across two consecutive evaluator ticks (last-seen pos+time stored;
//---     re-confirm within 350m) so a passing patrol is never reflex-nuked.
//---   • OPTIONAL PURCHASE (sub-flag WFBE_C_TK_SCUD_AI_BUY): when rich (econ-surge OR funds > AI_BUY_FUNDS) and the side owns
//---     < 1 bought SCUD and its HEAVY factory upgrade >= the buy-row level, buy ONE via the SAME server register path players
//---     use (charge AI treasury, register platform, per-side cap still enforced by TkScudRegister).
//---   • TELEMETRY: AICOMSTAT ...|AI_SCUD|... per fire; |AI_SCUD_BUY| on purchase. The existing 60s global launch marker +
//---     theatrics apply as normal — players can hunt the AI's launchers (that's the game).
//---
//--- A2-OA-1.64 safe throughout: no isEqualType/isEqualTo; ==/!= only on non-Boolean operands (if/else for bools); plain
//--- getVariable + isNil; nearEntities/nearestObjects bounded; side tests via `in [west,east,resistance]`.
//====================================================================================

//--- Is a side currently commanded by a HUMAN? (mirror AI_Commander.sqf: commander team leader is a real player.) Honours the
//--- AICOM LOCK (lock=1 => treat as AI-commanded so the AI keeps firing during evals/night, same as the supervisor).
WFBE_SE_FNC_IcbmTelSideIsAI = {
	private ["_side","_cmdTeam"];
	_side = _this select 0;
	if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) exitWith {true};
	_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
	if (isNull _cmdTeam) exitWith {true};   //--- no commander team object => not a human commander.
	if (isPlayer (leader _cmdTeam)) exitWith {false};
	true
};

//--- A side's SCUD/ICBM research level (0 if the constant/upgrade array is absent). Same read the fire path uses.
WFBE_SE_FNC_IcbmTelSideScudLevel = {
	private ["_side","_lvl","_upg"];
	_side = _this select 0;
	_lvl = 0;
	if (!isNil "WFBE_UP_ICBM") then {
		_upg = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
		if (typeName _upg == "ARRAY" && {WFBE_UP_ICBM < count _upg}) then {_lvl = _upg select WFBE_UP_ICBM};
	};
	_lvl
};

//--- Count ALIVE enemy entities (men + crewed vehicles) within _radius of _pos. Bounded by nearEntities radius. Returns a
//--- SCALAR count. _enemySides is precomputed by the caller (all present sides + resistance, minus the firing side).
WFBE_SE_FNC_IcbmTelEnemyClusterN = {
	private ["_pos","_radius","_enemySides","_n","_e"];
	_pos        = _this select 0;
	_radius     = _this select 1;
	_enemySides = _this select 2;
	_n = 0;
	{
		_e = _x;
		if (alive _e && {(side _e) in _enemySides}) then {
			//--- on-foot man OR a crewed vehicle (empty hulls don't count as a target mass). A2-OA-safe crew test.
			if (_e isKindOf "Man") then {
				_n = _n + 1;
			} else {
				if (({alive _x} count (crew _e)) > 0) then {_n = _n + 1};
			};
		};
	} forEach (_pos nearEntities [["Man","LandVehicle","Air"], _radius]);
	_n
};

//--- ONE AI-side SCUD evaluation tick. Returns nothing; self-gates on every rule. Called by the spawned loop below.
WFBE_SE_FNC_IcbmTelAiEval = {
	private ["_side","_sideText","_enemySides","_enemyHQ","_hqExcl","_clusterRad","_minCluster","_range",
	         "_scudLvl","_plats","_anchors","_maxAnchors","_myID","_t","_tSideID","_bestPos","_bestN","_n","_np","_confKey","_confTKey",
	         "_lastPos","_lastT","_confirmR","_confirmed","_now","_lastFireKey","_lastFire","_aiInterval","_satCost","_funds"];
	_side = _this select 0;
	if !(_side in [west, east, resistance]) exitWith {};
	_sideText = str _side;

	//--- Only AI-commanded sides fire (human commanders keep the Tactical menu).
	if !([_side] Call WFBE_SE_FNC_IcbmTelSideIsAI) exitWith {};

	//--- Research + platform gates.
	_scudLvl = [_side] Call WFBE_SE_FNC_IcbmTelSideScudLevel;
	if (_scudLvl < 1) exitWith {};
	_plats = [_side] Call WFBE_SE_FNC_TkScudAllPlatforms;
	if (count _plats == 0) exitWith {};

	//--- Enemy set (the firing side is excluded; resistance folded in so GUER towns/units count as enemy mass).
	_enemySides = (WFBE_PRESENTSIDES + [resistance]) - [_side];
	//--- Enemy HQ centre for the anti-base exclusion. On a 2-AI-side match the enemy is the OTHER main side; we also fold in
	//--- every OTHER present side's HQ so no side's base is ever struck. HQ_EXCLUSION is a hard radius (Ray: never SCUD the base).
	_hqExcl     = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_HQ_EXCLUSION", 900];
	_clusterRad = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_CLUSTER_R", 300];
	_minCluster = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_MIN_CLUSTER", 8];
	_maxAnchors = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_MAX_ANCHORS", 6];
	_range      = missionNamespace getVariable ["WFBE_C_ICBM_TEL_RANGE", 10350];
	_myID = (_side) Call WFBE_CO_FNC_GetSideID;

	//--- BUILD ANCHOR LIST (bounded): enemy-held town centres + this side's OWN contested towns (a town we hold but that has
	//--- enemies pressing it is exactly where a cluster forms). Cap to the nearest _maxAnchors to a side platform so the
	//--- cluster scan stays cheap (<= _maxAnchors nearEntities calls per side per tick). Positions are town-object positions.
	private ["_platAnchor","_candsRaw"];
	//--- reference point for anchor ranking = the side's FIRST platform (any platform; nearest-to-target is re-resolved at fire).
	_platAnchor = getPosATL (_plats select 0);
	_candsRaw = [];
	{
		_t = _x;
		_tSideID = _t getVariable ["sideID", -1];
		//--- enemy-held town (sideID != mine and not neutral -1) OR my own town (contested clusters form on our front towns too).
		if ((_tSideID != _myID && {_tSideID >= 0}) || {_tSideID == _myID}) then {
			_np = getPos _t;
			//--- ANTI-BASE: skip any anchor within HQ_EXCLUSION of ANY enemy HQ (never build a target near a base).
			private ["_tooCloseToBase"];
			_tooCloseToBase = false;
			{
				_enemyHQ = (_x) Call WFBE_CO_FNC_GetSideHQ;
				if (!isNull _enemyHQ) then {
					if ((_np distance (getPos _enemyHQ)) < _hqExcl) exitWith {_tooCloseToBase = true};
				};
			} forEach _enemySides;
			//--- must also be reachable by SOME platform (range measured from the nearest platform, as at fire time).
			if (!_tooCloseToBase) then {
				private ["_nearPlat"];
				_nearPlat = [_side, _np] Call WFBE_SE_FNC_TkScudNearestPlatform;
				if (!isNull _nearPlat && {(getPosATL _nearPlat) distance [_np select 0, _np select 1, 0] <= _range}) then {
					_candsRaw set [count _candsRaw, _np];
				};
			};
		};
	} forEach towns;

	//--- Keep the _maxAnchors positions CLOSEST to the platform-anchor (bounded scan) WITHOUT the sort/resize commands (not used
	//--- anywhere else in this tree — we don't assume them). Manual repeated min-find: pull the nearest still-unpicked cand up to
	//--- _maxAnchors times. O(candsRaw * maxAnchors) which is tiny (towns count * 6). A2-OA-safe: only distance/set/forEach.
	if (count _candsRaw == 0) exitWith {};   //--- nothing valid, in-range, and away from bases.
	_anchors = [];
	private ["_picked","_pi","_bestI","_bestD","_ci","_cd2","_already"];
	_picked = [];
	for "_pi" from 1 to (_maxAnchors min (count _candsRaw)) do {
		_bestI = -1; _bestD = 1e12;
		for "_ci" from 0 to ((count _candsRaw) - 1) do {
			_already = false;
			{ if (_x == _ci) exitWith {_already = true} } forEach _picked;
			if (!_already) then {
				_cd2 = ((_candsRaw select _ci) distance _platAnchor);
				if (_cd2 < _bestD) then {_bestD = _cd2; _bestI = _ci};
			};
		};
		if (_bestI >= 0) then {
			_picked set [count _picked, _bestI];
			_anchors set [count _anchors, (_candsRaw select _bestI)];
		};
	};

	if (count _anchors == 0) exitWith {};

	//--- CLUSTER SCAN: pick the anchor with the largest enemy cluster (>= _minCluster). Bounded to <= _maxAnchors scans.
	_bestPos = [0,0,0]; _bestN = 0;
	{
		_np = _x;
		_n = [_np, _clusterRad, _enemySides] Call WFBE_SE_FNC_IcbmTelEnemyClusterN;
		if (_n > _bestN) then {_bestN = _n; _bestPos = _np};
	} forEach _anchors;

	if (_bestN < _minCluster) exitWith {
		//--- no worthy mass this tick; clear the pending confirmation (we require CONSECUTIVE re-confirmation).
		missionNamespace setVariable [Format ["WFBE_TK_SCUD_AI_CLUST_%1", _sideText], [0,0,0]];
		missionNamespace setVariable [Format ["WFBE_TK_SCUD_AI_CLUSTT_%1", _sideText], -1];
	};

	//--- 2-TICK PERSISTENCE: only fire when the SAME cluster (within _confirmR) was seen on the PREVIOUS tick too.
	_now = time;
	_confKey  = Format ["WFBE_TK_SCUD_AI_CLUST_%1",  _sideText];
	_confTKey = Format ["WFBE_TK_SCUD_AI_CLUSTT_%1", _sideText];
	_confirmR = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_CONFIRM_R", 350];
	_lastPos = missionNamespace getVariable [_confKey, [0,0,0]];
	_lastT   = missionNamespace getVariable [_confTKey, -1];
	//--- a valid prior sighting = within 2.5 evaluator intervals (so a skipped tick doesn't force a full re-warm-up).
	_confirmed = false;
	if (_lastT > 0 && {(_now - _lastT) <= (2.5 * (missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_TICK", 120]))}) then {
		if ((_bestPos distance _lastPos) <= _confirmR) then {_confirmed = true};
	};
	//--- always (re)store this tick's cluster as the new "last seen" so next tick can confirm.
	missionNamespace setVariable [_confKey, _bestPos];
	missionNamespace setVariable [_confTKey, _now];

	if (!_confirmed) exitWith {
		diag_log (Format ["AICOMSTAT|v2|EVENT|%1|%2|AI_SCUD_TRACK|clusterN=%3|pos=%4|awaiting-confirm", _sideText, round (_now / 60), _bestN, [round (_bestPos select 0), round (_bestPos select 1)]]);
	};

	//--- PER-SIDE MINIMUM INTERVAL (on top of the per-platform cooldown enforced inside the fire fn).
	_lastFireKey = Format ["WFBE_TK_SCUD_AI_LASTFIRE_%1", _sideText];
	_lastFire    = missionNamespace getVariable [_lastFireKey, -99999];
	_aiInterval  = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_INTERVAL", 600];
	if ((_now - _lastFire) < _aiInterval) exitWith {};

	//--- FUNDS GATE: never bankrupt the AI — require >= 2x the SATURATION cost before firing.
	_satCost = missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000];
	_funds   = _side Call GetAICommanderFunds;
	if (_funds < (2 * _satCost)) exitWith {
		diag_log (Format ["AICOMSTAT|v2|EVENT|%1|%2|AI_SCUD_SKIP_FUNDS|funds=%3|need=%4", _sideText, round (_now / 60), _funds, 2 * _satCost]);
	};

	//--- FIRE. SATURATION (v1). platformHint=objNull -> the fire fn resolves the nearest platform to _bestPos itself and
	//--- measures range from it. _aiTreasury=_side -> charges wfbe_aicom_funds. grpNull team (unused on the AI path).
	private ["_nearPlatForLog"];
	_nearPlatForLog = [_side, _bestPos] Call WFBE_SE_FNC_TkScudNearestPlatform;
	[_side, _bestPos, "SATURATION", grpNull, _satCost, objNull, _side] Call WFBE_SE_FNC_IcbmTelFire;
	missionNamespace setVariable [_lastFireKey, _now];
	diag_log (Format ["AICOMSTAT|v2|EVENT|%1|%2|AI_SCUD|side=%1|target=%3|clusterN=%4|platform=%5", _sideText, round (_now / 60), [round (_bestPos select 0), round (_bestPos select 1)], _bestN, (if (isNull _nearPlatForLog) then {"none"} else {typeOf _nearPlatForLog})]);
	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] AI SCUD launch — SATURATION at %2 (clusterN %3, funds %4).", _sideText, [round (_bestPos select 0), round (_bestPos select 1)], _bestN, _funds]] Call WFBE_CO_FNC_LogContent;
};

//--- OPTIONAL AI SCUD PURCHASE (sub-flag WFBE_C_TK_SCUD_AI_BUY). When rich AND the side owns < 1 bought SCUD AND its HEAVY
//--- factory upgrade >= the buy-row level, buy ONE via the SAME server register path players use (charge AI treasury, then
//--- TkScudRegister which tags + registers + enforces the per-side cap). Server-authoritative; spawns the hull near the HQ.
WFBE_SE_FNC_IcbmTelAiBuy = {
	private ["_side","_sideText","_bought","_hfLvl","_needLvl","_upg","_rich","_surge","_funds","_buyFunds","_cost","_hq","_hqPos","_pos","_veh"];
	_side = _this select 0;
	if !(_side in [west, east, resistance]) exitWith {};
	if ((missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_BUY", 1]) <= 0) exitWith {};
	if !([_side] Call WFBE_SE_FNC_IcbmTelSideIsAI) exitWith {};
	if ((missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) <= 0) exitWith {};
	if (worldName != "Takistan") exitWith {};
	_sideText = str _side;

	//--- own < 1 bought SCUD? (research TEL doesn't count — this buys a mobile launcher.)
	_bought = count ([_side] Call WFBE_SE_FNC_TkScudPlatforms);
	if (_bought >= 1) exitWith {};

	//--- HEAVY factory upgrade >= the buy-row level. WFBE_UP_HEAVY is a core constant (Init_CommonConstants.sqf) always defined,
	//--- so it is used directly (mirrors AI_Commander.sqf's direct WFBE_UP_HEAVY use — no isNil guard needed / no phantom classref).
	_needLvl = missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_LEVEL", 3];
	_hfLvl = 0;
	_upg = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	if (typeName _upg == "ARRAY" && {WFBE_UP_HEAVY < count _upg}) then {_hfLvl = _upg select WFBE_UP_HEAVY};
	if (_hfLvl < _needLvl) exitWith {};

	//--- RICH signal: the AICOM econ-surge flag (logik) OR raw funds over the buy threshold.
	_funds    = _side Call GetAICommanderFunds;
	_buyFunds = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_BUY_FUNDS", 60000];
	private ["_logik"];
	_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
	_surge = if (isNil "_logik" || {isNull _logik}) then {false} else {_logik getVariable ["wfbe_aicom_econ_surge", false]};
	_rich  = _surge || {_funds > _buyFunds};
	if (!_rich) exitWith {};

	//--- affordability: don't buy if it would drop the treasury below one SAT shot (keeps a shot in reserve).
	_cost = missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_COST", 28000];
	if (_funds < (_cost + (missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000]))) exitWith {};

	_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
	if (isNull _hq) exitWith {};
	_hqPos = getPos _hq;
	_pos = [_hqPos, 55] Call WFBE_CO_FNC_GetEmptyPosition;
	if (typeName _pos != "ARRAY" || {count _pos < 2}) then {_pos = [(_hqPos select 0) + 40, (_hqPos select 1) + 40, 0]};

	//--- spawn the hull (same class as the research TEL / player buy row) and register it via the shared server path. We charge
	//--- the AI treasury FIRST (the register path only refunds a player TEAM on over-cap; passing grpNull team + our own charge
	//--- keeps the AI economy authoritative). If register refuses at cap it deletes the surplus (rare — we gate on _bought<1).
	_veh = createVehicle [(missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"]), [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
	if (isNull _veh) exitWith {
		["WARNING", Format ["Init_IcbmTel.sqf : [%1] AI SCUD buy — createVehicle FAILED at %2.", _sideText, _pos]] Call WFBE_CO_FNC_LogContent;
	};
	_veh setPos [_pos select 0, _pos select 1, 0];
	_veh setVehicleLock "LOCKED";
	_veh setDir (random 360);
	[_side, -_cost] Call ChangeAICommanderFunds;
	//--- register (grpNull team => no player refund path taken; our AI charge above is the debit). Cap enforced inside.
	[_veh, _side, grpNull, _cost] Call WFBE_SE_FNC_TkScudRegister;
	["INFORMATION", Format ["Init_IcbmTel.sqf : [%1] AI SCUD PURCHASED (cost %2, funds now %3, hfLvl %4).", _sideText, _cost, _side Call GetAICommanderFunds, _hfLvl]] Call WFBE_CO_FNC_LogContent;
	diag_log (Format ["AICOMSTAT|v2|EVENT|%1|%2|AI_SCUD_BUY|side=%1|cost=%3|funds=%4", _sideText, round (time / 60), _cost, _side Call GetAICommanderFunds]);
};

//--- SPAWNED LOOP: low-cadence AI-SCUD evaluator for all present AI-capable sides (west/east; GUER has no upgrade economy so
//--- it never passes the research gate — harmless to include). One cheap tick every WFBE_C_TK_SCUD_AI_TICK (120s); each side's
//--- eval self-gates. TK-only (worldName) + master flag WFBE_C_TK_SCUD_AI. Guarded so it never runs off-Takistan or when off.
if (worldName == "Takistan" && {(missionNamespace getVariable ["WFBE_C_TK_SCUD_AI", 1]) > 0}) then {
	[] spawn {
		private ["_tick","_sides","_s"];
		//--- let the AI commanders + platform registry warm up before the first evaluation.
		waitUntil {sleep 5; (!isNil "serverInitFull") || WFBE_GameOver};
		sleep 60;
		["INITIALIZATION", "Init_IcbmTel.sqf : AI SCUD evaluator loop ONLINE (Takistan, WFBE_C_TK_SCUD_AI=1)."] Call WFBE_CO_FNC_LogContent;
		diag_log ("AICOMSTAT|v2|EVENT|all|" + str (round (time / 60)) + "|AI_SCUD_LOOP|online");
		while {!WFBE_GameOver} do {
			_tick = missionNamespace getVariable ["WFBE_C_TK_SCUD_AI_TICK", 120];
			_sides = WFBE_PRESENTSIDES - [resistance];   //--- the two main AI-capable sides (GUER has no research economy).
			{
				_s = _x;
				//--- each side eval is fully self-guarded; wrap nothing else — a slow scan on one side must not stall the other.
				[_s] Call WFBE_SE_FNC_IcbmTelAiEval;
				//--- optional purchase pass (own sub-flag + rich/level gates inside).
				[_s] Call WFBE_SE_FNC_IcbmTelAiBuy;
			} forEach _sides;
			sleep _tick;
		};
		diag_log ("AICOMSTAT|v2|EVENT|all|" + str (round (time / 60)) + "|AI_SCUD_LOOP|offline (game over)");
	};
} else {
	["INFORMATION", Format ["Init_IcbmTel.sqf : AI SCUD evaluator SKIPPED (worldName=%1, WFBE_C_TK_SCUD_AI=%2).", worldName, missionNamespace getVariable ["WFBE_C_TK_SCUD_AI", 1]]] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Init_IcbmTel.sqf : land ICBM TEL functions compiled + ready."] Call WFBE_CO_FNC_LogContent;
