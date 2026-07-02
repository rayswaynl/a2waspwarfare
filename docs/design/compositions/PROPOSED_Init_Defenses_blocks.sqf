/* =====================================================================================
   PROPOSED composition blocks — drop-in replacements for the matching WFBE_NEURODEF_*
   variables in Server\Init\Init_Defenses.sqf.  DESIGN LANE INPUT ONLY — not wired.

   RAY SPEC (2026-07-02): compositions are a PURE WALL-MATERIAL LADDER, nothing else.
     LOW    (Barracks, Light)            = small walls  -> Land_fort_bagfence_long
     MEDIUM (Heavy, ServicePoint, Bank)  = big walls    -> Base_WarfareBBarrier10x / Land_HBarrier_large
     HIGH   (Command Center, Aircraft)   = CONCRETE     -> Concrete_Wall_EP1
                                            (the EXACT class the HQ uses:
                                             WFBE_NEURODEF_HEADQUARTERS_WALLS, this file l.183-207)
   No wire, no nests, no towers, no bunkers, no flags, no chicanes. Ring of the tier's
   wall type with access gaps, period.

   Format identical to the live file: ['classname',[xOff,yOff,zOff],relDir].
   +Y = building FRONT, +X = building RIGHT, Z auto-flattened by the spawner.
   Consumed unchanged by CreateDefenseTemplate (auto-walls) and, for the Bank, by
   WFBE_SE_FNC_SpawnStructureDressing. Missing classes are logged + skipped (fail-safe).

   ACCESS RULES (verified per block below): vehicle factories keep the +X (model-right)
   face fully OPEN — that is the pad / fallback-egress side (Client_BuildUnit.sqf,
   fallback _dir=90). No block covers the building footprint. No closed rings; every
   ring has >=1 walking gap and open corners (A2-AI-pathable).

   Segment lengths for the gap math: bagfence_long ~2.85 m · Concrete_Wall_EP1 ~3.6 m ·
   Land_HBarrier_large ~5 m · Base_WarfareBBarrier10x ~24 m.
   All four classes are IN-TREE (already spawned by live templates in this same file).
   ===================================================================================== */

//--- BARRACKS (LOW = bagfence). 18x12, infantry factory, no vehicle egress.
//--- Front firing line with a ~3 m centre foot gap + one short flank step each side.
//--- Sides/rear otherwise open. 6 objects. NO closed ring.
missionNamespace setVariable ['WFBE_NEURODEF_BARRACKS_WALLS',[
	['Land_fort_bagfence_long',[-6,8,0],0],['Land_fort_bagfence_long',[-2.9,8,0],0],
	['Land_fort_bagfence_long',[2.9,8,0],0],['Land_fort_bagfence_long',[6,8,0],0],
	['Land_fort_bagfence_long',[-10,0,0],90],['Land_fort_bagfence_long',[10,0,0],90]
]];

//--- LIGHT FACTORY (LOW = bagfence). 22x14, vehicles exit +X (right) -> right face OPEN.
//--- Front + rear firing lines (each with a ~4 m centre foot gap) + a short left screen.
//--- 10 objects. NO closed ring; +X fully clear.
missionNamespace setVariable ['WFBE_NEURODEF_LIGHT_WALLS',[
	['Land_fort_bagfence_long',[-6.5,9,0],0],['Land_fort_bagfence_long',[-3.4,9,0],0],
	['Land_fort_bagfence_long',[3.4,9,0],0],['Land_fort_bagfence_long',[6.5,9,0],0],
	['Land_fort_bagfence_long',[-6.5,-9,0],0],['Land_fort_bagfence_long',[-3.4,-9,0],0],
	['Land_fort_bagfence_long',[3.4,-9,0],0],['Land_fort_bagfence_long',[6.5,-9,0],0],
	['Land_fort_bagfence_long',[-13,1.6,0],90],['Land_fort_bagfence_long',[-13,-1.6,0],90]
]];

//--- HEAVY FACTORY (MEDIUM = big HESCO). 28x16, armor exits +X (right) -> right face OPEN.
//--- Three 24 m HESCO slabs: front, rear, left. Corner foot gaps ~5 m where the slabs
//--- don't meet; right side fully clear. 3 objects (one slab = one object, FPS-light).
missionNamespace setVariable ['WFBE_NEURODEF_HEAVY_WALLS',[
	['Base_WarfareBBarrier10x',[0,12,0],0],
	['Base_WarfareBBarrier10x',[0,-12,0],0],
	['Base_WarfareBBarrier10x',[-17,0,0],90]
]];

//--- SERVICE POINT (MEDIUM = big HESCO). 16x8, vehicles drive up on either side -> keep
//--- BOTH X faces open; single rear slab only. Today this template is empty []. 1 object.
//--- OPTIONAL — include only if Ray wants Service in the ladder (he listed it MEDIUM).
missionNamespace setVariable ['WFBE_NEURODEF_SERVICEPOINT_WALLS',[
	['Base_WarfareBBarrier10x',[0,7,0],0]
]];

//--- AIRCRAFT FACTORY (HIGH = concrete, HQ-grade). 30x18, aircraft exit +X (right) ->
//--- right face OPEN as the taxi apron. Concrete_Wall_EP1 (the HQ's wall class) on
//--- front, rear and left; all four corners open ~4 m+; 16 objects.
missionNamespace setVariable ['WFBE_NEURODEF_AIRCRAFT_WALLS',[
	['Concrete_Wall_EP1',[-9,12,0],0],['Concrete_Wall_EP1',[-5.4,12,0],0],['Concrete_Wall_EP1',[-1.8,12,0],0],
	['Concrete_Wall_EP1',[1.8,12,0],0],['Concrete_Wall_EP1',[5.4,12,0],0],['Concrete_Wall_EP1',[9,12,0],0],
	['Concrete_Wall_EP1',[-9,-12,0],0],['Concrete_Wall_EP1',[-5.4,-12,0],0],['Concrete_Wall_EP1',[-1.8,-12,0],0],
	['Concrete_Wall_EP1',[1.8,-12,0],0],['Concrete_Wall_EP1',[5.4,-12,0],0],['Concrete_Wall_EP1',[9,-12,0],0],
	['Concrete_Wall_EP1',[-18,-5.4,0],90],['Concrete_Wall_EP1',[-18,-1.8,0],90],
	['Concrete_Wall_EP1',[-18,1.8,0],90],['Concrete_Wall_EP1',[-18,5.4,0],90]
]];

//--- COMMAND CENTER (HIGH = concrete, HQ-grade). 12x10, no vehicle egress. The HQ box
//--- pattern at small scale: concrete on all four faces, single ~3.6 m walking gate on
//--- the front (-Y), corner gaps ~2-3 m. 11 objects. NOT a closed ring (gate + corners).
missionNamespace setVariable ['WFBE_NEURODEF_COMMANDCENTER_WALLS',[
	['Concrete_Wall_EP1',[-3.6,7,0],0],['Concrete_Wall_EP1',[0,7,0],0],['Concrete_Wall_EP1',[3.6,7,0],0],
	['Concrete_Wall_EP1',[-7,-3.6,0],90],['Concrete_Wall_EP1',[-7,0,0],90],['Concrete_Wall_EP1',[-7,3.6,0],90],
	['Concrete_Wall_EP1',[7,-3.6,0],90],['Concrete_Wall_EP1',[7,0,0],90],['Concrete_Wall_EP1',[7,3.6,0],90],
	['Concrete_Wall_EP1',[-3.6,-7,0],0],['Concrete_Wall_EP1',[3.6,-7,0],0]
]];

/* -------------------------------------------------------------------------------------
   BANK (MEDIUM = big walls). Dressing path (WFBE_SE_FNC_SpawnStructureDressing) —
   REPLACES the WFBE_NEURODEF_BANK_WEST / _EAST bodies. Both sides are identical now
   (no faction props left), so one array serves both. Sized to a ~16x12 model
   (Land_fortified_nest_big_EP1 today / Land_A_Office01_EP1 proposed — part C).
   24 m HESCO slabs on rear + both sides; HBarrier_large front with a single ~5 m raid
   gate; rear corners open ~3 m. 7 objects (was ~24). NOT a closed ring.
   ------------------------------------------------------------------------------------- */
missionNamespace setVariable ['WFBE_NEURODEF_BANK_WEST',[
	['Base_WarfareBBarrier10x',[0,13,0],0],
	['Base_WarfareBBarrier10x',[-15,0,0],90],
	['Base_WarfareBBarrier10x',[15,0,0],90],
	['Land_HBarrier_large',[-10,-13,0],0],['Land_HBarrier_large',[-5,-13,0],0],
	['Land_HBarrier_large',[5,-13,0],0],['Land_HBarrier_large',[10,-13,0],0]
]];
missionNamespace setVariable ['WFBE_NEURODEF_BANK_EAST', missionNamespace getVariable 'WFBE_NEURODEF_BANK_WEST'];
