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

//--- CBRadar intentionally has no auto walls — dressing is handled by Server_SpawnStructureDressing.sqf.
missionNamespace setVariable ['WFBE_NEURODEF_CBRADAR_WALLS',[

]];

//--- Bank intentionally has no auto walls — dressing is handled by Server_SpawnStructureDressing.sqf.
missionNamespace setVariable ['WFBE_NEURODEF_BANK_WALLS',[

]];

//=============================================================================
//--- cmdcon43-c: FACTORY WALL SLABS v3 (WFBE_C_WALLS_V3). Ray-approved 2026-07-02.
//--- Ray's verbatim ask (Build 88): "revert the factory wall changes, and then just add
//--- additional concrete slabs to them like the HQ has for survivability".
//---
//--- The cmdcon42-g wall LADDER v2 (bagfence/HESCO/concrete material swap) is REVERTED —
//--- those *_WALLS_V2 factory arrays are DELETED and the factories are back on their
//--- ORIGINAL legacy *_WALLS compositions (untouched above / in the HEAVY+AIRCRAFT blocks below).
//--- WFBE_C_WALLS_V2 stays REGISTERED but is now DEAD (default 0); see Init_CommonConstants.sqf.
//---
//--- These *_WALLS_V3 arrays = the ORIGINAL legacy factory walls PLUS a ring/segments of
//--- Concrete_Wall_EP1 slabs, the EXACT class the HQ funnel uses (WFBE_NEURODEF_HEADQUARTERS_WALLS
//--- below, 20x Concrete_Wall_EP1). Slabs are near-indestructible cover = the survivability Ray wants.
//--- Construction_Small/MediumSite.sqf select _V3 vs legacy by WFBE_C_WALLS_V3 at spawn time.
//--- REVERSIBILITY: WFBE_C_WALLS_V3 = 0 -> the hooks read the plain legacy *_WALLS -> exact
//--- original walls, no slabs. No legacy array is edited or deleted.
//---
//--- Format ['classname',[xOff,yOff,zOff],relDir]; +Y=model front, +X=model right; identical math
//--- to the HQ array + CreateDefenseTemplate (setDir (dir - relDir), origin modelToWorld relPos, z=0).
//--- Concrete_Wall_EP1 is ~3.6 m wide. Placement rules kept from the legacy layouts:
//---   * Vehicle factories (Light/Heavy/Aircraft) spawn vehicles toward +X (model right, _dir=90,
//---     Client_BuildUnit.sqf pads/fallback) -> the +X face is left OPEN (no slabs) for egress.
//---   * Slabs are pushed to the OUTSIDE of the legacy wall ring so foot traffic + the legacy
//---     walking gaps are preserved; they add a second, harder cover layer, not a new blocker.
//=============================================================================

//--- BARRACKS v3. Legacy = 8x Base_WarfareBBarrier5x closed ring w/ front+rear walking gaps (infantry
//--- factory, no vehicle egress). Add a concrete slab apron OUTSIDE the front (+Y) and rear (-Y) faces,
//--- offset past the legacy 11 m ring, leaving the same center walking gaps open. Legacy 8 + 6 slabs = 14.
missionNamespace setVariable ['WFBE_NEURODEF_BARRACKS_WALLS_V3',
	(missionNamespace getVariable 'WFBE_NEURODEF_BARRACKS_WALLS') +
	[
		['Concrete_Wall_EP1',[-5.4,13.5,0],0],['Concrete_Wall_EP1',[5.4,13.5,0],0],
		['Concrete_Wall_EP1',[-5.4,-13.5,0],0],['Concrete_Wall_EP1',[5.4,-13.5,0],0],
		['Concrete_Wall_EP1',[-13.5,0,0],90],['Concrete_Wall_EP1',[13.5,0,0],90]
	]
];

//--- LIGHT v3. Legacy = 10x Land_HBarrier_large U-ring; vehicles exit +X (right). Add a concrete slab
//--- backing layer OUTSIDE the -X, +Y and -Y legacy walls; +X (egress) face stays OPEN. Legacy 10 + 7 slabs = 17.
missionNamespace setVariable ['WFBE_NEURODEF_LIGHT_WALLS_V3',
	(missionNamespace getVariable 'WFBE_NEURODEF_LIGHT_WALLS') +
	[
		['Concrete_Wall_EP1',[-14,-6.5,0],90],['Concrete_Wall_EP1',[-14,-2.9,0],90],
		['Concrete_Wall_EP1',[-14,0.7,0],90],['Concrete_Wall_EP1',[-14,4.3,0],90],
		['Concrete_Wall_EP1',[-3.6,15,0],0],['Concrete_Wall_EP1',[3.6,15,0],0],
		['Concrete_Wall_EP1',[0,-15,0],0]
	]
];

//--- COMMANDCENTER v3. Legacy = 6x Land_HBarrier_large + 1x Land_HBarrier5, front walking gap. No vehicle
//--- egress. Add a concrete slab ring OUTSIDE the ~7.5 m legacy walls on both sides + rear, front gap kept.
//--- Legacy 7 + 8 slabs = 15.
missionNamespace setVariable ['WFBE_NEURODEF_COMMANDCENTER_WALLS_V3',
	(missionNamespace getVariable 'WFBE_NEURODEF_COMMANDCENTER_WALLS') +
	[
		['Concrete_Wall_EP1',[7.5,-3.6,0],90],['Concrete_Wall_EP1',[7.5,0,0],90],['Concrete_Wall_EP1',[7.5,3.6,0],90],
		['Concrete_Wall_EP1',[-9,-3.6,0],90],['Concrete_Wall_EP1',[-9,0,0],90],['Concrete_Wall_EP1',[-9,3.6,0],90],
		['Concrete_Wall_EP1',[-1.8,-10,0],0],['Concrete_Wall_EP1',[1.8,-10,0],0]
	]
];

//--- SERVICEPOINT v3. Legacy is EMPTY [] (drive-through service bay, both X faces open). Ray's ask is
//--- "additional slabs" on the factories — the service point is a repair pad, not a walled factory, and
//--- has no legacy walls to add to. Keep it EMPTY (no slabs) so both drive-through faces stay clear.
missionNamespace setVariable ['WFBE_NEURODEF_SERVICEPOINT_WALLS_V3',
	(missionNamespace getVariable 'WFBE_NEURODEF_SERVICEPOINT_WALLS')
];

//--- HEAVY v3 and AIRCRAFT v3 are defined LATER in this file, immediately after their legacy
//--- WFBE_NEURODEF_HEAVY_WALLS / WFBE_NEURODEF_AIRCRAFT_WALLS arrays (which live further down),
//--- because each _V3 array is built by concatenating slabs onto the legacy array it references.

//--- OWNER OVERRIDE 2026-06-14: ArtyRadar + Reserve must be a TIGHT cluster of <=6 THEMED props (antenna/crate/etc),
//--- NOT a walled HESCO compound with watchtowers. These four NEURODEF vars are the dressing templates read by
//--- Construction_MediumSite.sqf (WFBE_NEURODEF_ARTILLERYRADAR_/RESERVE_WEST|EAST); both rlTypes are excluded from the
//--- auto-walls block there, so the unused _WALLS variants and the former WDDM "walled compound" builds were removed.
//--- Compact themed cluster: core model + these <=5 small props = <=6 items, all within ~3.5 m, 0 AI, 0 walls.
missionNamespace setVariable ['WFBE_NEURODEF_ARTILLERYRADAR_WEST', [
	['Misc_cargo_cont_small',	[-3,2,0],	90],	//--- instrument / control box
	['Land_CamoNetVar_NATO',	[-3,2.6,0],	0],		//--- camo net draped over the box
	['USBasicAmmunitionBox_EP1',[2,2,0],	0],		//--- equipment crate
	['Land_fort_bagfence_round',[0,2.4,0],	180],	//--- sandbag arc at the mast base
	['FlagCarrierGUE',			[2.2,-1.5,0],180]	//--- faction flag
]];
missionNamespace setVariable ['WFBE_NEURODEF_ARTILLERYRADAR_EAST', [
	['Misc_cargo_cont_small',	[-3,2,0],	90],
	['Land_CamoNetVar_EAST',	[-3,2.6,0],	0],
	['TKBasicAmmunitionBox_EP1',[2,2,0],	0],
	['Land_fort_bagfence_round',[0,2.4,0],	180],
	['FlagCarrierGUE',			[2.2,-1.5,0],180]
]];
missionNamespace setVariable ['WFBE_NEURODEF_RESERVE_WEST', [
	['USBasicAmmunitionBox_EP1',[-2,1.5,0],	0],		//--- supply crate
	['USBasicAmmunitionBox_EP1',[-2,-0.5,0],90],	//--- supply crate
	['Land_fort_bagfence_long',	[2,0.5,0],	90],	//--- short sandbag wall
	['Land_Campfire',			[2,2.5,0],	0],		//--- watch-post lamp
	['FlagCarrierGUE',			[0,-2.5,0],	180]	//--- faction flag
]];
missionNamespace setVariable ['WFBE_NEURODEF_RESERVE_EAST', [
	['TKBasicAmmunitionBox_EP1',[-2,1.5,0],	0],
	['TKBasicAmmunitionBox_EP1',[-2,-0.5,0],90],
	['Land_fort_bagfence_long',	[2,0.5,0],	90],
	['Land_Campfire',			[2,2.5,0],	0],
	['FlagCarrierGUE',			[0,-2.5,0],	180]
]];

//=============================================================================
// CBR (Counter Battery Radar) composition dressing — task 37 visual rework.
// Footprint ≤ 14 m radius. Core = Land_Antenna at origin for both sides (Land_telek1 rejected as likely absent).
// WEST: NATO/US radar outpost — cornered sandbag ring, camo-netted shelter, razorwire perimeter.
// EAST: RU/TK radar outpost — L-shaped HBarrier screen, camo net, hedgehog traps, razorwire.
// All classnames confirmed used elsewhere in this mission (see comments on each entry).
// NOTE: Land_Antenna confirmed (CBR anchor + Structures_CO files).
//       Misc_cargo_cont_small confirmed (used in former WEST CBR template).
//       Land_CamoNetVar_NATO / Land_CamoNetVar_EAST confirmed (Core_Structures and Core configs).
//       Land_fort_bagfence_round / _long / _corner confirmed (defenses, AAPOD, WDDM templates).
//       USBasicAmmunitionBox_EP1 / TKBasicAmmunitionBox_EP1 confirmed.
//       Land_Campfire confirmed (Structures_CO_US defense list).
//       Fort_RazorWire confirmed (defense templates above).
//       Land_HBarrier_large confirmed (multiple wall templates).
//       Hedgehog confirmed (WFBE_NEURODEF_WALL_GATE above).
//=============================================================================

//--- WEST: NATO/US radar outpost — cornered sandbag ring enclosing the mast, camo-netted
//--- instrument shelter set back from it, paired ammo crates, razorwire arcs at the perimeter.
//--- task 27 WDDM pass: HESCO 5x mini-ring + one corner watchtower wrap the existing
//--- sandbag outpost so it reads as the same WDDM family as Bank/Reserve/ArtyRadar.
//--- Land_Fort_Watchtower(_EP1) content-branched like the _WALLS arrays. CBR is rarely
//--- built (reactive arty-threat gate), so this is player-facing in practice.
//--- All classnames VALIDATED (Base_WarfareBBarrier5x: barracks/artyradar walls; watchtowers: RESERVE).
private '_c';
_c = [
	//--- Instrument shelter set back north-west; CamoNetVar drapes over it for a camouflaged look.
	['Misc_cargo_cont_small',		[-5.5, 4.5, 0],	90],	//--- Control shelter / generator box
	['Land_CamoNetVar_NATO',		[-5.5, 5.5, 0],	0],		//--- Camo net draped over shelter
	//--- Equipment crates stacked against the shelter's south side.
	['USBasicAmmunitionBox_EP1',	[-3.5, 2.5, 0],	0],		//--- Instrument crate (cable drums)
	['USBasicAmmunitionBox_EP1',	[-2.0, 2.5, 0],	90],	//--- Second crate (power cells)
	//--- Cornered sandbag ring tightly enclosing the antenna base — gives it a defended-position feel.
	['Land_fort_bagfence_round',	[0, 2.5, 0],	180],	//--- Sandbag arc front (south)
	['Land_fort_bagfence_long',		[-3.0, 0, 0],	90],	//--- Sandbag wall west side
	['Land_fort_bagfence_long',		[3.0, 0, 0],	90],	//--- Sandbag wall east side
	['Land_fort_bagfence_corner',	[-3.0, 2.5, 0],	0],		//--- NW corner of ring
	['Land_fort_bagfence_corner',	[3.0, 2.5, 0],	270],	//--- NE corner of ring
	//--- HESCO 5x outer mini-ring (WDDM pass) — open south gate gap at y=-13.
	['Base_WarfareBBarrier5x',		[-6, 13, 0],	0],		//--- Rear wall left
	['Base_WarfareBBarrier5x',		[6, 13, 0],		0],		//--- Rear wall right
	['Base_WarfareBBarrier5x',		[-13, 6, 0],	90],	//--- West wall north
	['Base_WarfareBBarrier5x',		[-13, -6, 0],	90],	//--- West wall south
	['Base_WarfareBBarrier5x',		[13, 6, 0],		90],	//--- East wall north
	['Base_WarfareBBarrier5x',		[13, -6, 0],	90],	//--- East wall south
	//--- Razorwire outer perimeter — two arcs south, closing the gate flanks.
	['Fort_RazorWire',				[-5.5, -11.0, 0],25],	//--- SW perimeter arc
	['Fort_RazorWire',				[5.5, -11.0, 0],335],	//--- SE perimeter arc
	['Land_Campfire',				[7.0, 4.5, 0],	0]		//--- Operator watch-post / lamp (east)
];
if (WF_A2_Arrowhead) then {
	_c = _c + [['Land_Fort_Watchtower_EP1',[-11, 11, 0],45]];	//--- OA corner tower (rear-left)
} else {
	_c = _c + [['Land_Fort_Watchtower',[-11, 11, 0],45]];		//--- A2/CO corner tower (rear-left)
};
missionNamespace setVariable ['WFBE_NEURODEF_CBRADAR_WEST', _c];

//--- EAST: RU/TK radar outpost — L-shaped blast-wall screen behind the mast, camo-netted,
//--- hedgehog tank traps forward, paired equipment crates, razorwire perimeter.
//--- task 27 WDDM pass: HESCO 5x mini-ring + one corner watchtower (mirrors WEST).
//--- All classnames VALIDATED in this mission's content set.
_c = [
	//--- Blast-wall L-screen behind and beside the mast (north + north-east).
	['Land_HBarrier_large',			[0, 5.0, 0],	0],		//--- Back blast wall (north, perpendicular)
	['Land_HBarrier_large',			[4.5, 2.5, 0],	90],	//--- East-flank blast wall
	//--- Camo net over the north blast wall — breaks up the silhouette.
	['Land_CamoNetVar_EAST',		[0, 5.5, 0],	0],		//--- Net draped over north wall
	//--- Equipment crates clustered west of the mast.
	['TKBasicAmmunitionBox_EP1',	[-3.5, 1.5, 0],	0],		//--- Equipment crate (west)
	['TKBasicAmmunitionBox_EP1',	[-2.0, 1.5, 0],	90],	//--- Second crate
	//--- Sandbag screen on the vulnerable south and west faces.
	['Land_fort_bagfence_long',		[-3.5, -1.5, 0],0],		//--- Sandbag south-west screen
	['Land_fort_bagfence_long',		[0, -3.0, 0],	0],		//--- Sandbag south screen
	['Land_fort_bagfence_corner',	[-3.5, -3.0, 0],270],	//--- SW corner sandbag
	//--- HESCO 5x outer mini-ring (WDDM pass) — open south gate gap at y=-13.
	['Base_WarfareBBarrier5x',		[-6, 13, 0],	0],		//--- Rear wall left
	['Base_WarfareBBarrier5x',		[6, 13, 0],		0],		//--- Rear wall right
	['Base_WarfareBBarrier5x',		[-13, 6, 0],	90],	//--- West wall north
	['Base_WarfareBBarrier5x',		[-13, -6, 0],	90],	//--- West wall south
	['Base_WarfareBBarrier5x',		[13, 6, 0],		90],	//--- East wall north
	['Base_WarfareBBarrier5x',		[13, -6, 0],	90],	//--- East wall south
	//--- Hedgehog tank traps on the open south approach (gate flanks).
	['Hedgehog',					[-5.5, -11.0, 0],0],	//--- Tank trap SW
	['Hedgehog',					[5.5, -11.0, 0],0],		//--- Tank trap SE
	//--- Razorwire arc closing the far south perimeter.
	['Fort_RazorWire',				[0, -13.0, 0],	0],		//--- Razorwire south centre
	['Land_Campfire',				[-7.0, 4.5, 0],	0]		//--- Operator position / lamp (west)
];
if (WF_A2_Arrowhead) then {
	_c = _c + [['Land_Fort_Watchtower_EP1',[11, 11, 0],315]];	//--- OA corner tower (rear-right)
} else {
	_c = _c + [['Land_Fort_Watchtower',[11, 11, 0],315]];		//--- A2/CO corner tower (rear-right)
};
missionNamespace setVariable ['WFBE_NEURODEF_CBRADAR_EAST', _c];

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

//--- cmdcon43-c: HEAVY v3 slabs (see the WFBE_C_WALLS_V3 block near the top of this file).
//--- Legacy HEAVY = 13x Land_HBarrier_large enclosure (~28x30 m); armor exits +X (right, model x=+14 face
//--- which the legacy layout already leaves gapped). Add a Concrete_Wall_EP1 backing layer OUTSIDE the rear
//--- (-X, x=-14) and the +Y / -Y legacy walls; the +X egress face is left UNTOUCHED. Legacy 13 + 7 slabs = 20.
missionNamespace setVariable ['WFBE_NEURODEF_HEAVY_WALLS_V3',
	(missionNamespace getVariable 'WFBE_NEURODEF_HEAVY_WALLS') +
	[
		['Concrete_Wall_EP1',[-17,-7.2,0],90],['Concrete_Wall_EP1',[-17,-3.6,0],90],
		['Concrete_Wall_EP1',[-17,0,0],90],['Concrete_Wall_EP1',[-17,3.6,0],90],['Concrete_Wall_EP1',[-17,7.2,0],90],
		['Concrete_Wall_EP1',[-3.6,16,0],0],['Concrete_Wall_EP1',[-3.6,-17.5,0],0]
	]
];

//--- cmdcon43-c: AIRCRAFT v3 slabs (see the WFBE_C_WALLS_V3 block near the top of this file).
//--- Legacy AIRCRAFT = 10x Land_HBarrier_large U-ring (~22x24 m); aircraft exit +X (right, apron at model
//--- x=+10). Add a Concrete_Wall_EP1 backing layer OUTSIDE the rear (-X, x=-11) and the +Y / -Y legacy walls;
//--- the +X apron is left OPEN. Legacy 10 + 7 slabs = 17.
missionNamespace setVariable ['WFBE_NEURODEF_AIRCRAFT_WALLS_V3',
	(missionNamespace getVariable 'WFBE_NEURODEF_AIRCRAFT_WALLS') +
	[
		['Concrete_Wall_EP1',[-14,-7.2,0],90],['Concrete_Wall_EP1',[-14,-3.6,0],90],
		['Concrete_Wall_EP1',[-14,0,0],90],['Concrete_Wall_EP1',[-14,3.6,0],90],['Concrete_Wall_EP1',[-14,7.2,0],90],
		['Concrete_Wall_EP1',[-3.6,15,0],0],['Concrete_Wall_EP1',[-3.6,-15,0],0]
	]
];

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

//=============================================================================
// Bank (Federal Reserve / Bank Rossii) composition dressing.
// Footprint ≤ 22 m radius. Core = WarfareBBarracks building at origin.
// Perimeter: HBarrier ring with an entrance gap on the south side (raidable).
// WEST: US/NATO aesthetic. EAST: RU/TK aesthetic.
// Classname confidence notes:
//   Land_HBarrier_large      — HIGH (used extensively in defense templates above).
//   Land_HBarrier5           — HIGH (used in COMMANDCENTER_WALLS template above).
//   FlagCarrierGUE           — PROVEN: live camp flag on this COMBINEDOPS_W server
//                              (CombinedOps_W.sqf:6 / Vanilla.sqf:6). Replaced the
//                              previously-unverified FlagCarrierUSA / FlagCarrierRU,
//                              which were referenced ONLY in this file (no content registry).
//   USBasicAmmunitionBox_EP1 — HIGH (confirmed in CBR template above).
//   TKBasicAmmunitionBox_EP1 — HIGH (confirmed in CBR template above).
//   Land_CamoNetB_NATO       — HIGH (confirmed in CBR template above).
//   Land_CamoNetB_EAST       — HIGH (confirmed in CBR template above).
//   Land_fort_bagfence_long  — HIGH (confirmed in CBR template above).
//   Fort_RazorWire           — HIGH (confirmed in CBR template above).
//   Land_Campfire            — HIGH (confirmed in CBR template above).
//   Land_HBarrier5           — HIGH (from COMMANDCENTER_WALLS above).
//=============================================================================

//=============================================================================
// BANK COMPOSITION DRESSING — task 27 WDDM rework (Bank is the ONLY one of the 4
//   reskin targets the AI commander actually builds — AI_Commander_Base.sqf:184-192,
//   confirmed live x4). Upgraded from the plain HBarrier box to the same WDDM
//   "floodlit walled compound" aesthetic the Reserve/ArtyRadar reskin used:
//   a full HESCO 10x perimeter ring with a south gate gap, two front-corner
//   watchtowers, a central illuminant tower, and a gated entrance — keeping the
//   bank-identity props (faction flag, camo net, supply crates, sandbags, wire).
//
//   CLASSNAME DISCIPLINE: every class below is VALIDATED — already spawned by an
//   existing template in THIS mission file:
//     Base_WarfareBBarrier10x        — RESERVE_WALLS/RESERVE_WEST (l.81-84/183-190)
//     Land_Fort_Watchtower_EP1       — RESERVE_WALLS/WEST (l.88/197), WF_A2_Arrowhead branch
//     Land_Fort_Watchtower           — RESERVE_WALLS/WEST (l.90/199), A2/CO branch
//     Land_Ind_IlluminantTower       — RESERVE_WALLS/WEST (l.85/192)
//     Land_CncBlock_Stripes — ARTILLERYRADAR/Bank gate furniture (proven; replaced unverified Land_BarGate2)
//     RoadCone / Sign_Danger         — ARTILLERYRADAR gate (l.65-66/140-142)
//     FlagCarrierGUE, Land_CamoNetB_NATO/EAST, US/TKBasicAmmunitionBox_EP1,
//     Land_fort_bagfence_long, Fort_RazorWire, Land_Campfire — bank-identity props (prior BANK_).
//   Footprint ~28 x 24 m (±14 X, ±12 Y) HESCO ring — Bank classname is now
//   Land_fortified_nest_big_EP1 (~16x16 fortified compound, was Land_Mil_hangar_EP1),
//   so the ring was tightened from ±24X/±18Y to hug the smaller model. Walls are skipped (MediumSite.sqf:160-166).
//   Cosmetic / one-time spawn / 0-AI → STANDING GUARDRAIL not engaged (no unit inserted).
//=============================================================================

//--- WEST: US Federal Reserve — floodlit walled compound, watchtowers + gated entrance, 0 AI.
//--- Ring tightened from ±24X/±18Y to ±14X/±12Y to hug Land_fortified_nest_big_EP1 (~16x16).
private '_b';
_b = [
	//--- HESCO 10x perimeter ring (gap centre on the front/south face, y=-12).
	['Base_WarfareBBarrier10x',	[-7, 12, 0],	0],		//--- North wall left (rear)
	['Base_WarfareBBarrier10x',	[7, 12, 0],		0],		//--- North wall right
	['Base_WarfareBBarrier10x',	[-14, -5, 0],	90],	//--- West wall south
	['Base_WarfareBBarrier10x',	[-14, 5, 0],	90],	//--- West wall north
	['Base_WarfareBBarrier10x',	[14, -5, 0],	90],	//--- East wall south
	['Base_WarfareBBarrier10x',	[14, 5, 0],		90],	//--- East wall north
	['Base_WarfareBBarrier10x',	[-8, -12, 0],	0],		//--- South wall left (gate gap centre ≈ 5 m)
	['Base_WarfareBBarrier10x',	[8, -12, 0],	0],		//--- South wall right
	//--- Central illuminant tower — compound floodlight.
	['Land_Ind_IlluminantTower',[0, 0, 0],		0],		//--- Compound floodlight (centre)
	//--- US flag pole — front-right corner, faces entrance.
	['FlagCarrierGUE',			[8, -10, 0],	180],	//--- Flag near gate (FlagCarrierGUE = proven live camp flag; was unverified FlagCarrierUSA)
	//--- NATO camo net over NW corner (bank identity).
	['Land_CamoNetB_NATO',		[-10, 9, 0],	270],	//--- Camo net NW
	//--- Supply/vault crates inside compound (east side).
	['USBasicAmmunitionBox_EP1',	[10, 4, 0],		0],		//--- Vault supply crate
	['USBasicAmmunitionBox_EP1',	[11.5, 4, 0],	0],		//--- Second vault crate
	//--- Sandbag guard posts flanking the gate gap.
	['Land_fort_bagfence_long',	[-5, -10, 0],	90],	//--- Gate left sandbag
	['Land_fort_bagfence_long',	[5, -10, 0],	90],	//--- Gate right sandbag
	//--- Approach cones + danger sign at the entrance (south, y<-12).
	['RoadCone',				[-1.5, -14, 0],	0],		//--- Approach cone left
	['RoadCone',				[1.5, -14, 0],	0],		//--- Approach cone right
	['Sign_Danger',				[5.5, -13, 0],	0],		//--- Checkpoint danger sign
	//--- Razorwire perimeter outside the south flanks.
	['Fort_RazorWire',			[-13, -13, 0],	0],		//--- SW approach wire
	['Fort_RazorWire',			[11, -13, 0],	0],		//--- SE approach wire
	//--- Campfire/operator light at the rear.
	['Land_Campfire',			[-12, 10, 0],	0]		//--- NW corner light
];
if (WF_A2_Arrowhead) then {
	_b = _b + [['Land_Fort_Watchtower_EP1',[-12, 10, 0],45],['Land_Fort_Watchtower_EP1',[12, 10, 0],315]];	//--- OA corner towers
	_b = _b + [['Land_CncBlock_Stripes',[-1.6, -12.6, 0],0],['Land_CncBlock_Stripes',[1.6, -11.4, 0],0]];	//--- OA: jersey chicane in the gate gap
} else {
	_b = _b + [['Land_Fort_Watchtower',[-12, 10, 0],45],['Land_Fort_Watchtower',[12, 10, 0],315]];			//--- A2/CO corner towers
	_b = _b + [['Land_CncBlock_Stripes',[-1.6, -12.6, 0],0],['Land_CncBlock_Stripes',[1.6, -11.4, 0],0]];	//--- A2/CO: jersey chicane in the gate gap (was unverified Land_BarGate2; CncBlock proven)
};
missionNamespace setVariable ['WFBE_NEURODEF_BANK_WEST', _b];

//--- EAST: Bank Rossii — floodlit walled compound, watchtowers + gated entrance, 0 AI (identical layout, RU props).
//--- Ring tightened from ±24X/±18Y to ±14X/±12Y to hug Land_fortified_nest_big_EP1 (~16x16).
_b = [
	//--- HESCO 10x perimeter ring (gap centre on the front/south face, y=-12).
	['Base_WarfareBBarrier10x',	[-7, 12, 0],	0],		//--- North wall left (rear)
	['Base_WarfareBBarrier10x',	[7, 12, 0],		0],		//--- North wall right
	['Base_WarfareBBarrier10x',	[-14, -5, 0],	90],	//--- West wall south
	['Base_WarfareBBarrier10x',	[-14, 5, 0],	90],	//--- West wall north
	['Base_WarfareBBarrier10x',	[14, -5, 0],	90],	//--- East wall south
	['Base_WarfareBBarrier10x',	[14, 5, 0],		90],	//--- East wall north
	['Base_WarfareBBarrier10x',	[-8, -12, 0],	0],		//--- South wall left (gate gap centre ≈ 5 m)
	['Base_WarfareBBarrier10x',	[8, -12, 0],	0],		//--- South wall right
	//--- Central illuminant tower — compound floodlight.
	['Land_Ind_IlluminantTower',[0, 0, 0],		0],		//--- Compound floodlight (centre)
	//--- RU flag pole — front-right corner, faces entrance.
	['FlagCarrierGUE',			[8, -10, 0],	180],	//--- Flag near gate (FlagCarrierGUE = proven live camp flag; was unverified FlagCarrierRU)
	//--- EAST camo net over NW corner (bank identity).
	['Land_CamoNetB_EAST',		[-10, 9, 0],	270],	//--- Camo net NW
	//--- TK supply/vault crates inside compound (east side).
	['TKBasicAmmunitionBox_EP1',	[10, 4, 0],		0],		//--- Vault supply crate
	['TKBasicAmmunitionBox_EP1',	[11.5, 4, 0],	0],		//--- Second vault crate
	//--- Sandbag guard posts flanking the gate gap.
	['Land_fort_bagfence_long',	[-5, -10, 0],	90],	//--- Gate left sandbag
	['Land_fort_bagfence_long',	[5, -10, 0],	90],	//--- Gate right sandbag
	//--- Approach cones + danger sign at the entrance (south, y<-12).
	['RoadCone',				[-1.5, -14, 0],	0],		//--- Approach cone left
	['RoadCone',				[1.5, -14, 0],	0],		//--- Approach cone right
	['Sign_Danger',				[5.5, -13, 0],	0],		//--- Checkpoint danger sign
	//--- Razorwire perimeter outside the south flanks.
	['Fort_RazorWire',			[-13, -13, 0],	0],		//--- SW approach wire
	['Fort_RazorWire',			[11, -13, 0],	0],		//--- SE approach wire
	//--- Campfire/operator light at the rear.
	['Land_Campfire',			[-12, 10, 0],	0]		//--- NW corner light
];
if (WF_A2_Arrowhead) then {
	_b = _b + [['Land_Fort_Watchtower_EP1',[-12, 10, 0],45],['Land_Fort_Watchtower_EP1',[12, 10, 0],315]];	//--- OA corner towers
	_b = _b + [['Land_CncBlock_Stripes',[-1.6, -12.6, 0],0],['Land_CncBlock_Stripes',[1.6, -11.4, 0],0]];	//--- OA: jersey chicane in the gate gap
} else {
	_b = _b + [['Land_Fort_Watchtower',[-12, 10, 0],45],['Land_Fort_Watchtower',[12, 10, 0],315]];			//--- A2/CO corner towers
	_b = _b + [['Land_CncBlock_Stripes',[-1.6, -12.6, 0],0],['Land_CncBlock_Stripes',[1.6, -11.4, 0],0]];	//--- A2/CO: jersey chicane in the gate gap (was unverified Land_BarGate2; CncBlock proven)
};
missionNamespace setVariable ['WFBE_NEURODEF_BANK_EAST', _b];

//======================================================================================
//--- cmdcon42-g: DEFENSES/FORTIFICATIONS MENU v2 — anchor-composition buildables.
//--- HEDGEHOG LINE: one-click AT obstacle (4x Hedgehog_EP1 in a line). Side-neutral. Flat.
//--- FLAK TOWER: elevated AA static + pooled AI gunner on a tower deck (WEST/EAST variants).
//---   The AA child carries a NON-ZERO z offset (deck height). The generic ConstructPosition
//---   path flattens z, so a flak-tower-specific block in Server_ConstructPosition.sqf lifts the
//---   gun onto the deck via setPosATL (per proposal B.5 idiom). Manning is the existing pooled
//---   DefenseTeam (ConstructDefense mans any gun with an empty gunner slot). NEEDS-BOX-VERIFY.
//======================================================================================
missionNamespace setVariable ['WFBE_NEURODEF_HEDGEHOGLINE',[
	['Hedgehog_EP1',[-4.5,0,0],0],['Hedgehog_EP1',[-1.5,0,0],0],
	['Hedgehog_EP1',[1.5,0,0],0],['Hedgehog_EP1',[4.5,0,0],0]
]];
//--- Flak tower: element 0 = host tower @ ground (z=0), element 1 = AA gun @ deck height (z>0).
//--- Server_ConstructPosition.sqf lifts any child with z>0.1 onto the deck via setPosATL + levels it, and
//--- (when WFBE_C_DEF_FLAKTOWER_AUTOZ=1) auto-corrects that z to the host tower's REAL boundingBox top.
//--- cmdcon44-c (Build 89, Ray 2026-07-03): "isnt there like a thinner tall tower? like one of the light
//--- towers or something". The host classname + deck z are flag-driven (WFBE_C_DEF_FLAKTOWER_STRUCTURE /
//--- _DECK_Z / _AUTOZ, Init_CommonConstants.sqf) so the tower can be swapped/retuned on the box with no code
//--- change or re-mirror. DEFAULT = Land_Ind_IlluminantTower (thin lattice floodlight/"light" tower, mapSize
//--- 2; CONFIRMED in the arma2-co-config-reference catalog + already spawned live as the Bank centrepiece =>
//--- loads on both maps). Deck z is auto-measured; _DECK_Z=17.0 is only the fallback if AUTOZ is off/fails.
private ["_flakHost","_flakDeckZ"];
_flakHost  = missionNamespace getVariable ["WFBE_C_DEF_FLAKTOWER_STRUCTURE", "Land_Ind_IlluminantTower"];
_flakDeckZ = missionNamespace getVariable ["WFBE_C_DEF_FLAKTOWER_DECK_Z", 17.0];
//--- WEST: A2-OA has no US static bullet-AA -> Stinger_Pod is the WEST AA mount.
missionNamespace setVariable ['WFBE_NEURODEF_FLAKTOWER_WEST',[
	[_flakHost,[0,0,0],0],
	['Stinger_Pod_US_EP1',[0,0,_flakDeckZ],0]
]];
//--- EAST / GUER: the true ZU-23 auto-cannon on the deck.
missionNamespace setVariable ['WFBE_NEURODEF_FLAKTOWER_EAST',[
	[_flakHost,[0,0,0],0],
	['ZU23_TK_EP1',[0,0,_flakDeckZ],0]
]];

//======================================================================================
//--- cmdcon44-c (Build 89, Ray 2026-07-03): DEFENSES LIST — AA / ARTILLERY / MIXED POSITIONS
//--- + FORTIFICATIONS, AUTHORED IN RAY'S WDDM TOOL. Ray (item 36): "Did u fully remake these as
//--- fable using my WDDM tool? if not, do so - and think like an actual soldier in what would be
//--- useful (same for fortifications)". cmdcon44-a had hand-coded these arrays inline; this pass
//--- REPLACES them with compositions authored as .wddm.json design files (openable/iterable in the
//--- WDDM editor, rayswaynl/WDDM) under docs/design/compositions/*.wddm.json, converted to the SQF
//--- below by Tools/WddmToSqf/wddm_to_sqf.py. The .wddm.json is the SOURCE OF TRUTH; to change a
//--- layout, edit it in WDDM and re-run the converter (do not hand-edit these arrays).
//---
//--- SOLDIER LOGIC in every design (full rationale in each .wddm.json 'notes' field):
//---   * 360 security or tied-in flanks — every gun's blind side is covered by another weapon or cover;
//---   * clear primary arcs AND flank/rear protection for the firer (interlocking fields of fire);
//---   * dispersion vs artillery (batteries spread + revetted, not clustered);
//---   * an entrance/exit is always left open (a position you can't resupply/withdraw from is a tomb);
//---   * nothing decorative blocks a weapon's fire (nets/cover sit behind or beside the guns).
//--- All classnames config-verified against the rayswaynl/arma2-co-config-reference CfgVehicles catalog.
//--- REVERSIBILITY: WFBE_C_DEFMENU_V2_POSITIONS = 0 -> the legacy compositions further up this file stand.
//--- Format ['classname',[xOff,yOff,zOff],relDir]; +Y=front, +X=right (z=0 flat).
//======================================================================================
if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2_POSITIONS", 1]) > 0) then {

	//--- AA NEST (LIGHT, 2 AI) WEST — twin Stinger on a bag ring + rear .50 for 360 self-defence, flank HBarrier wings, forward wire.
	missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_WEST',[
		['Stinger_Pod_US_EP1',[-4,4,0],335],
		['Stinger_Pod_US_EP1',[4,4,0],25],
		['Land_fort_bagfence_round',[-4,4,0],0],
		['Land_fort_bagfence_round',[4,4,0],0],
		['M2StaticMG',[0,-4,0],180],
		['Land_fort_bagfence_round',[0,-4,0],0],
		['USBasicAmmunitionBox_EP1',[-6,-1,0],0],
		['Land_HBarrier_large',[-8,0,0],90],
		['Land_HBarrier_large',[8,0,0],90],
		['Land_CamoNetVar_NATO',[-6,3,0],0],
		['Land_CamoNetVar_NATO',[6,3,0],0],
		['Fort_RazorWire',[-3,7,0],20]
	]];

	//--- AA NEST (LIGHT, 2 AI) EAST — ZU-23 + Igla dispersed pit, rear DShK self-defence, flank wings, forward wire.
	missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_EAST',[
		['ZU23_TK_EP1',[-4,4,0],335],
		['Igla_AA_pod_TK_EP1',[4,4,0],25],
		['Land_fort_bagfence_round',[-4,4,0],0],
		['Land_fort_bagfence_round',[4,4,0],0],
		['DSHKM_TK_INS_EP1',[0,-4,0],180],
		['Land_fort_bagfence_round',[0,-4,0],0],
		['TKBasicAmmunitionBox_EP1',[-6,-1,0],0],
		['Land_HBarrier_large',[-8,0,0],90],
		['Land_HBarrier_large',[8,0,0],90],
		['Land_CamoNet_EAST',[-6,3,0],0],
		['Land_CamoNet_EAST',[6,3,0],0],
		['Fort_RazorWire',[-3,7,0],20]
	]];

	//--- AA BATTERY / SAM (HEAVY, 4 AI) WEST — 3 dispersed Stingers on an 18 m arc, revetment berms, camo-netted control/radar point, rear MG security, split ammo, HESCO wings.
	missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_HEAVY_WEST',[
		['Stinger_Pod_US_EP1',[-10,6,0],320],
		['Stinger_Pod_US_EP1',[0,9,0],0],
		['Stinger_Pod_US_EP1',[10,6,0],40],
		['Land_fort_bagfence_round',[-10,4.4,0],0],
		['Land_fort_bagfence_round',[0,7.4,0],0],
		['Land_fort_bagfence_round',[10,4.4,0],0],
		['Land_fort_rampart',[-5,5,0],0],
		['Land_fort_rampart',[5,5,0],0],
		['Misc_cargo_cont_small',[0,-3,0],90],
		['Land_CamoNetVar_NATO',[0,-2.4,0],0],
		['M2StaticMG',[-7,-6,0],200],
		['Land_fort_bagfence_round',[-7,-6,0],0],
		['USBasicAmmunitionBox_EP1',[-6,1,0],0],
		['USBasicAmmunitionBox_EP1',[6,1,0],0],
		['Base_WarfareBBarrier5x',[-14,2,0],90],
		['Base_WarfareBBarrier5x',[14,2,0],90],
		['Fort_RazorWire',[-8,9,0],10],
		['Fort_RazorWire',[8,9,0],350]
	]];

	//--- AA BATTERY / SAM (HEAVY, 4 AI) EAST — 2 ZU-23 + centre Igla dispersed, ramparts, control point, rear DShK, split ammo, HBarrier wings, forward traps.
	missionNamespace setVariable ['WFBE_NEURODEF_AAPOS_HEAVY_EAST',[
		['ZU23_TK_EP1',[-10,6,0],330],
		['Igla_AA_pod_TK_EP1',[0,9,0],0],
		['ZU23_TK_EP1',[10,6,0],30],
		['Land_fort_bagfence_round',[-10,4.4,0],0],
		['Land_fort_bagfence_round',[0,7.4,0],0],
		['Land_fort_bagfence_round',[10,4.4,0],0],
		['Land_fort_rampart_EP1',[-5,5,0],0],
		['Land_fort_rampart_EP1',[5,5,0],0],
		['Misc_cargo_cont_small',[0,-3,0],90],
		['Land_CamoNet_EAST',[0,-2.4,0],0],
		['DSHKM_TK_INS_EP1',[-7,-6,0],200],
		['Land_fort_bagfence_round',[-7,-6,0],0],
		['TKBasicAmmunitionBox_EP1',[-6,1,0],0],
		['TKBasicAmmunitionBox_EP1',[6,1,0],0],
		['Land_HBarrier_large',[-14,2,0],90],
		['Land_HBarrier_large',[14,2,0],90],
		['Hedgehog',[-8,9,0],0],
		['Hedgehog',[8,9,0],0],
		['Fort_RazorWire',[0,10,0],0]
	]];

	//--- ARTILLERY PIT (LIGHT, 1 AI) WEST — M119 in an earthen artillery revetment (clear overhead), rear .50 picket, ammo behind cover, bag horseshoe.
	missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_LIGHT_WEST',[
		['Land_fort_artillery_nest_EP1',[0,3,0],0],
		['M119_US_EP1',[0,3,0],0],
		['M2StaticMG',[0,-5,0],180],
		['Land_fort_bagfence_round',[0,-5,0],0],
		['USBasicAmmunitionBox_EP1',[-3,-2,0],0],
		['Land_fort_bagfence_long',[-6,0,0],90],
		['Land_fort_bagfence_long',[6,0,0],90],
		['Land_fort_bagfence_corner',[-6,-3,0],270],
		['Land_fort_bagfence_corner',[6,-3,0],180],
		['Fort_RazorWire',[0,7,0],0]
	]];

	//--- ARTILLERY PIT (LIGHT, 1 AI) EAST — D-30 in a revetment, rear DShK picket, ammo behind cover, HBarrier horseshoe.
	missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_LIGHT_EAST',[
		['Land_fort_artillery_nest_EP1',[0,3,0],0],
		['D30_TK_EP1',[0,3,0],0],
		['DSHKM_TK_INS_EP1',[0,-5,0],180],
		['Land_fort_bagfence_round',[0,-5,0],0],
		['TKBasicAmmunitionBox_EP1',[-3,-2,0],0],
		['Land_HBarrier_large',[-6,0,0],90],
		['Land_HBarrier_large',[6,0,0],90],
		['Land_HBarrier_large',[-3,-4,0],0],
		['Land_HBarrier_large',[3,-4,0],0],
		['Fort_RazorWire',[0,7,0],0]
	]];

	//--- ARTILLERY BATTERY (HEAVY, 4 AI) WEST — 3 M119 each in its own revetment, ~10 m spacing (counter-battery), paired rear .50 pickets, dispersed ammo, flank blast walls, rear nets.
	missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_WEST',[
		['Land_fort_artillery_nest_EP1',[-11,4,0],0],
		['Land_fort_artillery_nest_EP1',[0,5,0],0],
		['Land_fort_artillery_nest_EP1',[11,4,0],0],
		['M119_US_EP1',[-11,4,0],0],
		['M119_US_EP1',[0,5,0],0],
		['M119_US_EP1',[11,4,0],0],
		['USBasicAmmunitionBox_EP1',[-11,0,0],0],
		['USBasicAmmunitionBox_EP1',[0,1,0],0],
		['USBasicAmmunitionBox_EP1',[11,0,0],0],
		['M2StaticMG',[-6,-6,0],205],
		['M2StaticMG',[6,-6,0],155],
		['Land_fort_bagfence_round',[-6,-6,0],0],
		['Land_fort_bagfence_round',[6,-6,0],0],
		['Land_HBarrier_large',[-16,3,0],90],
		['Land_HBarrier_large',[16,3,0],90],
		['Land_CamoNetVar_NATO',[-6,-2,0],0],
		['Land_CamoNetVar_NATO',[6,-2,0],0],
		['Fort_RazorWire',[-10,-8,0],0],
		['Fort_RazorWire',[10,-8,0],0]
	]];

	//--- ARTILLERY BATTERY (HEAVY, 4 AI) EAST — 3 D-30 fanned in revetments, spaced, paired rear DShK pickets, dispersed ammo, flank walls, rear nets, rear traps.
	missionNamespace setVariable ['WFBE_NEURODEF_ARTYPOS_EAST',[
		['Land_fort_artillery_nest_EP1',[-11,4,0],0],
		['Land_fort_artillery_nest_EP1',[0,5,0],0],
		['Land_fort_artillery_nest_EP1',[11,4,0],0],
		['D30_TK_EP1',[-11,4,0],8],
		['D30_TK_EP1',[0,5,0],0],
		['D30_TK_EP1',[11,4,0],352],
		['TKBasicAmmunitionBox_EP1',[-11,0,0],0],
		['TKBasicAmmunitionBox_EP1',[0,1,0],0],
		['TKBasicAmmunitionBox_EP1',[11,0,0],0],
		['DSHKM_TK_INS_EP1',[-6,-6,0],205],
		['DSHKM_TK_INS_EP1',[6,-6,0],155],
		['Land_fort_bagfence_round',[-6,-6,0],0],
		['Land_fort_bagfence_round',[6,-6,0],0],
		['Land_HBarrier_large',[-16,3,0],90],
		['Land_HBarrier_large',[16,3,0],90],
		['Land_CamoNet_EAST',[-6,-2,0],0],
		['Land_CamoNet_EAST',[6,-2,0],0],
		['Hedgehog',[-10,-8,0],0],
		['Hedgehog',[10,-8,0],0]
	]];

	//--- MIXED POST (LIGHT, 2 AI) WEST — .50 + TOW interlocking front arcs, rear Stinger (air + blind side), central ammo, flank walls, forward wire.
	missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_WEST',[
		['M2StaticMG',[-5,3,0],335],
		['TOW_TriPod_US_EP1',[5,3,0],25],
		['Stinger_Pod_US_EP1',[0,-4,0],180],
		['Land_fort_bagfence_round',[-5,3,0],0],
		['Land_fort_bagfence_round',[5,3,0],0],
		['Land_fort_bagfence_round',[0,-4,0],0],
		['USBasicAmmunitionBox_EP1',[0,0,0],0],
		['Land_fort_bagfence_long',[-7,0,0],0],
		['Land_fort_bagfence_long',[7,0,0],0],
		['Fort_RazorWire',[0,6,0],0]
	]];

	//--- MIXED POST (LIGHT, 2 AI) EAST — DShK + SPG-9 interlocking arcs, rear Igla, central ammo, flank walls, forward wire.
	missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_EAST',[
		['DSHKM_TK_INS_EP1',[-5,3,0],335],
		['SPG9_TK_INS_EP1',[5,3,0],25],
		['Igla_AA_pod_TK_EP1',[0,-4,0],180],
		['Land_fort_bagfence_round',[-5,3,0],0],
		['Land_fort_bagfence_round',[5,3,0],0],
		['Land_fort_bagfence_round',[0,-4,0],0],
		['TKBasicAmmunitionBox_EP1',[0,0,0],0],
		['Land_fort_bagfence_long',[-7,0,0],0],
		['Land_fort_bagfence_long',[7,0,0],0],
		['Fort_RazorWire',[0,6,0],0]
	]];

	//--- MIXED STRONGPOINT (HEAVY, 4 AI) WEST — twin .50 + TOW + rear Stinger + COVERED INFANTRY BUNKER fallback, HBarrier horseshoe, forward wire.
	missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_HEAVY_WEST',[
		['M2StaticMG',[-9,3,0],330],
		['M2StaticMG',[9,3,0],30],
		['TOW_TriPod_US_EP1',[0,6,0],0],
		['Stinger_Pod_US_EP1',[0,-3,0],180],
		['Land_fortified_nest_small_EP1',[0,-6,0],0],
		['Land_fort_bagfence_round',[-9,3,0],0],
		['Land_fort_bagfence_round',[9,3,0],0],
		['USBasicAmmunitionBox_EP1',[-4,0,0],0],
		['USBasicAmmunitionBox_EP1',[4,0,0],0],
		['Land_HBarrier_large',[-11,3,0],90],
		['Land_HBarrier_large',[11,3,0],90],
		['Land_HBarrier_large',[-6,9,0],0],
		['Land_HBarrier_large',[6,9,0],0],
		['Land_fort_bagfence_corner',[-10,-2,0],270],
		['Land_fort_bagfence_corner',[10,-2,0],180],
		['Fort_RazorWire',[-7,7,0],0],
		['Fort_RazorWire',[7,7,0],0]
	]];

	//--- MIXED STRONGPOINT (HEAVY, 4 AI) EAST — twin DShK + Metis + rear Igla + COVERED INFANTRY BUNKER fallback, HBarrier horseshoe + rear screen, forward traps.
	missionNamespace setVariable ['WFBE_NEURODEF_MIXEDPOS_HEAVY_EAST',[
		['DSHKM_TK_INS_EP1',[-9,3,0],330],
		['DSHKM_TK_INS_EP1',[9,3,0],30],
		['Metis_TK_EP1',[0,6,0],0],
		['Igla_AA_pod_TK_EP1',[0,-3,0],180],
		['Land_fortified_nest_small_EP1',[0,-6,0],0],
		['Land_fort_bagfence_round',[-9,3,0],0],
		['Land_fort_bagfence_round',[9,3,0],0],
		['TKBasicAmmunitionBox_EP1',[-4,0,0],0],
		['TKBasicAmmunitionBox_EP1',[4,0,0],0],
		['Land_HBarrier_large',[-11,3,0],90],
		['Land_HBarrier_large',[11,3,0],90],
		['Land_HBarrier_large',[-6,9,0],0],
		['Land_HBarrier_large',[6,9,0],0],
		['Land_HBarrier_large',[-6,-3,0],0],
		['Land_HBarrier_large',[6,-3,0],0],
		['Hedgehog',[-7,7,0],0],
		['Hedgehog',[7,7,0],0],
		['Fort_RazorWire',[0,-8,0],0]
	]];

};

//======================================================================================
//--- cmdcon44-c (Build 89): FORTIFICATIONS SET (Ray item 36 "same for fortifications"). Three new
//--- side-neutral fortification compositions, likewise WDDM-authored (docs/design/compositions/
//--- fort_*.wddm.json) + converted below, wired into WFBE_POSITION_TEMPLATE_MAP + the Core_CIV
//--- Fortification menu rows. Always defined (harmless if a side's menu list omits the anchor).
//======================================================================================
//--- INFANTRY STRONGPOINT (fortification, side-neutral) — central Bunker (large) hard core, two forward fighting bays with interlocking arcs, comms-trench bag runs linking them, flank ramparts (dispersion), rear resupply, open covered entrance, forward canalizing wire.
missionNamespace setVariable ['WFBE_NEURODEF_FORT_STRONGPOINT',[
	['Land_fortified_nest_big_EP1',[0,0,0],0],
	['Land_fort_bagfence_corner',[-7,6,0],0],
	['Land_fort_bagfence_long',[-7,6,0],90],
	['Land_fort_bagfence_corner',[7,6,0],270],
	['Land_fort_bagfence_long',[7,6,0],90],
	['Land_fort_bagfence_long',[-4,3,0],25],
	['Land_fort_bagfence_long',[4,3,0],335],
	['Land_fort_rampart',[-9,-1,0],0],
	['Land_fort_rampart',[9,-1,0],0],
	['USBasicAmmunitionBox_EP1',[-2,-3,0],0],
	['Fort_RazorWire',[-4,9,0],15],
	['Fort_RazorWire',[4,9,0],345]
]];

//--- ROADBLOCK / CHECKPOINT (fortification, side-neutral) — staggered concrete chicane forces vehicles single-file, gate stop line, mutually-supporting bag-fence guard positions, rear camo-netted shelter, shoulder tank traps, warning sign/cones, tie-in wire.
missionNamespace setVariable ['WFBE_NEURODEF_FORT_CHECKPOINT',[
	['Land_CncBlock_Stripes',[-3,5,0],0],
	['Land_CncBlock_Stripes',[3,2,0],0],
	['Land_CncBlock_Stripes',[-3,-1,0],0],
	['Land_BarGate2',[0,3.5,0],0],
	['Land_fort_bagfence_corner',[-6,3,0],0],
	['Land_fort_bagfence_long',[-6,3,0],90],
	['Land_fort_bagfence_corner',[6,1,0],270],
	['Land_fort_bagfence_long',[6,1,0],90],
	['Misc_cargo_cont_small',[-5,-3,0],90],
	['Land_CamoNetVar_NATO',[-5,-2.4,0],0],
	['Hedgehog',[-8,5,0],0],
	['Hedgehog',[8,5,0],0],
	['Sign_Danger',[2,6,0],180],
	['RoadCone',[-1.5,7,0],0],
	['RoadCone',[1.5,7,0],0],
	['Fort_RazorWire',[-8,2,0],0],
	['Fort_RazorWire',[8,-1,0],0]
]];

//--- OBSERVATION POST (fortification, side-neutral) — elevated bunker-tower for long fields of view, camo net breaking the silhouette, low bag-ring fallback (not a bastion), concealed rear supply cache, single discreet forward wire. Concealment over firepower.
missionNamespace setVariable ['WFBE_NEURODEF_FORT_OP',[
	['Land_Fort_Watchtower_EP1',[0,2,0],0],
	['Land_CamoNetVar_NATO',[0,4,0],0],
	['Land_fort_bagfence_round',[0,-1,0],0],
	['Land_fort_bagfence_long',[-4,0,0],90],
	['Land_fort_bagfence_long',[4,0,0],90],
	['USBasicAmmunitionBox_EP1',[-2,-3,0],0],
	['Land_CamoNetVar_NATO',[-2,-3,0],0],
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
	['Land_Ind_Timbers','WFBE_NEURODEF_WALL_GATE',false],
	//--- cmdcon42-g menu v2 anchors (side-neutral hedgehog line; faction-specific flak tower).
	['Misc_cargo_cont_small','WFBE_NEURODEF_HEDGEHOGLINE',false],	//--- Hedgehog Line (AT obstacle)
	['Land_Ind_TankSmall','WFBE_NEURODEF_FLAKTOWER',true],			//--- Flak Tower (elevated AA, 1 AI)
	//--- cmdcon44-c WDDM fortifications set (side-neutral compositions; ghosts are unused cargo/barrel models).
	['Land_Misc_Cargo1B','WFBE_NEURODEF_FORT_STRONGPOINT',false],		//--- Infantry Strongpoint
	['Land_transport_crates_EP1','WFBE_NEURODEF_FORT_CHECKPOINT',false],	//--- Roadblock / Checkpoint
	['Land_Barrel_water','WFBE_NEURODEF_FORT_OP',false]					//--- Observation Post
];
WFBE_POSITION_ANCHOR_NAMES = ['Land_Ind_BoardsPack1','Land_CncBlock_Stripes','Land_Barrel_sand','Land_Ind_BoardsPack2','Land_WoodenRamp','RoadCone','Paleta1','Paleta2','Land_Ind_Timbers','Misc_cargo_cont_small','Land_Ind_TankSmall','Land_Misc_Cargo1B','Land_transport_crates_EP1','Land_Barrel_water'];
