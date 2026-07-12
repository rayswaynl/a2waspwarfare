/*
	Common_AsrFiredGuard.sqf
	Null-shooter entry guard for the OPTIONAL 3rd-party ASR AI mod (x, asr_ai, sys_aiskill).

	Live box RPT (build 89, 2026-07-04) shows a once-per-session script error inside the mod:
		"Error 0 elements provided, 3 expected" at the mod's nearEntities proximity scan
		(expression context [_shooter,_k]), file x\asr_ai\addons\sys_aiskill\fnc_fired.sqf line 118.
	Root cause: the mod's XEH fired handler can run for a shooter DELETED in the same frame
	(this mission trash-collects corpses/wrecks aggressively), so _shooter is objNull by the
	time the proximity scan runs -> zero-element position -> RPT error.

	Fix: wrap the mod's compiled global (CBA A2 naming: asr_ai_sys_aiskill_fnc_fired) with an
	entry null-guard; transparent pass-through otherwise. Per-machine and local - XEH invokes
	the global BY NAME on every shot, so the reassignment takes effect immediately. Inert when
	the mod is absent (local rig / vanilla clients): logs one line and exits. Idempotent: a
	second run exits before re-wrapping (re-wrap would self-recurse). If a future mod build
	renames the global, the "not present" RPT line below is the tell - re-point the wrap then.
	Correctness fix - ships unflagged per repo flag policy.
*/

if (!isNil "WFBE_ASR_FNC_FIRED_ORIG") exitWith {}; //--- Already wrapped.

if (isNil "asr_ai_sys_aiskill_fnc_fired") exitWith {
	["INFORMATION", "Common_AsrFiredGuard.sqf: ASR AI fired handler not present on this machine - guard not installed."] Call WFBE_CO_FNC_LogContent;
};

WFBE_ASR_FNC_FIRED_ORIG = asr_ai_sys_aiskill_fnc_fired;
asr_ai_sys_aiskill_fnc_fired = {
	if (isNull (_this select 0)) exitWith {};
	_this call WFBE_ASR_FNC_FIRED_ORIG
};

["INFORMATION", "Common_AsrFiredGuard.sqf: null-shooter guard wrapped asr_ai_sys_aiskill_fnc_fired."] Call WFBE_CO_FNC_LogContent;
