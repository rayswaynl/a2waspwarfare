# Mixed Saturation Strike — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a commander-called "Drone Strike" tactical support — a 5-ship crewless drone package (2 flare/CM + 3 loitering munitions) that ingresses from the map edge to a map-clicked point and hard-kills enemy ground vehicles, with `.50`-cal+ counterplay, mirror faction balance, and a Stuka dive siren.

**Architecture:** Server-authoritative. Front-end clones the **ICBM map-click capture** but uses the **Paratroops server hand-off** (`RequestSpecial → SendToServer → Server_HandleSpecial case → KAT_DroneStrike`). New server orchestrator `Support_DroneStrike.sqf` spawns/flies/acquires/strikes/despawns; clients render FX (flares + siren) off a broadcast. Reuses ICBM (launch UX), Paratroopers (map-edge spawn + fly-to-point), UAV (createVehicle crewless airframe + lifecycle), and the IRS module (flare/CM deflection).

**Tech Stack:** Arma 2 OA SQF. No automated test harness exists — **verification is in-engine on the test rig** (pack with `pack_pbo.py`, load the Chernarus mission, observe). Each task ends with an explicit in-engine or syntax-check verification.

**Spike-first:** the entire flight layer hinges on whether a *crewless* airframe flies acceptably under script (no AI-pilot precedent exists in this mission). **Task 1 is a throwaway spike that decides the flight primitive before we build the real orchestrator.** Do not write the full orchestrator until the spike passes.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Common/Init/Init_CommonConstants.sqf` | modify | `WFBE_C_DRONE_*` constants |
| `Common/Config/Core_Root/Root_*.sqf` (RU, INS, USMC, CDF, US_Camo, …) | modify | `WFBE_%1DRONE` model var (defaults to `WFBE_%1UAV`) |
| `Sounds/description.ext` | modify | `CfgSounds` entry `drone_stuka` |
| `Sounds/drone_stuka-10.ogg` | add (asset) | Ju-87 Jericho-trumpet siren |
| `stringtable.xml` | modify | UI strings |
| `Client/GUI/GUI_Menu_Tactical.sqf` | modify | list row + enable case + request case + map-click handler (MenuAction 11) |
| `Server/Init/Init_Server.sqf` | modify | `KAT_DroneStrike = Compile preprocessFile …` |
| `Server/Functions/Server_HandleSpecial.sqf` | modify | `case "DroneStrike"` |
| `Server/Support/Support_DroneStrike.sqf` | **create** | orchestrator: spawn → fly → acquire → dive → despawn + scripted HP |
| `Common/Functions/Common_DroneFX.sqf` | **create** | client FX: flare pops + Stuka siren off broadcast |

## Final constants (in `Init_CommonConstants.sqf`, inside the `with missionNamespace do {` block)

```sqf
//--- Drone Saturation Strike (System B).
if (isNil "WFBE_C_DRONE_FLARE_COUNT") then {WFBE_C_DRONE_FLARE_COUNT = 2};       //--- # flare/CM drones
if (isNil "WFBE_C_DRONE_MUNITION_COUNT") then {WFBE_C_DRONE_MUNITION_COUNT = 3}; //--- # loitering munitions
if (isNil "WFBE_C_DRONE_INGRESS_SPEED") then {WFBE_C_DRONE_INGRESS_SPEED = 60};  //--- m/s transit
if (isNil "WFBE_C_DRONE_LOITER_SPEED") then {WFBE_C_DRONE_LOITER_SPEED = 35};    //--- m/s orbit
if (isNil "WFBE_C_DRONE_CRUISE_ALT") then {WFBE_C_DRONE_CRUISE_ALT = 200};       //--- m AGL
if (isNil "WFBE_C_DRONE_LOITER_TIME") then {WFBE_C_DRONE_LOITER_TIME = 90};      //--- s before forced commit
if (isNil "WFBE_C_DRONE_ZONE_RADIUS") then {WFBE_C_DRONE_ZONE_RADIUS = 250};     //--- m acquisition radius
if (isNil "WFBE_C_DRONE_WARHEAD") then {WFBE_C_DRONE_WARHEAD = "Sh_125_HE"};     //--- survivable warhead
if (isNil "WFBE_C_DRONE_SCATTER") then {WFBE_C_DRONE_SCATTER = 12};              //--- m impact scatter
if (isNil "WFBE_C_DRONE_HP") then {WFBE_C_DRONE_HP = 6};                         //--- ≈ .50-cal hits to down
if (isNil "WFBE_C_DRONE_MIN_HIT") then {WFBE_C_DRONE_MIN_HIT = 0.08};            //--- min HandleDamage delta that counts (≥.50)
if (isNil "WFBE_C_DRONE_DIVE_STAGGER") then {WFBE_C_DRONE_DIVE_STAGGER = 1.5};   //--- s between dives
if (isNil "WFBE_C_DRONE_COST") then {WFBE_C_DRONE_COST = 22000};                 //--- server-validated cost
if (isNil "WFBE_C_DRONE_COOLDOWN") then {WFBE_C_DRONE_COOLDOWN = 360};           //--- s cooldown
if (isNil "WFBE_C_DRONE_CONCURRENT_CAP") then {WFBE_C_DRONE_CONCURRENT_CAP = 1}; //--- max packages/side in flight
```

---

## Task 0: Scaffolding — constants, model var, sound, strings, list row, server registration

No flight logic; this is the safe, mechanical wiring. After this the new menu entry appears and the server route exists (but does nothing yet).

**Files:**
- Modify: `Common/Init/Init_CommonConstants.sqf` (inside the `with missionNamespace do {` block, ~line 240)
- Modify: `Common/Config/Core_Root/Root_RU.sqf:17`, `Root_INS.sqf`, `Root_USMC.sqf:18`, `Root_CDF.sqf`, `Root_US_Camo.sqf`, and any other `Root_*.sqf` that sets `WFBE_%1UAV`
- Modify: `Sounds/description.ext` (before the final `};`, ~line 160)
- Modify: `stringtable.xml` (after line 4, inside `<Container name="WF">`)
- Modify: `Client/GUI/GUI_Menu_Tactical.sqf:58-61`
- Modify: `Server/Init/Init_Server.sqf:42`
- Modify: `Server/Functions/Server_HandleSpecial.sqf:65`

- [ ] **Step 1: Add the constants block** to `Init_CommonConstants.sqf` (paste the "Final constants" block above immediately after the ICBM-era constants near line 240, still inside `with missionNamespace do {`).

- [ ] **Step 2: Add the model var** after each `WFBE_%1UAV` line in every `Root_*.sqf`. Example for `Root_RU.sqf` (after line 17):

```sqf
missionNamespace setVariable [Format["WFBE_%1DRONE", _side], (missionNamespace getVariable Format["WFBE_%1UAV", _side])];
```

Use the identical line in `Root_USMC.sqf`, `Root_CDF.sqf`, `Root_INS.sqf`, `Root_US_Camo.sqf`, and any other Root that sets `WFBE_%1UAV`. (Defaults the drone model to that faction's UAV — Predator/Pchela — cosmetic only.)

- [ ] **Step 3: Add the CfgSounds entry** in `Sounds/description.ext`, before the closing `};` at line 161:

```cpp
    class drone_stuka {
        name = "drone_stuka";
        sound[] = {"\Sounds\drone_stuka-10.ogg", 10, 1};
        titles[] = {};
    };
```

- [ ] **Step 4: Drop in the sound asset** `Sounds/drone_stuka-10.ogg` (a Ju-87 "Jericho trumpet" dive siren, mono OGG). If not yet sourced, commit a short silent placeholder OGG so the config validates; the feature works (silently) until the real clip lands. **Mark this asset as a follow-up TODO in the PR description.**

- [ ] **Step 5: Add stringtable keys** in `stringtable.xml` after line 4 (`<Container name="WF">`):

```xml
<Key ID="STR_WF_TACTICAL_DroneStrike">
       <English>Drone Strike</English>
        <French>Frappe de drones</French>
        <German>Drohnenangriff</German>
        <Russian>Удар дронов</Russian>
        <Italian>Attacco droni</Italian>
      </Key>
<Key ID="STR_WF_TACTICAL_DroneStrike_Info">
       <English>Drone package inbound. They will saturate the target area.</English>
        <French>Drones en approche.</French>
        <German>Drohnenpaket im Anflug.</German>
        <Russian>Дроны на подходе.</Russian>
        <Italian>Droni in arrivo.</Italian>
      </Key>
```

- [ ] **Step 6: Add the support list row.** In `GUI_Menu_Tactical.sqf`, append `"DroneStrike"` to the four parallel arrays at lines 58–61 (add as the LAST element of each):

```sqf
_addToList = [localize 'STR_WF_TACTICAL_FastTravel',localize 'STR_WF_ICBM',localize 'STR_WF_TACTICAL_ParadropAmmo',localize 'STR_WF_TACTICAL_ParadropVehicle',localize 'STR_WF_TACTICAL_Paratroop',localize 'STR_WF_TACTICAL_UnitCam',localize 'STR_WF_TACTICAL_UAV',localize 'STR_WF_TACTICAL_UAVDestroy',localize 'STR_WF_TACTICAL_UAVRemoteControl',localize 'STR_WF_TACTICAL_DroneStrike'];
_addToListID = ["Fast_Travel","ICBM","Paradrop_Ammo","Paradrop_Vehicle","Paratroopers","Units_Camera","UAV","UAV_Destroy","UAV_Remote_Control","DroneStrike"];
_addToListFee = [0,75000,9500,3500,8500,0,12500,0,0,22000];
_addToListInterval = [0,1000,800,600,900,0,0,0,0,360];
```

- [ ] **Step 6b: Add the enable/disable case.** In `GUI_Menu_Tactical.sqf`, inside the `switch (_currentSpecial)` at lines 245–287, after the `case "UAV_Remote_Control":` block (line 283):

```sqf
			case "DroneStrike": {
				if (isNil "lastDroneCall") then {lastDroneCall = -99999};
				_currentLevel = _currentUpgrades select WFBE_UP_UAV;
				_controlEnable = if (_funds >= _currentFee && _currentLevel > 0 && time - lastDroneCall > _currentInterval) then {true} else {false};
			};
```

- [ ] **Step 6c: Add the request case.** In the `switch (_currentSpecial)` at lines 298–344 (the `if (MenuAction == 20)` block), after `case "Units_Camera":` (line 343):

```sqf
				case "DroneStrike": {
					MenuAction = 11;
					if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
					_textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim;
				};
```

- [ ] **Step 6d: Add the map-click handler.** In the `if (mouseButtonUp == 0)` block, after the Ammo-Paradrop handler (`MenuAction == 10`, ends line 528) and before that block's closing `};` (line 529):

```sqf
			//--- Drone Strike.
			if (MenuAction == 11) then {
				MenuAction = -1;
				_forceReload = true;
				if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
				[17022] Call SetControlFadeAnimStop;
				_callPos = _map posScreenToWorld[mouseX,mouseY];
				if (!surfaceIsWater _callPos) then {
					lastDroneCall = time;
					-(_currentFee) Call ChangePlayerFunds;
					["RequestSpecial", ["DroneStrike",sideJoined,_callPos,clientTeam]] Call WFBE_CO_FNC_SendToServer;
					hint localize "STR_WF_TACTICAL_DroneStrike_Info";
				};
			};
```

- [ ] **Step 7: Register the server function.** In `Server/Init/Init_Server.sqf`, after line 42:

```sqf
KAT_DroneStrike = Compile preprocessFile "Server\Support\Support_DroneStrike.sqf";
```

- [ ] **Step 8: Add the server dispatch case.** In `Server/Functions/Server_HandleSpecial.sqf`, after the `case "uav":` block (line 65):

```sqf
	case "DroneStrike": {
		_args spawn KAT_DroneStrike;
	};
```

- [ ] **Step 9 (verify):** Create a minimal stub `Server/Support/Support_DroneStrike.sqf` so Step 7 compiles:

```sqf
["INFORMATION", Format["Support_DroneStrike.sqf : [%1] requested at %2.", _this select 1, _this select 2]] Call WFBE_CO_FNC_LogContent;
```

Pack the mission (`pack_pbo.py`), load on the test rig as commander with the UAV upgrade, open the Tactical menu → confirm **"Drone Strike"** appears in the support list and (next task) the gate logic. Check the server `.rpt` for the log line after requesting. Expected: menu row present, no script errors on mission load.

- [ ] **Step 10: Commit**

```bash
git add -A && git commit -m "feat(drone): scaffold Drone Strike tactical entry + server route"
```

---

## Task 1: SPIKE — decide the flight primitive (throwaway)

Prove a *crewless* airframe flies acceptably under script. This replaces the Task-0 stub temporarily; its result decides the orchestrator's flight code.

**Files:** Modify: `Server/Support/Support_DroneStrike.sqf` (spike body)

- [ ] **Step 1: Write the spike** — spawn ONE crewless drone at a map edge, fly it to the clicked point, loiter a circle for 30 s, despawn:

```sqf
Private ["_side","_destination","_model","_bd","_corners","_spawnPos","_drone","_alt","_speed","_t","_hdg","_tgt"];
_side = _this select 1;
_destination = _this select 2;
_model = missionNamespace getVariable Format ["WFBE_%1DRONE", str _side];
if (isNil "_model") then {_model = missionNamespace getVariable Format ["WFBE_%1UAV", str _side]};
_alt = WFBE_C_DRONE_CRUISE_ALT;
_speed = WFBE_C_DRONE_INGRESS_SPEED;

_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
_corners = if (isNil "_bd") then {[[0,0,_alt]]} else {[[0,0,_alt],[0,_bd,_alt],[_bd,_bd,_alt],[_bd,0,_alt]]};
_spawnPos = _corners select (floor random count _corners);

_drone = createVehicle [_model, _spawnPos, [], 0, "FLY"];
_drone setPosATL _spawnPos;
_drone allowDamage false;     //--- spike only: isolate flight from being shot
_drone flyInHeight _alt;

//--- METHOD A (preferred, no AI): scripted forward thrust + heading steer.
_tgt = +_destination; _tgt set [2, _alt];
while {alive _drone && ((_drone distance2D _tgt) > 60)} do {
	_hdg = (_drone) getDir _tgt;
	_drone setDir _hdg;
	_drone setVectorDirAndUp [[sin _hdg, cos _hdg, 0],[0,0,1]];
	_drone setVelocityModelSpace [0, _speed, 0];
	_drone setPosATL [(getPosATL _drone) select 0,(getPosATL _drone) select 1,_alt]; //--- altitude lock
	sleep 0.08;
};

//--- loiter a circle for 30s.
_t = time;
while {alive _drone && (time - _t < 30)} do {
	_ang = ((time - _t) * (_speed / WFBE_C_DRONE_ZONE_RADIUS)) * (180/pi);
	_pt = [_destination, WFBE_C_DRONE_ZONE_RADIUS, _ang] call BIS_fnc_relPos;
	_hdg = (_drone) getDir _pt;
	_drone setDir _hdg;
	_drone setVectorDirAndUp [[sin _hdg, cos _hdg, -0.05],[0,0,1]];
	_drone setVelocityModelSpace [0, WFBE_C_DRONE_LOITER_SPEED, 0];
	_drone setPosATL [(getPosATL _drone) select 0,(getPosATL _drone) select 1,_alt];
	sleep 0.08;
};
deleteVehicle _drone;
```

- [ ] **Step 2 (verify in-engine):** Pack, load, call Drone Strike on a visible grid. **Observe:** does the airframe travel smoothly from the edge to the point and circle without violently pitching, stalling, or exploding? Watch server `.rpt` for errors.
  - **PASS** → Method A is the flight primitive; proceed to Task 2 using this movement code.
  - **FAIL** (jitter/flips/explodes) → switch to **Method B fallback**: give the drone an AI pilot on `CARELESS`/`STEALTH` and use `doMove`/`AIMoveTo` waypoints (proven by `Support_Paratroopers.sqf`). Replace the two `while` loops with: create a pilot via `WFBE_CO_FNC_CreateUnit`, `moveInDriver`, `_grp setBehaviour "CARELESS"`, disable `AUTOTARGET`/`TARGET`, `_drone flyInHeight _alt`, `_pilot doMove _destination`, then a `waitUntil {_drone distance2D _destination < 300}`. Record the decision in the spec §12.

- [ ] **Step 3: Record the outcome** (one line in the PR description + spec §12): "Flight primitive = Method A (scripted)" or "Method B (AI pilot)". Do **not** commit the spike as-is — it becomes Task 2.

---

## Task 2: Orchestrator — package spawn, roles, ingress, acquire, staggered dive, despawn

Build the real `Support_DroneStrike.sqf` on the spike-proven flight primitive. (Code below assumes Method A; if Method B was chosen, swap the inner movement loop per Task 1 Step 2.)

**Files:** Modify: `Server/Support/Support_DroneStrike.sqf`

- [ ] **Step 1: Write the orchestrator.**

```sqf
Private ["_side","_destination","_playerTeam","_sideID","_model","_bd","_corners","_spawnPos",
	"_total","_drones","_i","_role","_drone","_alt","_speed","_activeKey","_active","_endTime","_grp"];

_side = _this select 1;
_destination = _this select 2;
_playerTeam = _this select 3;
_sideID = _side Call GetSideID;
_alt = WFBE_C_DRONE_CRUISE_ALT;
_speed = WFBE_C_DRONE_INGRESS_SPEED;
_total = WFBE_C_DRONE_FLARE_COUNT + WFBE_C_DRONE_MUNITION_COUNT;

["INFORMATION", Format["Support_DroneStrike.sqf : [%1] Team [%2] drone strike at %3.", str _side, _playerTeam, _destination]] Call WFBE_CO_FNC_LogContent;

//--- Concurrent cap (per side).
_activeKey = Format["WFBE_DRONE_ACTIVE_%1", str _side];
_active = missionNamespace getVariable [_activeKey, 0];
if (_active >= WFBE_C_DRONE_CONCURRENT_CAP) exitWith {
	["INFORMATION","Support_DroneStrike.sqf : concurrent cap reached, ignoring."] Call WFBE_CO_FNC_LogContent;
};
missionNamespace setVariable [_activeKey, _active + 1];

_model = missionNamespace getVariable Format ["WFBE_%1DRONE", str _side];
if (isNil "_model") then {_model = missionNamespace getVariable Format ["WFBE_%1UAV", str _side]};

//--- Map-edge spawn (clone of Support_Paratroopers).
_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
_corners = if (isNil "_bd") then {[[0,0,_alt]]} else {
	[[0+random 200,0+random 200,_alt],[0+random 200,_bd-random 200,_alt],[_bd-random 200,_bd-random 200,_alt],[_bd-random 200,0+random 200,_alt]]
};
_spawnPos = _corners select (floor random count _corners);

//--- Spawn the package crewless.
_drones = [];
for "_i" from 0 to (_total - 1) do {
	_role = if (_i < WFBE_C_DRONE_FLARE_COUNT) then {"flare"} else {"munition"};
	_drone = createVehicle [_model, _spawnPos, [], 0, "FLY"];
	_drone setPosATL [(_spawnPos select 0) + (_i * 18), (_spawnPos select 1) + (_i * 12), _alt]; //--- formation spread
	_drone setVariable ["wfbe_drone_role", _role, true];
	_drone setVariable ["wfbe_drone_hp", WFBE_C_DRONE_HP, true];
	_drone flyInHeight _alt;
	_drone addEventHandler ["HandleDamage", {_this call WFBE_DroneHandleDamage}];      //--- Task 3
	_drone addEventHandler ["Killed", Compile Format["[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled",_sideID]];
	_drone setVariable ["wfbe_phase", _i, true];   //--- staggers dives + spreads orbit
	_drones pushBack _drone;
};
processInitCommands;

//--- Ingress: fly each drone to the zone (Method A movement; per-drone spawn).
{
	private "_d"; _d = _x;
	[_d, _destination, _alt, _speed] spawn {
		params ["_d","_dest","_alt","_speed"];
		private "_tgt"; _tgt = +_dest; _tgt set [2,_alt];
		while {alive _d && ((_d distance2D _tgt) > (60 + random 80))} do {
			private "_h"; _h = _d getDir _tgt;
			_d setDir _h;
			_d setVectorDirAndUp [[sin _h, cos _h, 0],[0,0,1]];
			_d setVelocityModelSpace [0,_speed,0];
			_d setPosATL [(getPosATL _d) select 0,(getPosATL _d) select 1,_alt];
			sleep 0.08;
		};
		_d setVariable ["wfbe_drone_arrived", true, true];
	};
} forEach _drones;

//--- Loiter + flare screen + acquire, until commit timer.
_endTime = time + WFBE_C_DRONE_LOITER_TIME;
{
	private "_d"; _d = _x;
	[_d, _destination, _endTime, _sideID, _side] spawn {
		params ["_d","_dest","_endTime","_sideID","_side"];
		waitUntil {sleep 0.5; (_d getVariable ["wfbe_drone_arrived",false]) || !alive _d || time > _endTime};
		if (!alive _d) exitWith {};
		private "_role"; _role = _d getVariable "wfbe_drone_role";

		if (_role == "flare") then {
			//--- Flare drone: orbit + pop flares on incoming missiles (Task 4 wires the EH).
			_d addEventHandler ["incomingMissile", {_this call WFBE_DroneOnIncoming}];
			while {alive _d && time < _endTime + 20} do {
				private "_ang"; _ang = (time * (WFBE_C_DRONE_LOITER_SPEED / WFBE_C_DRONE_ZONE_RADIUS)) * (180/pi);
				private "_pt"; _pt = [_dest, WFBE_C_DRONE_ZONE_RADIUS, _ang] call BIS_fnc_relPos;
				private "_h"; _h = _d getDir _pt;
				_d setDir _h; _d setVectorDirAndUp [[sin _h, cos _h, -0.05],[0,0,1]];
				_d setVelocityModelSpace [0, WFBE_C_DRONE_LOITER_SPEED, 0];
				_d setPosATL [(getPosATL _d) select 0,(getPosATL _d) select 1, WFBE_C_DRONE_CRUISE_ALT];
				sleep 0.1;
			};
		} else {
			//--- Loitering munition: search for a ground target, then dive.
			private ["_target","_t0"]; _target = objNull; _t0 = time;
			while {alive _d && isNull _target && time < _endTime} do {
				private "_cands"; _cands = nearestObjects [_dest, ["LandVehicle","StaticWeapon"], WFBE_C_DRONE_ZONE_RADIUS];
				_cands = _cands select {alive _x && (side _x getFriend _side) < 0.6 && !(_x isKindOf "Air") && !(_x isKindOf "Man")};
				//--- AA first, then anything.
				private "_aa"; _aa = _cands select {_x isKindOf "StaticWeapon" || _x isKindOf "AAA"};
				_target = if (count _aa > 0) then {_aa select 0} else {if (count _cands > 0) then {_cands select 0} else {objNull}};
				if (isNull _target) then {
					//--- keep orbiting
					private "_ang"; _ang = (time * (WFBE_C_DRONE_LOITER_SPEED / WFBE_C_DRONE_ZONE_RADIUS)) * (180/pi);
					private "_pt"; _pt = [_dest, WFBE_C_DRONE_ZONE_RADIUS, _ang + ((_d getVariable ["wfbe_phase",0])*40)] call BIS_fnc_relPos;
					private "_h"; _h = _d getDir _pt;
					_d setDir _h; _d setVectorDirAndUp [[sin _h, cos _h, -0.05],[0,0,1]];
					_d setVelocityModelSpace [0, WFBE_C_DRONE_LOITER_SPEED, 0];
					_d setPosATL [(getPosATL _d) select 0,(getPosATL _d) select 1, WFBE_C_DRONE_CRUISE_ALT];
				};
				sleep 0.4;
			};
			//--- Stagger dives.
			sleep ((_d getVariable ["wfbe_phase",0]) * WFBE_C_DRONE_DIVE_STAGGER);
			if (!alive _d) exitWith {};
			private "_aim"; _aim = if (isNull _target) then {_dest} else {getPosATL _target};
			//--- Broadcast the Stuka siren on commit (Task 4).
			["WFBE_DroneFX", ["dive", _d]] Call WFBE_CO_FNC_SendToClient;
			//--- Top-attack dive.
			private "_dur"; _dur = 0;
			while {alive _d && ((getPosATL _d) select 2 > 8) && _dur < 8} do {
				private "_v"; _v = (_aim vectorDiff (getPosATL _d));
				_d setVectorDirAndUp [vectorNormalized _v,[0,0,1]];
				_d setVelocity (_v vectorMultiply (WFBE_C_DRONE_INGRESS_SPEED / (vectorMagnitude _v max 1)));
				_dur = _dur + 0.06; sleep 0.06;
			};
			//--- Impact: warhead with scatter.
			private "_imp"; _imp = [_aim, random WFBE_C_DRONE_SCATTER, random 360] call BIS_fnc_relPos;
			WFBE_C_DRONE_WARHEAD createVehicle _imp;
			deleteVehicle _d;
		};
	};
} forEach _drones;

//--- Lifecycle cleanup (mirror Support_UAV).
[_drones, _activeKey, _side] spawn {
	params ["_drones","_activeKey","_side"];
	private "_hardLife"; _hardLife = time + WFBE_C_DRONE_LOITER_TIME + 60;
	waitUntil {sleep 2; ({alive _x} count _drones == 0) || time > _hardLife};
	{ if (!isNull _x) then {deleteVehicle _x} } forEach _drones;
	missionNamespace setVariable [_activeKey, (missionNamespace getVariable [_activeKey,1]) - 1];
};
```

- [ ] **Step 2 (assign formation phase index)** — set `wfbe_phase` per munition so dives stagger and orbits spread. Insert in the spawn loop right after setting role:

```sqf
	_drone setVariable ["wfbe_phase", _i, true];
```

- [ ] **Step 3 (verify in-engine):** Park 2–3 enemy vehicles (incl. a static AA) near a point. Call Drone Strike there. **Observe:** 5 drones ingress from the edge, flares orbit, the 3 munitions acquire and dive (staggered) onto the vehicles, explosions land near targets, drones despawn, no leaks. Check `.rpt`. A second immediate call should be rejected (cap=1).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(drone): server orchestrator — spawn, ingress, acquire, staggered dive, cleanup"
```

---

## Task 3: Scripted survivability — `.50`-cal+ counterplay

Make `.50` and heavier hurt drones; rifles/LMGs don't. Independent of airframe armor (mirror balance).

**Files:** Modify: `Server/Support/Support_DroneStrike.sqf` (add the `WFBE_DroneHandleDamage` function, or place in `Server/Init/Init_Server.sqf` as a compiled global)

- [ ] **Step 1: Define the handler** (add near the top of `Init_Server.sqf`, after the KAT_ block):

```sqf
WFBE_DroneHandleDamage = {
	params ["_unit","_sel","_dmg","_source","_ammo"];
	private "_prev"; _prev = damage _unit;
	private "_delta"; _delta = _dmg - _prev;
	//--- Only count hits at or above the .50-cal threshold; ignore small-arms plink.
	if (_delta >= WFBE_C_DRONE_MIN_HIT) then {
		private "_hp"; _hp = (_unit getVariable ["wfbe_drone_hp", WFBE_C_DRONE_HP]) - 1;
		_unit setVariable ["wfbe_drone_hp", _hp, true];
		if (_hp <= 0) exitWith { 1 };   //--- destroyed
	};
	//--- Otherwise clamp damage so the airframe never accumulates from sub-.50 fire.
	(_unit getVariable ["wfbe_drone_dmgfloor", 0]) min 0.0
};
```

> Note: `HandleDamage` must return the resulting damage value. Returning a value < lethal keeps the drone alive; returning `1` kills it. Confirm the 5th param `_ammo` is populated in A2 OA during the spike; if not, the `_delta` magnitude alone (already used here) is sufficient to separate `.50`+ from rifle fire — that is the primary mechanism and does not depend on `_ammo`.

- [ ] **Step 2 (verify in-engine):** Shoot a loitering drone with a rifle (should barely affect it) then a `.50`/DShK or autocannon (should down it in ~`WFBE_C_DRONE_HP` solid hits). Confirm both factions behave identically (Predator and Pchela).

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(drone): scripted .50-cal+ survivability (mirror-balanced)"
```

---

## Task 4: Client FX — flare pops + Stuka dive siren

Server broadcasts; clients render. Keeps particles/sound off the server.

**Files:**
- Create: `Common/Functions/Common_DroneFX.sqf`
- Modify: `Server/Init/Init_Server.sqf` (define `WFBE_DroneOnIncoming` flare logic) and ensure the client handler `WFBE_DroneFX` is registered in the client PV table.

- [ ] **Step 1: Flare-on-incoming (server-side, reuses IRS pattern)** — define in `Init_Server.sqf`:

```sqf
WFBE_DroneOnIncoming = {
	params ["_drone","_ammo","_shooter"];
	if (!alive _drone) exitWith {};
	//--- Visual + spoof: spawn a CM flare and (reuse IRS) probabilistically deflect the missile.
	private "_flare"; _flare = "F_40mm_White" createVehicle (getPosATL _drone);
	_flare setPosATL (getPosATL _drone);
	[_drone, _ammo, _shooter] call WFBE_CO_MOD_IRS_HandleMissile;  //--- confirm callable; else inline a setVectorDirAndUp nudge with 50% chance
};
```

> If `WFBE_CO_MOD_IRS_HandleMissile` is not directly callable in this context, inline the deflection: find the missile via `nearestObject [_shooter,_ammo]` and, with ~50% chance, `_missile setVectorDirAndUp` a few degrees off-axis (pattern from `IRS_HandleMissile.sqf`). The flare `createVehicle` alone already gives the visual; deflection is the "spoof."

- [ ] **Step 2: Client FX dispatcher** — `Common/Functions/Common_DroneFX.sqf`:

```sqf
params ["_evt","_obj"];
switch (_evt) do {
	case "dive": {
		if (!isNull _obj) then { _obj say3D "drone_stuka"; };  //--- Jericho-trumpet siren at the diving drone
	};
};
```

- [ ] **Step 3: Wire the broadcast handler.** Register `WFBE_DroneFX` so `["WFBE_DroneFX", [...]] Call WFBE_CO_FNC_SendToClient` routes to `Common_DroneFX.sqf` on clients. Follow the existing `WFBE_CO_FNC_SendToClient` handler registration (same mechanism `HandleParatrooperMarkerCreation` uses in `Support_Paratroopers.sqf:120`). Locate that registration table and add: `case "WFBE_DroneFX": { _args ExecVM "Common\Functions\Common_DroneFX.sqf" };` (match the table's actual syntax).

- [ ] **Step 4 (verify in-engine):** Fire an AA missile at the flare drones → flares pop, missile sometimes spoofed. On each munition dive → the Stuka siren plays positionally and chains across the staggered dives.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(drone): client FX — flare spoof + Stuka dive siren"
```

---

## Task 5: Package + smoke-test pass

**Files:** none (build/deploy)

- [ ] **Step 1:** Pack the Chernarus mission via `pack_pbo.py`; deploy the PBO to the Arma 2 OA test rig.
- [ ] **Step 2:** Full smoke test: menu gate (needs UAV upgrade + funds + cooldown), cost deduction, ingress, flare orbit/spoof, acquisition (AA-first), staggered dives + siren, `.50` counterplay, despawn + cap, no `.rpt` errors, both factions.
- [ ] **Step 3:** Fix-forward any issues; re-pack; re-test. Record results in the PR.

---

## Task 6: PR

**Files:** none (git)

- [ ] **Step 1:** `git push -u origin feat/drone-saturation-strike`
- [ ] **Step 2:** Open PR against `master` titled "feat: Drone Saturation Strike (System B)". Body links the spec + plan, lists the file map, the flight-primitive decision from the spike, the outstanding `drone_stuka.ogg` asset TODO, and the smoke-test results.
- [ ] **Step 3:** Request review.

---

## Self-review notes

- **Spec coverage:** trigger/designation (Task 0+2), package 2/3 (Task 2), targeting ground-only AA-first (Task 2 acquire), hard-kill warhead (Task 2 impact), `.50` survivability (Task 3), mirror balance (Task 0 model var + Task 3 scripted HP), flares + siren juice (Task 4), reuse map (all), guardrails cap/despawn (Task 2 cleanup) — all covered.
- **Known build-time confirmations** (carried from spec §12): flight primitive (Task 1 spike), `_ammo` availability in HandleDamage (Task 3 note — not load-bearing), `WFBE_CO_MOD_IRS_HandleMissile` callability and CM flare classname `F_40mm_White` (Task 4 note), `WFBE_CO_FNC_SendToClient` handler-table syntax (Task 4 Step 3), `getFriend` threshold for enemy detection (Task 2).
- **Not placeholders, but flagged unknowns** resolved in-engine because Arma has no static type system; each is isolated to one task with a concrete fallback.
