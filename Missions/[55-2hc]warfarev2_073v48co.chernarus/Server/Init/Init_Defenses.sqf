/* Structures */
//--- Barracks: enclosed HESCO compound with a front walking gap (infantry factory — no vehicle egress to block).
//--- Cleaner + FPS-lighter than scattered H-barriers (8 wall sections). Footprint/fit needs an in-engine check.
missionNamespace setVariable ['WFBE_NEURODEF_BARRACKS_WALLS',[
	['Base_WarfareBBarrier5x',[-7,11,0],0],['Base_WarfareBBarrier5x',[7,11,0],0],
	['Base_WarfareBBarrier5x',[-7,-11,0],0],['Base_WarfareBBarrier5x',[7,-11,0],0],
	['Base_WarfareBBarrier5x',[-11,-5,0],90],['Base_WarfareBBarrier5x',[-11,5,0],90],
	['Base_WarfareBBarrier5x',[11,-5,0],90],['Base_WarfareBBarrier5x',[11,5,0],90]
]];

missionNamespace setVariable ['WFBE_NEURODEF_LIGHT_WALLS',[
	['Land_HBarrier_large',[10,-1,0],90],
	['Land_HBarrier_large',[10,9,0],-90],
	['Land_HBarrier_large',[10,-8.5,0],90],
	['Land_HBarrier_large',[7,-12,0],180],
	['Land_HBarrier_large',[-7,-12,0],180],
	['Land_HBarrier_large',[7,12,0],180],
	['Land_HBarrier_large',[-7,12,0],180],
	['Land_HBarrier_large',[-11,-9,0],90],
	['Land_HBarrier_large',[-11,6,0],90],
	['Land_HBarrier_large',[-11,9,0],90]
]];

missionNamespace setVariable ['WFBE_NEURODEF_COMMANDCENTER_WALLS',[
	['Land_HBarrier_large',[4,-3.5,0],90],
	['Land_HBarrier_large',[4,4,0],90],
	['Land_HBarrier_large',[1,7.5,0],180],
	['Land_HBarrier_large',[-2.5,7.5,0],180],
	['Land_HBarrier_large',[-5.5,4,0],90],
	['Land_HBarrier_large',[-5.5,-3.5,0],90],
	['Land_HBarrier5',[4,-6.5,0],180]
]];

missionNamespace setVariable ['WFBE_NEURODEF_SERVICEPOINT_WALLS',[

]];

//--- AARadar intentionally has no auto walls. It should stay a plain radar structure.
missionNamespace setVariable ['WFBE_NEURODEF_AARADAR_WALLS',[

]];

//--- Shielded HQ walls (WDDM: hq_concrete_walk_exit), tight funnel layout from PR8 live test.
missionNamespace setVariable ['WFBE_NEURODEF_HEADQUARTERS_WALLS',[
	['Concrete_Wall_EP1',[-4.4,6.1,0],0],
	['Concrete_Wall_EP1',[-2.2,6.1,0],0],
	['Concrete_Wall_EP1',[0,6.1,0],0],
	['Concrete_Wall_EP1',[2.2,6.1,0],0],
	['Concrete_Wall_EP1',[4.4,6.1,0],0],
	['Concrete_Wall_EP1',[-6.1,-4.4,0],90],
	['Concrete_Wall_EP1',[-6.1,-2.2,0],90],
	['Concrete_Wall_EP1',[-6.1,0,0],90],
	['Concrete_Wall_EP1',[-6.1,2.2,0],90],
	['Concrete_Wall_EP1',[-6.1,4.4,0],90],
	['Concrete_Wall_EP1',[6.1,-4.4,0],90],
	['Concrete_Wall_EP1',[6.1,-2.2,0],90],
	['Concrete_Wall_EP1',[6.1,0,0],90],
	['Concrete_Wall_EP1',[6.1,2.2,0],90],
	['Concrete_Wall_EP1',[6.1,4.4,0],90],
	['Concrete_Wall_EP1',[-4.4,-6.1,0],0],
	['Concrete_Wall_EP1',[-2.2,-6.1,0],0],
	['Concrete_Wall_EP1',[2.2,-6.1,0],0],
	['Concrete_Wall_EP1',[4.4,-6.1,0],0],
	['Land_CncBlock_Stripes',[-0.9,-7.0,0],335],
	['Land_CncBlock_Stripes',[0.9,-7.0,0],25],
	['Land_CncBlock_Stripes',[-2.5,-5.8,0],325],
	['Land_CncBlock_Stripes',[2.5,-5.8,0],35]
]];

missionNamespace setVariable ['WFBE_NEURODEF_HEAVY_WALLS',[
	['Land_HBarrier_large',[14,-1,0],90],
	['Land_HBarrier_large',[14,9,0],-90],
	['Land_HBarrier_large',[14,-8.5,0],90],
	['Land_HBarrier_large',[14,-11,0],90],
	['Land_HBarrier_large',[11,-14.5,0],180],
	['Land_HBarrier_large',[-3,-14.5,0],180],
	['Land_HBarrier_large',[-10.5,-14.5,0],180],
	['Land_HBarrier_large',[-14,-11,0],90],
	['Land_HBarrier_large',[-14,4,0],90],
	['Land_HBarrier_large',[-14,9.5,0],90],
	['Land_HBarrier_large',[11,13,0],180],
	['Land_HBarrier_large',[-4,13,0],180],
	['Land_HBarrier_large',[-11,13,0],-180]
]];

missionNamespace setVariable ['WFBE_NEURODEF_AIRCRAFT_WALLS',[
	['Land_HBarrier_large',[10,-1,0],90],
	['Land_HBarrier_large',[10,9,0],-90],
	['Land_HBarrier_large',[10,-8.5,0],90],
	['Land_HBarrier_large',[7,-12,0],180],
	['Land_HBarrier_large',[-7,-12,0],180],
	['Land_HBarrier_large',[7,12,0],180],
	['Land_HBarrier_large',[-7,12,0],180],
	['Land_HBarrier_large',[-11,-9,0],90],
	['Land_HBarrier_large',[-11,6,0],90],
	['Land_HBarrier_large',[-11,9,0],90]
]];

missionNamespace setVariable ['WFBE_NEURODEF_MG',[
	[if (WF_A2_Vanilla) then {'Land_fortified_nest_small'} else {'Land_fortified_nest_small_EP1'},[0.25,0,0],180],
	['Land_fort_bagfence_corner',[-1,-3,0],0]
]];

missionNamespace setVariable ['WFBE_NEURODEF_AAPOD',[
	['Land_fort_bagfence_round',[0,2,0],0],
	['Land_fort_bagfence_long',[-2.8,-1.7,0],90],
	['Land_fort_bagfence_long',[2.8,-1.7,0],90],
	['Land_fort_bagfence_long',[1.4,-5.5,0],0],
	['Land_fort_bagfence_corner',[-1.8,-5,0],0]
]];

//=============================================================================
// WDDM commander positions (Stage 1) — composition templates authored in the
// WDDM editor (rayswaynl/WDDM). Spawned by Server\Functions\Server_ConstructPosition.sqf
// when a commander builds the matching anchor (see WFBE_POSITION_* maps below).
// Format per entry: ['classname',[xOffset,yOffset,zOffset],relativeDir]. Z is flattened to ground.
//=============================================================================

//--- Modular base-wall prefabs (faction-neutral, unmanned) ---
missionNamespace setVariable ['WFBE_NEURODEF_WALL_STRAIGHT',[
	['Land_HBarrier_large',[-7.5,0,0],0],['Land_HBarrier_large',[-2.5,0,0],0],
	['Land_HBarrier_large',[2.5,0,0],0],['Land_HBarrier_large',[7.5,0,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_WALL_CORNER',[
	['Land_HBarrier3',[0,0,0],0],
	['Land_HBarrier_large',[5,0,0],0],['Land_HBarrier_large',[10,0,0],0],
	['Land_HBarrier_large',[0,5,0],90],['Land_HBarrier_large',[0,10,0],90]
]];
missionNamespace setVariable ['WFBE_NEURODEF_WALL_GATE',[
	['Land_HBarrier_large',[-10,0,0],0],['Land_HBarrier_large',[-5,0,0],0],
	['Land_HBarrier_large',[5,0,0],0],['Land_HBarrier_large',[10,0,0],0],
	['Hedgehog',[-2.7,0,0],0],['Hedgehog',[2.7,0,0],0]
]];

//--- AA position (LIGHT tier, 2 AI) — dispersed twin AA; camo nets sit OFFSET behind the launchers so they never block upward fire ---
missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_WEST',[
	['Stinger_Pod_US_EP1',[-5,3,0],340],['Stinger_Pod_US_EP1',[5,3,0],20],
	['Land_fort_bagfence_round',[-5,3,0],0],['Land_fort_bagfence_round',[5,3,0],0],
	['Land_CamoNetVar_NATO',[-5,0,0],0],['Land_CamoNetVar_NATO',[5,0,0],0],
	['USLaunchers_EP1',[0,-2,0],0],
	['Land_HBarrier_large',[-8,1,0],90],['Land_HBarrier_large',[8,1,0],90],
	['Fort_RazorWire',[0,5,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_EAST',[
	['ZU23_TK_EP1',[-5,3,0],340],['Igla_AA_pod_TK_EP1',[5,3,0],20],
	['Land_fort_bagfence_round',[-5,3,0],0],['Land_fort_bagfence_round',[5,3,0],0],
	['Land_CamoNet_EAST',[-5,0,0],0],['Land_CamoNet_EAST',[5,0,0],0],
	['TKVehicleBox_EP1',[0,-2,0],0],
	['Land_HBarrier_large',[-8,1,0],90],['Land_HBarrier_large',[8,1,0],90],
	['Fort_RazorWire',[0,5,0],0]
]];

//--- Artillery position (HEAVY tier, 4 AI) — 3-gun battery + rear MG security. Guns kept CLEAR of overhead cover (high-angle fire); concealment nets are at the REAR only ---
missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_WEST',[
	['M119_US_EP1',[-9,4,0],0],['M119_US_EP1',[0,5,0],0],['M119_US_EP1',[9,4,0],0],
	['USBasicAmmunitionBox_EP1',[-9,-1,0],0],['USBasicAmmunitionBox_EP1',[0,0,0],0],['USBasicAmmunitionBox_EP1',[9,-1,0],0],
	['Land_fort_bagfence_long',[-13,3,0],90],['Land_fort_bagfence_long',[13,3,0],90],
	['Land_fort_bagfence_long',[-6,-3,0],0],['Land_fort_bagfence_long',[6,-3,0],0],
	['M2StaticMG',[0,-5,0],180],['Land_fort_bagfence_round',[0,-5,0],0],
	['Land_CamoNetVar_NATO',[-5,-2,0],0],['Land_CamoNetVar_NATO',[5,-2,0],0],
	['Fort_RazorWire',[-8,-7,0],0],['Fort_RazorWire',[8,-7,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_EAST',[
	['D30_TK_EP1',[-9,4,0],8],['D30_TK_EP1',[0,5,0],0],['D30_TK_EP1',[9,4,0],352],
	['TKBasicAmmunitionBox_EP1',[-9,-1,0],0],['TKBasicAmmunitionBox_EP1',[0,0,0],0],['TKBasicAmmunitionBox_EP1',[9,-1,0],0],
	['Land_HBarrier_large',[-13,3,0],90],['Land_HBarrier_large',[13,3,0],90],
	['Land_HBarrier_large',[-9,-2,0],0],['Land_HBarrier_large',[-3,-2,0],0],['Land_HBarrier_large',[3,-2,0],0],['Land_HBarrier_large',[9,-2,0],0],
	['DSHKM_TK_INS_EP1',[0,-5,0],180],['Land_fort_bagfence_round',[0,-5,0],0],
	['Land_CamoNet_EAST',[-5,-3.5,0],0],['Land_CamoNet_EAST',[5,-3.5,0],0],
	['Hedgehog',[-7,-7,0],0],['Hedgehog',[7,-7,0],0]
]];

//--- Mixed position (LIGHT tier, 2 AI) — compact MG + AT crossfire, angled for interlocking fire (no artillery) ---
missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_WEST',[
	['M2StaticMG',[-5,3,0],340],['TOW_TriPod_US_EP1',[5,3,0],20],
	['Land_fort_bagfence_round',[-5,3,0],0],['Land_fort_bagfence_round',[5,3,0],0],
	['USBasicAmmunitionBox_EP1',[0,-2,0],0],
	['Land_fort_bagfence_long',[-7,0,0],0],['Land_fort_bagfence_long',[7,0,0],0],
	['Fort_RazorWire',[0,5,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_EAST',[
	['DSHKM_TK_INS_EP1',[-5,3,0],340],['SPG9_TK_INS_EP1',[5,3,0],20],
	['Land_fort_bagfence_round',[-5,3,0],0],['Land_fort_bagfence_round',[5,3,0],0],
	['TKBasicAmmunitionBox_EP1',[0,-2,0],0],
	['Land_fort_bagfence_long',[-7,0,0],0],['Land_fort_bagfence_long',[7,0,0],0],
	['Fort_RazorWire',[0,5,0],0]
]];

//--- HEAVY-tier counterparts + ARTY light: gives each manned role a true light/heavy buildable.
//--- Heavy AA/Mixed reuse the original 4-AI compositions; ARTY light is a single clear-overhead gun.
missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_HEAVY_WEST',[
	['Stinger_Pod_US_EP1',[-8,6,0],330],['Stinger_Pod_US_EP1',[0,8,0],0],['Stinger_Pod_US_EP1',[8,6,0],30],
	['Land_fort_bagfence_round',[-8,4.4,0],0],['Land_fort_bagfence_round',[0,6.2,0],0],['Land_fort_bagfence_round',[8,4.4,0],0],
	['M2StaticMG',[0,-4,0],180],['Land_fort_bagfence_round',[0,-6.2,0],0],
	['USLaunchers_EP1',[-4,2,0],0],['USLaunchers_EP1',[4,2,0],0],
	['Land_CamoNetVar_NATO',[-4,6,0],0],['Land_CamoNetVar_NATO',[4,6,0],0],
	['Fort_RazorWire',[-7,-6,0],0],['Fort_RazorWire',[7,-6,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_HEAVY_EAST',[
	['ZU23_TK_EP1',[-7,5,0],350],['ZU23_TK_EP1',[7,5,0],10],['Igla_AA_pod_TK_EP1',[0,7,0],0],
	['DSHKM_TK_INS_EP1',[0,-4,0],180],
	['TKVehicleBox_EP1',[-5,1,0],0],['TKVehicleBox_EP1',[5,1,0],0],
	['Land_HBarrier_large',[-11,4,0],90],['Land_HBarrier_large',[11,4,0],90],
	['Land_HBarrier_large',[-6,-2,0],0],['Land_HBarrier_large',[0,-2,0],0],['Land_HBarrier_large',[6,-2,0],0],
	['Hedgehog',[-4,-6,0],0],['Hedgehog',[4,-6,0],0],['Fort_RazorWire',[0,-7,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_HEAVY_WEST',[
	['M2StaticMG',[-9,3,0],335],['M2StaticMG',[9,3,0],25],['TOW_TriPod_US_EP1',[0,6,0],0],
	['Stinger_Pod_US_EP1',[0,-2,0],0],['Land_fort_bagfence_round',[0,-4,0],0],
	['USBasicAmmunitionBox_EP1',[-4,0,0],0],['USBasicAmmunitionBox_EP1',[4,0,0],0],
	['Land_fort_bagfence_corner',[-10,1,0],270],['Land_fort_bagfence_long',[-10,-3,0],0],
	['Land_fort_bagfence_long',[10,-3,0],0],['Land_fort_bagfence_corner',[10,1,0],180],
	['Land_HBarrier_large',[0,9,0],0],
	['Fort_RazorWire',[-6,-6,0],0],['Fort_RazorWire',[6,-6,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_HEAVY_EAST',[
	['DSHKM_TK_INS_EP1',[-8,4,0],350],['DSHKM_TK_INS_EP1',[8,4,0],10],['Metis_TK_EP1',[0,6,0],0],
	['Igla_AA_pod_TK_EP1',[0,-2,0],0],['Land_fort_bagfence_round',[0,-4,0],0],
	['TKBasicAmmunitionBox_EP1',[-4,0,0],0],['TKBasicAmmunitionBox_EP1',[4,0,0],0],
	['Land_HBarrier_large',[-10,3,0],90],['Land_HBarrier_large',[10,3,0],90],
	['Land_HBarrier_large',[-6,-3,0],0],['Land_HBarrier_large',[0,-3,0],0],['Land_HBarrier_large',[6,-3,0],0],
	['Hedgehog',[-6,-6,0],0],['Hedgehog',[6,-6,0],0],['Fort_RazorWire',[0,-7,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_LIGHT_WEST',[
	['M119_US_EP1',[0,3,0],0],
	['USBasicAmmunitionBox_EP1',[-3,-2,0],0],['USBasicAmmunitionBox_EP1',[3,-2,0],0],
	['Land_fort_bagfence_long',[-5,1,0],90],['Land_fort_bagfence_long',[5,1,0],90],
	['Fort_RazorWire',[0,5,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_LIGHT_EAST',[
	['D30_TK_EP1',[0,3,0],0],
	['TKBasicAmmunitionBox_EP1',[-3,-2,0],0],['TKBasicAmmunitionBox_EP1',[3,-2,0],0],
	['Land_HBarrier_large',[-5,2,0],90],['Land_HBarrier_large',[5,2,0],90],
	['Fort_RazorWire',[0,5,0],0]
]];

//--- Anchor (build-menu placeholder classname) -> composition template map.
// [anchorClassname, baseTemplateVar, factionSpecific?]  (factionSpecific appends _WEST / _EAST at build time)
WFBE_POSITION_TEMPLATE_MAP = [
	['Land_Ind_BoardsPack1','WFBE_NEURODEF_AAPOS',true],			//--- AA (light, 2 AI)
	['Land_CncBlock_Stripes','WFBE_NEURODEF_AAPOS_HEAVY',true],			//--- AA (heavy, 4 AI)
	['Land_Barrel_sand','WFBE_NEURODEF_ARTYPOS_LIGHT',true],	//--- Artillery (light, 1 AI)
	['Land_Ind_BoardsPack2','WFBE_NEURODEF_ARTYPOS',true],		//--- Artillery (heavy, 4 AI)
	['Land_WoodenRamp','WFBE_NEURODEF_MIXEDPOS',true],			//--- Mixed (light, 2 AI)
	['RoadCone','WFBE_NEURODEF_MIXEDPOS_HEAVY',true],			//--- Mixed (heavy, 4 AI)
	['Paleta1','WFBE_NEURODEF_WALL_STRAIGHT',false],
	['Paleta2','WFBE_NEURODEF_WALL_CORNER',false],
	['Land_Ind_Timbers','WFBE_NEURODEF_WALL_GATE',false]
];
WFBE_POSITION_ANCHOR_NAMES = ['Land_Ind_BoardsPack1','Land_CncBlock_Stripes','Land_Barrel_sand','Land_Ind_BoardsPack2','Land_WoodenRamp','RoadCone','Paleta1','Paleta2','Land_Ind_Timbers'];
