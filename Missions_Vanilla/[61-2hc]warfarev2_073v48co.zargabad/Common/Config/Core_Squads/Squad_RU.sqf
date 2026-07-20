Private ['_aiTeamTemplateRequires','_aiTeamTemplateName','_aiTeamTemplates','_aiTeamTypes','_aiTeamUpgrades','_return','_side','_u'];

_side = _this;

//--- Overall Dump.
_return = ["East", "RU", ["RU_Pchela1TSquadron","RU_Ka52Squadron"]] Call Compile preprocessFile "Common\Config\Core_Squads\Squads_GetFactionGroups.sqf";
_aiTeamTemplates = _return select 0;
_aiTeamTemplateName = _return select 1;
_aiTeamTemplateRequires = _return select 2;
_aiTeamTypes = _return select 3;
_aiTeamUpgrades = _return select 4;

//--- Custom Groups. COMBINED-ARMS REBUILD 2026-06-14 (claude-gaming): replaces the old pure-armor
//--- "Tank Platoon (Light)" [T72,T72] that could not capture. EAST on Chernarus resolves to RU -> THIS file.
//--- Every type1/type2 template carries dismount infantry (cargo carrier + squad) so it can take towns;
//--- tanks always ride with a cargo-carrier escort. AA + Ka-52 kept as pure non-capturing support.
//--- Classes verified registered (Core_RU/Core_INS/Core_MVD/Core_Spetsnaz load unconditionally).

//--- (1) Infantry - Rifle Squad (pure infantry, captures as dismounts)
_u		= ["RU_Soldier_SL"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier"];
_u = _u + ["RU_Soldier2"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Rifle Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,0]];

//--- (2) Infantry - Spetsnaz Assault Team (elite, foot)
_u		= ["RUS_Soldier_TL"];
_u = _u + ["RUS_Soldier_GL"];
_u = _u + ["RUS_Soldier_Marksman"];
_u = _u + ["RUS_Soldier1"];
_u = _u + ["RUS_Soldier2"];
_u = _u + ["RUS_Soldier3"];
_u = _u + ["Ins_Soldier_AT"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Spetsnaz Assault Team"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[1,0,0,0]];

//--- (3) Infantry - Weapons Team (AT/AA)
_u		= ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_HAT"];
_u = _u + ["RU_Soldier_AA"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_Medic"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Weapons Team (AT/AA)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[1,0,0,0]];

//--- (4) Motorized - Kamaz Rifle Squad
_u		= ["Kamaz"];
_u = _u + ["RU_Soldier_SL"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier"];
_u = _u + ["RU_Soldier2"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - Kamaz Rifle Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,1,0,0]];

//--- (5) Motorized - Vodnik Patrol
_u		= ["GAZ_Vodnik_HMG"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - Vodnik Patrol"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,3,0,0]];

//--- (6) Motorized - Gun Truck Fire Support (UAZ_AGS30 paired with a Kamaz carrying the dismounts)
_u		= ["UAZ_AGS30_RU"];
_u = _u + ["Kamaz"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier"];
_u = _u + ["RU_Soldier2"];
_u = _u + ["RU_Soldier_Medic"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - Gun Truck Fire Support"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[1,1,0,0]];

//--- (7) Mechanized - BMP-2 Rifle Squad
_u		= ["BMP2_INS"];
_u = _u + ["RU_Soldier_SL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - BMP-2 Rifle Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

//--- (8) Mechanized - BTR-90 Rifle Squad (BTR90 is a factory-1 LIGHT unit -> type1)
_u		= ["BTR90"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_HAT"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - BTR-90 Rifle Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,3,0,0]];

//--- (9) Mechanized - BMP-3 Heavy Squad
_u		= ["BMP3"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - BMP-3 Heavy Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,2,0]];

//--- (10) Armor - Tank Platoon + BMP Escort (T72+T90 punch, BMP2 carries the dismounts that capture)
_u		= ["T72_RU"];
_u = _u + ["T90"];
_u = _u + ["BMP2_INS"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_HAT"];
_u = _u + ["RU_Soldier_Medic"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - Tank Platoon + BMP Escort"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,2,0]];

//--- (11) Armor - Heavy Tank + Mechanized Escort (T90 + BTR90 carrying dismounts)
_u		= ["T90"];
_u = _u + ["BTR90"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_HAT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - Heavy Tank + Mechanized Escort"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

//--- (12) Armor - Anti Air Platoon (PURE AA support, crew-only, cannot capture)
_u		= ["2S6M_Tunguska"];
_u = _u + ["ZSU_INS"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - Anti Air Platoon"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,2,0]];

//--- (13) Air - Infantry Mi-8 Squadron (air-assault cap force)
_u		= ["Mi17_Ins"];
_u = _u + ["MVD_Soldier_TL"];
_u = _u + ["MVD_Soldier_GL"];
_u = _u + ["MVD_Soldier_MG"];
_u = _u + ["MVD_Soldier_MG"];
_u = _u + ["MVD_Soldier_Marksman"];
_u = _u + ["MVD_Soldier_AT"];
_u = _u + ["MVD_Soldier_AT"];
_u = _u + ["MVD_Soldier_GL"];
_u = _u + ["MVD_Soldier_Medic"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Infantry Mi-8 Squadron"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

//--- (14) Air - Mi-8 Rocket Assault (armed transport that also caps)
_u		= ["Mi17_rockets_RU"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier"];     //--- B74.2 (Ray 2026-06-23): redundant RU_Soldier_AA -> rifleman (still loads of AA missile infantry; vehicle AA + the (3) Weapons Team manpad already cover air, halve the standalone AA bodies).
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Mi-8 Rocket Assault"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

//--- (15) Air - Ka-52 Attack Squadron (PURE gunships, 0 cargo, cannot capture)
_u		= ["Ka52Black"];
_u = _u + ["Ka52"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Ka-52 Attack Squadron"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

//--- ============================================================================
//--- ARCHETYPE EXPANSION 2026-06-14 (claude-gaming): +10 NEW RU archetypes with size-bump.
//--- Every template is pure-infantry OR a cargo-carrier-with-dismounts (no pure-armor).
//--- Cargo never overfilled (dismount count <= carrier transportSoldier). AGS/motorized gun
//--- trucks ride a Kamaz (large cargo) NOT GAZ_Vodnik_HMG. Factory tier in _aiTeamTypes matches
//--- the vehicle (0 inf / 1 light / 2 heavy / 3 air). Classes validated against
//--- Core_RU + Core_INS + Core_MVD + Core_Spetsnaz (all load unconditionally on Chernarus EAST=RU).
//--- ============================================================================

//--- (16) Infantry - Spetsnaz Recon Patrol (elite foot recon, captures as dismounts) [type0]
_u		= ["RUS_Soldier_TL"];
_u = _u + ["RUS_Soldier_Marksman"];
_u = _u + ["RUS_Soldier_GL"];
_u = _u + ["RUS_Soldier1"];
_u = _u + ["RUS_Soldier2"];
_u = _u + ["RUS_Soldier3"];
_u = _u + ["RUS_Soldier_Medic"];
_u = _u + ["Ins_Soldier_AT"];
_u = _u + ["RUS_Soldier1"];
_u = _u + ["RUS_Soldier2"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Spetsnaz Recon Patrol"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[1,0,0,0]];

//--- (17) Infantry - MVD Heavy Rifle Squad (heavy interior-troops squad, foot) [type0]
_u		= ["MVD_Soldier_TL"];
_u = _u + ["MVD_Soldier_MG"];
_u = _u + ["MVD_Soldier_GL"];
_u = _u + ["MVD_Soldier_Marksman"];
_u = _u + ["MVD_Soldier_AT"];
_u = _u + ["MVD_Soldier_AT"];
_u = _u + ["MVD_Soldier_Sniper"];
_u = _u + ["MVD_Soldier_MG"];
_u = _u + ["MVD_Soldier_GL"];
_u = _u + ["RU_Soldier_Medic"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - MVD Heavy Rifle Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[1,0,0,0]];

//--- (18) Motorized - AGS Gun Truck Section (UAZ AGS-30 fire-support + Kamaz carries the dismounts) [type1]
_u		= ["UAZ_AGS30_RU"];
_u = _u + ["Kamaz"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier"];
_u = _u + ["RU_Soldier_Medic"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - AGS Gun Truck Section"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[1,1,0,0]];

//--- (19) Motorized - Vodnik Mounted Rifle Squad (GAZ Vodnik transport carries the squad) [type1]
_u		= ["GAZ_Vodnik"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Motorized - Vodnik Mounted Rifle Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,2,0,0]];

//--- (20) Mechanized - BTR-90 Heavy Rifle Platoon (2x BTR90 carry a reinforced dismount squad) [type1]
_u		= ["BTR90"];
_u = _u + ["BTR90"];
_u = _u + ["RU_Soldier_SL"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_HAT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_AR"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - BTR-90 Heavy Rifle Platoon"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,true,false,false]];
_aiTeamTypes = _aiTeamTypes + [1];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,3,0,0]];

//--- (21) Mechanized - BMP-2 Heavy Platoon (2x BMP2 carry the dismounts, more punch) [type2]
_u		= ["BMP2_INS"];
_u = _u + ["BMP2_INS"];
_u = _u + ["RU_Soldier_SL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_Medic"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - BMP-2 Heavy Platoon"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];

//--- (22) Mechanized - BMP-3 Heavy Platoon (2x BMP3 punch, dismount squad caps) [type2]
_u		= ["BMP3"];
_u = _u + ["BMP3"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Mechanized - BMP-3 Heavy Platoon"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,2,0]];

//--- (23) Armor - Heavy Tank + Tunguska AA Escort + BMP carrier (T90 punch, 2S6 air-cover, BMP2 caps) [type2]
_u		= ["T90"];
_u = _u + ["2S6M_Tunguska"];
_u = _u + ["BMP2_INS"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_AR"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - Heavy Tank + Tunguska AA Escort"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

//--- (24) Air - Spetsnaz Mi-8 Air Assault (Mi-8 lifts an elite dismount squad that caps) [type3]
_u		= ["Mi17_Ins"];
_u = _u + ["RUS_Soldier_TL"];
_u = _u + ["RUS_Soldier_GL"];
_u = _u + ["RUS_Soldier_Marksman"];
_u = _u + ["RUS_Soldier1"];
_u = _u + ["RUS_Soldier2"];
_u = _u + ["RUS_Soldier3"];
_u = _u + ["RUS_Soldier_Medic"];
_u = _u + ["Ins_Soldier_AT"];
_u = _u + ["RUS_Soldier1"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Spetsnaz Mi-8 Air Assault"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

//--- (25) Air - Mi-8 Air Assault + Ka-52 Escort (Mi-8 carries the dismounts, Ka-52 escorts) [type3]
_u		= ["Mi17_Ins"];
_u = _u + ["Ka52"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_MG"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_HAT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Mi-8 Air Assault + Ka-52 Escort"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

//--- ============================================================================
//--- B66 PREMIUM CAPTURE-UNLOCK TEMPLATES (Ray 2026-06-21): 2 high-tier teams the AICOM picker
//--- can field once it owns the trigger town(s) (the picker implementer gates these on
//--- trigger-town ownership - this file only REGISTERS them in the same parallel-array shape).
//--- NOTE ON CLASSES: the B66 spec sketched ACR examples ("T72M4CZ", "RM70_ACR"). ACR is a
//--- SHELVED/ABSENT DLC on this server (see [[acr-shelved]] + Core_ACR.sqf:132-135: those classes
//--- log "DLC absent - skipped" ~70x and are NOT registered), so fielding them would spawn an empty/
//--- broken team. Substituted the registered RU equivalents that ARE in Core_RU/Units_CO_RU on this
//--- build: T90 (premium heavy tank) + BMP3 (heavy IFV carrier), and GRAD_RU (BM-21 Grad MLRS, the
//--- registered rocket-artillery battery). Both type 2 (HEAVY factory tier), matching the existing shape.
//--- ============================================================================

//--- (26) Armor - T-90 Spearhead (premium heavy tank punch + BMP-3 carrying the dismounts that capture) [type2]
_u		= ["T90"];
_u = _u + ["BMP3"];
_u = _u + ["RU_Soldier_TL"];
_u = _u + ["RU_Soldier_AR"];
_u = _u + ["RU_Soldier_GL"];
_u = _u + ["RU_Soldier_LAT"];
_u = _u + ["RU_Soldier_AT"];
_u = _u + ["RU_Soldier_HAT"];
_u = _u + ["RU_Soldier_Medic"];
_u = _u + ["RU_Soldier_AR"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - T-90 Spearhead"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

//--- (27) Artillery - Grad Rocket Battery (BM-21 Grad MLRS fire-support, crew-only - cannot capture) [type2]
_u		= ["GRAD_RU"];
_u = _u + ["GRAD_RU"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Artillery - Grad Rocket Battery"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,2,0]];

//--- AICOM v2 ROSTER BOOST (Ray 2026-06-27, AI-COMMANDER-ONLY - appended to _aiTeamTemplates only, does NOT
//--- touch the shared squads / player options): heavier armor + an attack heli + a heavy-weapons squad so a
//--- 'strong' AI fields elite teams. Verified A2-OA classnames; gated behind TOP factory tiers so they
//--- appear occasionally (the cost-weighted AICOM founding draw fields them as tech + funds allow).
_u = ["T90"]; _u = _u + ["T90"]; _u = _u + ["BMP3"]; _u = _u + ["RU_Soldier_SL"]; _u = _u + ["RU_Soldier_AR"]; _u = _u + ["RU_Soldier_AT"]; _u = _u + ["RU_Soldier_Medic"]; //--- wiki cross-check fix: armor platoon now carries a BMP-3 + dismount squad so it can CAPTURE (bare-armor can't flip a town).
_aiTeamTemplateName = _aiTeamTemplateName + ["Armor - MBT Platoon (T-90 + dismounts)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,3,0]];

_u = ["Ka52"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Attack Helicopter (Ka-52)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,2]];

_u = ["RU_Soldier_SL"]; _u = _u + ["RU_Soldier_MG"]; _u = _u + ["RU_Soldier_HAT"]; _u = _u + ["RU_Soldier_AT"]; _u = _u + ["RU_Soldier_Sniper"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Infantry - Heavy Weapons Squad"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[true,false,false,false]];
_aiTeamTypes = _aiTeamTypes + [0];
_aiTeamUpgrades = _aiTeamUpgrades + [[3,0,0,0]];

//--- AICOM v2 AIRFIELD JETS (Ray 2026-06-27): manned CAS/strike jets, fixed-wing -> auto-gated behind AIRFIELD
//--- ownership (AIR_REQUIRE_AIRFIELD) AND the 2h->5h jet time-ramp. Spawn on the captured airfield runway
//--- (AI_Commander_Teams jet runway-spawn). Pure gunships (no dismounts, cannot capture).
_u = ["Su39"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Su-25 CAS (Airfield)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

_u = ["Su34"];
_aiTeamTemplateName = _aiTeamTemplateName + ["Air - Su-34 Strike (Airfield)"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,false,true]];
_aiTeamTypes = _aiTeamTypes + [3];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,0,3]];

//--- AICOM SELF-PROPELLED ARTILLERY (Ray 2026-06-27): ONE BM-21 Grad battery per AI commander. NO tracked SP rocket-
//--- arty class is registered on this build (RU's only SP rocket arty is the WHEELED GRAD_RU); use it + name it
//--- honestly. LIGHT-tier-gated (unlocks at Light factory L4, matching GRAD_RU's tier), AI-only, crew-only -> fire
//--- support, cannot capture. Capped to 1 alive per side by the arty cap.
_u = ["GRAD_RU"];
_aiTeamTemplateName     = _aiTeamTemplateName     + ["Artillery - Grad SP Rocket Battery"];
_aiTeamTemplates        = _aiTeamTemplates        + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,true,false,false]];
_aiTeamTypes            = _aiTeamTypes            + [1];
_aiTeamUpgrades         = _aiTeamUpgrades         + [[0,4,0,0]];

missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATES", _side], _aiTeamTemplates];
missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATEREQUIRES", _side], _aiTeamTemplateRequires];
missionNamespace setVariable [Format["WFBE_%1AITEAMTYPES", _side], _aiTeamTypes];
missionNamespace setVariable [Format["WFBE_%1AITEAMUPGRADES", _side], _aiTeamUpgrades];
missionNamespace setVariable [Format["WFBE_%1AITEAMTEMPLATEDESCRIPTIONS", _side], _aiTeamTemplateName];
