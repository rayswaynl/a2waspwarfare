//--- Apply to: Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Common\Init\Init_CommonConstants.sqf
//--- (or the equivalent Init_CommonConstants.sqf under whichever mission the stresstest branch
//--- targets). Insert near the end of the file, alongside the other flag registrations (e.g.
//--- right after the WFBE_C_SCUD_SPEED_CAP_KMH line, before the closing
//--- '["INITIALIZATION", "Init_CommonConstants.sqf: Constants are defined."] Call WFBE_CO_FNC_LogContent;'
//--- line). Mirrors the existing 'if (isNil "WFBE_C_...")' idiom used for every other flag.
//---
//--- Deliberately NOT added to Rsc\Parameters.hpp -- this must never be reachable as a lobby
//--- toggle. It only exists/activates on a dedicated stresstest branch that applies this patch.
//---
//--- This is documentation only: applying this snippet to the live mission source is a
//--- deploy-time step for a dedicated stresstest branch, not part of this harness PR.

//--- STRESSTEST (Tools/Stresstest): mass-unit debug spawn gate. 0 (default) = off, byte-identical
//--- to not having Tools/Stresstest/Server_DebugStressSpawn.sqf at all. N = number of extra debug
//--- AI groups to spawn, staggered, at match init. Hard-capped at 200 inside the spawn script
//--- regardless of this value. See Tools/Stresstest/README.md for the full flow.
	if (isNil "WFBE_C_DEBUG_STRESS_SPAWN_GROUPS") then {WFBE_C_DEBUG_STRESS_SPAWN_GROUPS = 0};
