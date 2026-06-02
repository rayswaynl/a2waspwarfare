//============================================================================
//  [CLAUDE FEATURES - REMOVABLE]   Zargabad fun-mechanic features by Claude
//  ---------------------------------------------------------------------------
//  Single launch point for all of Claude's add-on Zargabad features, kept
//  separate from the core mission so they are trivial to remove or toggle.
//
//  REMOVE ALL : delete the whole Server\Module\Claude\ folder + the single
//               execVM line for this file in Server\Init\Init_Server.sqf.
//  REMOVE ONE : comment its line below and/or set its WFBE_C_CLAUDE_*_ENABLED
//               toggle to 0 (toggles default to 1 = on).
//
//  Solo feature set (user brief: one <=100, one <=250, one <=500 LOC):
//============================================================================
if (!isServer) exitWith {};

[] execVM "Server\Module\Claude\Claude_Sandstorm.sqf";        //--- #1 (<=100) Haboob sandstorm  [DONE]
// [] execVM "Server\Module\Claude\Claude_Warlord.sqf";       //--- #2 (<=250) HVT/Warlord hunt  [pending]
// [] execVM "Server\Module\Claude\Claude_SupplyConvoy.sqf";  //--- #3 (<=500) supply convoy     [pending]

["INITIALIZATION", "Claude_Features_Init.sqf: Claude Zargabad add-on features launched."] call WFBE_CO_FNC_LogContent;
