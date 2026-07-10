//--- Apply to: Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Server\Init\Init_Server.sqf
//--- (or the equivalent Init_Server.sqf under whichever mission the stresstest branch targets).
//--- Insert near the top, mirroring the existing HighClimb/AutoFlip worker-spawn pattern already
//--- there (lines 21-22 at the time this harness was built):
//---
//---   if (isServer) then { [] spawn Compile preprocessFileLineNumbers "Common\Functions\Common_AICOM_HighClimb.sqf" };
//---   if (isServer) then { [] spawn Compile preprocessFileLineNumbers "Common\Functions\Common_AICOM_AutoFlip.sqf" };
//---
//--- Server_DebugStressSpawn.sqf waits on 'commonInitComplete && townInit' internally (the same
//--- gate Init_Server.sqf itself blocks on later), so this hook is safe to place early -- exact
//--- placement relative to the rest of Init_Server.sqf does not matter.
//---
//--- This is documentation only: applying this snippet to the live mission source, and copying
//--- Server_DebugStressSpawn.sqf into that mission's Server\Debug\ folder, is a deploy-time step
//--- performed by pack_stresstest.py for a dedicated stresstest branch -- not part of this
//--- harness PR, and never wired into master's live init.

//--- STRESSTEST (Tools/Stresstest): mass-unit debug spawn hook. Inert unless
//--- WFBE_C_DEBUG_STRESS_SPAWN_GROUPS > 0 (Init_CommonConstants.snippet.sqf), which is never true
//--- outside a dedicated stresstest deploy.
if (isServer && {(missionNamespace getVariable ["WFBE_C_DEBUG_STRESS_SPAWN_GROUPS", 0]) > 0}) then {
	[] spawn Compile preprocessFileLineNumbers "Server\Debug\Server_DebugStressSpawn.sqf"
};
