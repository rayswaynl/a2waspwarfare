Private ['_aiTeamTemplateRequires','_aiTeamTemplateName','_aiTeamTemplates','_aiTeamTypes','_aiTeamUpgrades','_return','_side','_u'];

_side = _this;

//--- Overall Dump.
_return = ["West", "BIS_US", ["US_AH6XFlight","US_C130JFlight","US_MQ9Flight"]] Call Compile preprocessFile "Common\Config\Core_Squads\Squads_GetFactionGroups.sqf";
_aiTeamTemplates = _return select 0;
_aiTeamTemplateName = _return select 1;
_aiTeamTemplateRequires = _return select 2;
_aiTeamTypes = _return select 3;
_aiTeamUpgrades = _return select 4;

//--- Custom Groups.
_u		= ["M2A2_EP1"];
_u = _u + ["M2A2_EP1"];

_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - APC Platoon (Bradley)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

_u		= ["M6_EP1"];
_u = _u + ["M6_EP1"];

_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - Anti-Air Platoon"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

_u		= ["CH_47F_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];

_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Infantry CH-47F Squadron"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,0]];

//--- AICOM v2 ROSTER BOOST (Ray 2026-06-27, AI-COMMANDER-ONLY - appended to _aiTeamTemplates only, does NOT
//--- touch the shared squads / player options): heavier armor + an attack heli + a spec-ops squad so a
//--- 'strong' AI fields elite teams. Verified A2-OA classnames; gated behind TOP factory tiers so they
//--- appear occasionally (the cost-weighted AICOM founding draw fields them as tech + funds allow).
_u = ["M1A2_US_TUSK_MG_EP1"]; _u = _u + ["M1A2_US_TUSK_MG_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - MBT Platoon (M1A2 TUSK)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

_u = ["AH64D_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Attack Helicopter (AH-64D)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

_u = ["US_Delta_Force_TL_EP1"]; _u = _u + ["US_Delta_Force_MG_EP1"]; _u = _u + ["US_Delta_Force_Assault_EP1"]; _u = _u + ["US_Delta_Force_Assault_EP1"]; _u = _u + ["US_Delta_Force_M14_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Spec Ops (Delta Force)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[3,0,0,0]];

//--- AICOM v2 AIR PARITY (Ray 2026-06-27 "lots of choppers late-game, insertions + attack, BOTH sides"):
//--- the east (RU) roster is already air-rich; bring WEST up to match with troop insertions, light attack,
//--- an elite air-assault, and a combined transport+gunship escort. AI-commander-only, verified A2-OA classes,
//--- air-tier-gated. Dismount counts <= carrier cargo. The late-game air ramp (Init_CommonConstants) fields these heavily.
_u = ["UH60M_EP1"]; _u = _u + ["US_Soldier_TL_EP1"]; _u = _u + ["US_Soldier_AR_EP1"]; _u = _u + ["US_Soldier_LAT_EP1"]; _u = _u + ["US_Soldier_LAT_EP1"]; _u = _u + ["US_Soldier_Medic_EP1"]; _u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Infantry UH-60 Squadron"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

_u = ["AH6J_EP1"]; _u = _u + ["AH6J_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - AH-6 Little Bird Attack"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,1]];

_u = ["MH60S"]; _u = _u + ["US_Delta_Force_TL_EP1"]; _u = _u + ["US_Delta_Force_MG_EP1"]; _u = _u + ["US_Delta_Force_Assault_EP1"]; _u = _u + ["US_Delta_Force_Assault_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Delta Air Assault (MH-60)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

_u = ["UH60M_EP1"]; _u = _u + ["AH64D_EP1"]; _u = _u + ["US_Soldier_TL_EP1"]; _u = _u + ["US_Soldier_AR_EP1"]; _u = _u + ["US_Soldier_LAT_EP1"]; _u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - UH-60 Air Assault + AH-64 Escort"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATES", _side], _aiTeamTemplates];
missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATEREQUIRES", _side], _aiTeamTemplateRequires];
missionNamespace setVariable [Format["WFBE_%1AITEAMTYPES", _side], _aiTeamTypes];
missionNamespace setVariable [Format["WFBE_%1AITEAMUPGRADES", _side], _aiTeamUpgrades];
missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATEDESCRIPTIONS", _side], _aiTeamTemplateName];