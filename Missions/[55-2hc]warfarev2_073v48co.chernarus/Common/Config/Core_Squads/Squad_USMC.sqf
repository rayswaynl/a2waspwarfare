Private ['_aiTeamTemplateRequires','_aiTeamTemplateName','_aiTeamTemplates','_aiTeamTypes','_aiTeamUpgrades','_return','_side','_u'];

_side = _this;

//--- Overall Dump.
_return = ["West", "USMC", ["USMC_MQ9Squadron","USMC_FRTeam_Razor"]] Call Compile preprocessFile "Common\Config\Core_Squads\Squads_GetFactionGroups.sqf";
_aiTeamTemplates = _return select 0;
_aiTeamTemplateName = _return select 1;
_aiTeamTemplateRequires = _return select 2;
_aiTeamTypes = _return select 3;
_aiTeamUpgrades = _return select 4;

//--- Custom Groups.
//--- COMBINED-ARMS REBUILD 2026-06-14 (claude-gaming): pure "Armor - M1A1 Section" (2 empty tanks that
//--- can't capture) REMOVED. WEST on Chernarus resolves to US_Camo -> THIS file. Every type1/type2 template
//--- now carries dismount infantry (cargo carrier + squad) so it can take towns; tanks always ride with an
//--- escort carrier. Classes verified registered (Core_US + Core_USMC load unconditionally). Variety:
//--- infantry / weapons / AT / recon / motorized / mechanized / armor+escort / air-assault / mobile-AA.

//--- Infantry - Rifle Squad (Light) [type0]
_u		= ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Rifle Squad (Light)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[2,0,0,0]];

//--- Infantry - Weapons Squad [type0]
_u		= ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_MG_EP1"];
_u = _u + ["US_Soldier_AMG_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_AAT_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Weapons Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[3,0,0,0]];

//--- Infantry - Anti-Tank Section [type0]
_u		= ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_HAT_EP1"];
_u = _u + ["US_Soldier_AHAT_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Marksman_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Anti-Tank Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[3,0,0,0]];

//--- Motorized - Rifle Squad (MTVR) [type1]
_u		= ["MTVR_DES_EP1"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_MG_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - Rifle Squad (MTVR)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,1,0,0]];

//--- Motorized - HMMWV Recon Section [type1]
_u		= ["HMMWV_M1035_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_Spotter_EP1"];
_u = _u + ["US_Soldier_Marksman_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - HMMWV Recon Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,2,0,0]];

//--- Motorized - Gun Truck Section (M2) [type1]
_u		= ["HMMWV_M1151_M2_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - Gun Truck Section (M2)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,2,0,0]];

//--- Mechanized - Stryker Rifle Squad (ICV M2) [type2]
_u		= ["M1126_ICV_M2_EP1"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - Stryker Rifle Squad (ICV M2)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

//--- Mechanized - Bradley Rifle Squad (M2A2) [type2]
_u		= ["M2A2_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - Bradley Rifle Squad (M2A2)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

//--- Mechanized - Bradley A3 Rifle Squad (M2A3) [type2]
_u		= ["M2A3_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - Bradley A3 Rifle Squad (M2A3)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,2,0]];

//--- Armor - Abrams Team + Stryker Escort [type2] (tank ALWAYS bundled with a cargo carrier + dismounts)
_u		= ["M1A1_US_DES_EP1"];
_u = _u + ["M1126_ICV_M2_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - Abrams Team + Stryker Escort"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

//--- Armor - TUSK Heavy + Bradley Escort [type2]
_u		= ["M1A2_US_TUSK_MG_EP1"];
_u = _u + ["M2A2_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - TUSK Heavy + Bradley Escort"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,4,0]];

//--- Air - Air Assault Squad (CH-47F) [type3]
_u		= ["CH_47F_EP1"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_HAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Air Assault Squad (CH-47F)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,1]];

//--- Air - Little Bird Assault (MH-6J carries dismounts, AH-6J escorts) [type3]
_u		= ["AH6J_EP1"];
_u = _u + ["MH6J_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Little Bird Assault (MH-6J + AH-6J)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

//--- Motorized - Mobile AA Section (Avenger + MTVR with AA team) [type1]
_u		= ["HMMWV_Avenger_DES_EP1"];
_u = _u + ["MTVR_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AA_EP1"];
_u = _u + ["US_Soldier_EP1"];     //--- B74.2 (Ray 2026-06-23): 2x AA infantry -> 1x AA + rifleman (still loads of AA missile infantry; keep the Avenger + 1 manpad, halve the standalone AA bodies).
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - Mobile AA Section (Avenger)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,4,0,0]];

_u		= ["UH1Y"];
_u = _u + ["USMC_Soldier_TL"];
_u = _u + ["USMC_Soldier_AR"];
_u = _u + ["USMC_Soldier_LAT"];
_u = _u + ["USMC_Soldier_Medic"];
_u = _u + ["USMC_Soldier"];
_u = _u + ["USMC_Soldier"];
_u = _u + ["USMC_Soldier"];

_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Infantry UH1Y Squadron"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,1]];

_u		= ["MH60S"];
_u = _u + ["USMC_Soldier_TL"];
_u = _u + ["USMC_Soldier_MG"];
_u = _u + ["USMC_Soldier_AT"];
_u = _u + ["USMC_Soldier_Medic"];
_u = _u + ["USMC_Soldier"];
_u = _u + ["USMC_Soldier"];
_u = _u + ["USMC_Soldier"];

_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Infantry MH-60S Squadron"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

//--- ============================================================================
//--- ARCHETYPE EXPANSION 2026-06-14 (claude-gaming): +10 NEW US archetypes with size-bump.
//--- Every template is pure-infantry OR a cargo-carrier-with-dismounts (no pure-armor).
//--- Cargo never overfilled (dismount count <= carrier transportSoldier). Factory tier in
//--- _aiTeamTypes matches the vehicle (0 inf / 1 light / 2 heavy / 3 air). Classes validated
//--- against Core_US + Core_USMC (both load unconditionally on Chernarus WEST=US_Camo).
//--- ============================================================================

//--- Infantry - Stinger MANPADS Team (pure infantry AA, captures as dismounts) [type0]
_u		= ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_AA_EP1"];
_u = _u + ["US_Soldier_EP1"];     //--- B74.1 (Ray 2026-06-23): 2x Stinger -> 1x Stinger + rifleman (spam less AA infantry; the team keeps real AA, just half the bodies).
_u = _u + ["US_Soldier_AAR_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Stinger MANPADS Team"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[3,0,0,0]];

//--- Infantry - Combat Engineer Squad [type0]
_u		= ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_Engineer_EP1"];
_u = _u + ["US_Soldier_Engineer_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_MG_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Combat Engineer Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[3,0,0,0]];

//--- Infantry - Sniper Recon Patrol (foot recon, captures as dismounts) [type0]
_u		= ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_Sniper_EP1"];
_u = _u + ["US_Soldier_Spotter_EP1"];
_u = _u + ["US_Soldier_Marksman_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Sniper Recon Patrol"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[3,0,0,0]];

//--- Motorized - CROWS ATV Scout Section (CROWS gun-truck + ATV outriders carry the dismounts) [type1]
_u		= ["HMMWV_M998_crows_M2_DES_EP1"];
_u = _u + ["ATV_US_EP1"];
_u = _u + ["ATV_US_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_Spotter_EP1"];
_u = _u + ["US_Soldier_Marksman_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - CROWS ATV Scout Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,2,0,0]];

//--- Motorized - MK19 Gun Truck Section (MK19 fire-support + MTVR carries the dismounts) [type1]
_u		= ["HMMWV_MK19_DES_EP1"];
_u = _u + ["MTVR_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_MG_EP1"];
_u = _u + ["US_Soldier_AMG_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - MK19 Gun Truck Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,2,0,0]];

//--- Mechanized - Stryker ATGM Platoon (M1135 ATGM punch, 2x ICV carry the dismounts) [type2]
_u		= ["M1135_ATGMV_EP1"];
_u = _u + ["M1126_ICV_M2_EP1"];
_u = _u + ["M1126_ICV_M2_EP1"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - Stryker ATGM Platoon"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

//--- Mechanized - AAV Assault Squad (amphibious AAV carries a full reinforced dismount squad) [type2]
_u		= ["AAV"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_MG_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - AAV Assault Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

//--- Air - UH-60M Air Assault Squad (Black Hawk lift, full dismount squad caps) [type3]
_u		= ["UH60M_EP1"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_HAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - UH-60M Air Assault Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,1]];

//--- Air - Osprey Air Assault (MV-22 lifts a reinforced squad that caps) [type3]
_u		= ["MV22"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_MG_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_HAT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Osprey Air Assault (MV-22)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,1]];

//--- Air - Apache + Osprey Air Assault (AH-64D escorts, MV-22 carries the dismounts that cap) [type3]
_u		= ["AH64D_EP1"];
_u = _u + ["MV22"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Apache + Osprey Air Assault"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

//--- ===== C8 ROSTER EXPANSION (owner-approved 2026-07-27) =====

//--- Infantry - Urban Assault / CQB Squad [type0]
_u		= ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_GL_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Urban Assault / CQB Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[2,0,0,0]];

//--- Motorized - HMMWV SOV Raider [type1]
_u		= ["HMMWV_M998A2_SOV_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - HMMWV SOV Raider"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,1,0,0]];

//--- AICOM naval-template admission is held behind WFBE_C_AICOM_NAVAL_TEMPLATES until
//--- a water-aware founder/route exists.  These classes remain in Core_USMC.sqf and
//--- Units_* for player purchase and other explicitly water-aware callers.
if ((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_TEMPLATES", 0]) > 0) then {
//--- Motorized - RHIB Coastal Scout [type1]
_u		= ["RHIB"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_Spotter_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - RHIB Coastal Scout"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,1,0,0]];
};

//--- Motorized - HMMWV M2 QRF Pair [type1]
_u		= ["HMMWV_M2"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - HMMWV M2 QRF Pair"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,1,0,0]];

//--- Motorized - TOW HMMWV AT Section [type1]
_u		= ["HMMWV_TOW_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - TOW HMMWV AT Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,3,0,0]];

//--- Mechanized - LAV-25 Scout-Strike Section [type2]
_u		= ["LAV25"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_Spotter_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - LAV-25 Scout-Strike Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

if ((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_TEMPLATES", 0]) > 0) then {
//--- Mechanized - RHIB2Turret Coastal Raider [type2]
_u		= ["RHIB2Turret"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_MG_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - RHIB2Turret Coastal Raider"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];
};

//--- Mechanized - M1135 ATGM Ambush Team [type2]
_u		= ["M1135_ATGMV_EP1"];
_u = _u + ["HMMWV_M1151_M2_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - M1135 ATGM Ambush Team"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

//--- Mechanized - Stryker Engineer Breach Section [type2]
_u		= ["M1126_ICV_M2_EP1"];
_u = _u + ["US_Soldier_SL_EP1"];
_u = _u + ["US_Soldier_Engineer_EP1"];
_u = _u + ["US_Soldier_Engineer_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - Stryker Engineer Breach Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

//--- Mechanized - M6 Linebacker AA Section [type2] (escort carrier added for capture-capable dismounts, C8 doctrine)
_u		= ["M6_EP1"];
_u = _u + ["HMMWV_M1151_M2_DES_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AA_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - M6 Linebacker AA Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,4,0]];

//--- Mechanized - Stryker MGS Breakthrough Section [type2]
_u		= ["M1128_MGS_EP1"];
_u = _u + ["M1126_ICV_M2_EP1"];
_u = _u + ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AT_EP1"];
_u = _u + ["US_Soldier_Medic_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - Stryker MGS Breakthrough Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,4,0]];

//--- Infantry - Fire Team (Rapid Response) [type0]
_u		= ["US_Soldier_TL_EP1"];
_u = _u + ["US_Soldier_AR_EP1"];
_u = _u + ["US_Soldier_LAT_EP1"];
_u = _u + ["US_Soldier_EP1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Fire Team (Rapid Response)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[1,0,0,0]];

//--- WEST FIXED-WING (research finding 2026-07-28, "WEST cannot found a fixed-wing bomber on Chernarus"):
//--- Root_US_Camo.sqf compiles ONLY this file for WEST and it carried zero Plane team templates, while
//--- Squad_OA_US.sqf:124-125,164-165 (A-10 / AV-8B jet rows) never loads on Chernarus at all. Two Plane
//--- templates modelled directly on those OA_US rows, gated dark by default. Admission for a founded
//--- team still flows through the EXISTING AI_Commander_Teams.sqf / AI_Commander_AssignTypes.sqf
//--- isKindOf-Plane + airfield-ownership + jet time-ramp gates (unchanged) - this only makes the
//--- templates visible to that pipeline; it invents no new admission logic. Flag off = this whole
//--- block never executes, so the four roster arrays stay byte-identical to HEAD.
if (missionNamespace getVariable ["WFBE_C_AICOM_WEST_JETS", 0] > 0) then {
	_u		= ["A10_US_EP1"];
	_aiTeamTemplateName = _aiTeamTemplateName + ["Air - A-10 CAS (Airfield)"];
	_aiTeamTemplates = _aiTeamTemplates + [_u];
	_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
	_aiTeamTypes = _aiTeamTypes + [3];
	_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

	_u		= ["AV8B2"];
	_aiTeamTemplateName = _aiTeamTemplateName + ["Air - AV-8B Strike"];
	_aiTeamTemplates = _aiTeamTemplates + [_u];
	_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
	_aiTeamTypes = _aiTeamTypes + [3];
	_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];
};

missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATES", _side], _aiTeamTemplates];
missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATEREQUIRES", _side], _aiTeamTemplateRequires];
missionNamespace setVariable [Format["WFBE_%1AITEAMTYPES", _side], _aiTeamTypes];
missionNamespace setVariable [Format["WFBE_%1AITEAMUPGRADES", _side], _aiTeamUpgrades];
missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATEDESCRIPTIONS", _side], _aiTeamTemplateName];
