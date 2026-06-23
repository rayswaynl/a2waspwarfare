# Naval HVT Objectives (offshore capturable carriers and platforms)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

## Why This Matters

The naval HVT feature adds a whole new objective family to Chernarus: three pre-placed offshore LHD "carrier" objectives off the east coast, each one a real capturable town logic that starts GUER-owned and defends itself with a proximity-gated GUER combat air patrol. Capturing one is a payoff: every carrier becomes a friendly deck-spawn for GUER respawns, and the easternmost one (`Khe Sanh Charlie`) carries a SCUD saturation-strike pad.

This page is the runtime map for the *placement + capture + integration* flow. It deliberately does **not** restate the SCUD strike numbers (warheads, ballistic flight, MIRV) — those live on [SCUD Saturation Strike Mechanic](Scud-Saturation-Strike-Mechanic). It also distinguishes the naval CAP (defined here) from the unrelated [GUER Air Defense Loop](GUER-Air-Defense-Loop), which is a separate town-defender loop in its own file.

The single most important caveat: parts of the post-capture integration in `server_town.sqf` are **dead code** that reads variables nobody sets. The live respawn integration is the deck-spawn in `Client_OnRespawnHandler.sqf`. The "Dead Vs Live Integration" table below is the load-bearing part of this page — do not patch the carrier hangar block without reading it.

## Master Gate

Everything is behind one constant. Set it to `0` for a byte-for-byte vanilla session.

| Constant | Value | Source | Meaning |
| --- | --- | --- | --- |
| `WFBE_C_NAVAL_HVT` | `1` (default) | `Common/Init/Init_CommonConstants.sqf:943` | Master gate. `0` = no objects, no logic, no CAP, no SCUD. |
| `WFBE_C_SCUD_COST` | `25000` | `Init_CommonConstants.sqf:946` | Funds cost for a SCUD launch (consumed by [SCUD page](Scud-Saturation-Strike-Mechanic)). |

The gate is checked in four independent places, all with a default-on fallback of `1`:

- `Server/Init/Init_Server.sqf:53` compiles the SCUD strike handler only when on.
- `Server/Init/Init_Server.sqf:836-838` `execVM`s `Init_NavalHVT.sqf` only when on.
- `Server/Init/Init_NavalHVT.sqf:26-28` self-guards and logs a skip line if off.
- `Server/FSM/server_town.sqf:283` guards the post-capture block (combined with the per-location `wfbe_is_naval_hvt` tag).

## The Asset Roster

Despite the orchestrator header comment saying "2 naval logics" (`Init_NavalHVT.sqf:103`), the code spawns, tags, and registers **three** LHD HVTs. They are pre-placed game logics in `mission.sqm`, each calling `Init_Town.sqf` so they enter `towns[]` as ordinary town objects.

| Asset | Town name | Sea area | Payoff | mission.sqm |
| --- | --- | --- | --- | --- |
| [A] | `Khe Sanh Alpha` | NE sea | carrier deck-spawn | `mission.sqm:55-56` |
| [B] | `Khe Sanh Bravo` | SE sea | carrier deck-spawn | `mission.sqm:77-78` |
| [C] | `Khe Sanh Charlie` | Skalisty Island sea | carrier deck-spawn + SCUD pad | `mission.sqm:99-100` |

Each `mission.sqm` init line is `[this,"Khe Sanh X","+",10,50,400,["LargeTown1"]] execVM "Common\Init\Init_Town.sqf"` plus `this enableSimulation false` — so every carrier is a `LargeTown1`-template town with starting SV `10`, max SV `50`, town value `400` (`mission.sqm:56,78,100`). The `name` variable that the orchestrator matches on is written by `Init_Town.sqf:31` (`_town setVariable ["name",_townName]`).

### Default GUER ownership

No starting-mode in `Server/Init/Init_Towns.sqf` assigns the carriers, so they fall through to the per-town default: `Init_Town.sqf:90` sets any logic with no `sideID` to `WFBE_DEFENDER_ID`. `WFBE_DEFENDER = resistance` (`Common/Init/Init_Common.sqf:297`), so `WFBE_DEFENDER_ID` resolves to the GUER/resistance side id, which is `WFBE_C_GUER_ID = 2` (`Init_CommonConstants.sqf:32`). The CAP and SCUD-action loops also defensively fall back to `WFBE_C_GUER_ID` when reading the logic `sideID` (`Init_NavalHVT.sqf:221,303`).

## Orchestrator Lifecycle

`Server/Init/Init_NavalHVT.sqf` runs once, server-only, after town init. End-to-end:

| Stage | Source | Behavior |
| --- | --- | --- |
| Server + gate guard | `Init_NavalHVT.sqf:25-28` | Exits on client; exits + logs if `WFBE_C_NAVAL_HVT != 1`. |
| Wait for town init | `Init_NavalHVT.sqf:35-36` | `waitUntil townInit` then `waitUntil towns` so the pre-placed logics exist in `towns[]`. |
| Locate the 3 logics | `Init_NavalHVT.sqf:106-122` | Scans `towns[]`, matches `getVariable "name"` against the three Khe Sanh strings; warns + exits if any is missing. |
| Force sea level | `Init_NavalHVT.sqf:125-127` | `setPosASL` each logic to z=0 (sea surface) for accurate capture-radius detection. |
| Water sanity check | `Init_NavalHVT.sqf:131-135` | `diag_log` a `NAVALHVT-WARN` if any logic is not over `surfaceIsWater` — catches a bad land coordinate server-side. |
| Derive [x,y] anchors | `Init_NavalHVT.sqf:139-142` | 2-element anchors from logic positions for the prop spawners. |
| Spawn LHD hulls | `Init_NavalHVT.sqf:152,173,193` | Builds each carrier via `WFBE_NavalHVT_SpawnLHD`, heading `90`. |
| Deck-Z + tags | `Init_NavalHVT.sqf:160-166,180-186,195-201` | Computes top-of-hull Z, stores `wfbe_naval_deckz` and `wfbe_is_naval_hvt=true` (both broadcast) on each logic. |
| Charlie SCUD props | `Init_NavalHVT.sqf:205-277` | Adds a SCUD pad ref + addAction loop and a static erect `MAZ_543_SCUD_TK_EP1` model. |
| Register logics | `Init_NavalHVT.sqf:212,282` | Publishes `WFBE_NAVAL_HVT_PLATFORMS` ([Charlie]) and `WFBE_NAVAL_HVT_LOGICS` ([A,B,C]). |
| Start CAP loops | `Init_NavalHVT.sqf:289-376` | One proximity-gated GUER CAP thread per logic. |

### Anchor / ASL placement rules

The header comments are explicit about the A2-not-A3 placement discipline (`Init_NavalHVT.sqf:11-16`):

- `setPosASL` is used for every sea object (`SpawnProp` at `:48`, hull parts, pads, SCUD). `setPos`/`setPosATL` would snap to the seabed.
- All `createVehicle` calls are GLOBAL/server-authoritative so AI and collision see them.
- The hull is built from a 9-part offset list `WFBE_C_NAVAL_LHD_OFFSETS` (`:60-70`) — `Land_LHD_1..6`, `Land_LHD_house_1/2`, `Land_LHD_elev_R`. All offsets are currently `[0,0,0]` (the model geometry holds the ~250m layout internally), and the offsets are still rotated by ship heading in `WFBE_NavalHVT_SpawnLHD:86-89`.
- Each prop is `enableSimulation false` + `allowDamage false` (`SpawnProp:50-51`), so the carrier hull is indestructible static scenery — only the underlying town logic's `sideID` is capturable.

Charlie's SCUD pad (`HeliHCivil`, `:207`) and its `MAZ_543_SCUD_TK_EP1` model (`:264`) are placed at z=16 ASL — the assumed deck height. The actual carrier deck heli pads on Alpha (`:155-156`) and Bravo (`:175-176`) are positioned via `WFBE_NavalHVT_Off` (`:99`), whose helper hardcodes z=0, so those deck pads sit at the sea surface (z=0), not z=16. The deck-Z formula adds a fixed `16` bbox height to part-3's ASL z (`:162-163,182-183,197-198`), and the header flags the multi-part offsets and coordinates as `NEEDS REVIEW` for in-engine confirmation (`:18-23`).

## Capture Lifecycle

A carrier is captured by the ordinary town-capture loop (`server_town.sqf`) — there is no special naval capture math; the LHD is a `LargeTown1` town with a tiny SV (10/50), so it flips like any small town once a side dominates the capture radius. See [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) for the generic capture/SV mechanics.

What is naval-specific is the **post-capture block** in `server_town.sqf:281-316`, gated on `WFBE_C_NAVAL_HVT == 1 && _location getVariable "wfbe_is_naval_hvt"` (`:283`). On capture of a tagged carrier it:

1. Resolves the new owner side and broadcasts a `"naval-hvt-captured"` HandleSpecial to clients (no inbound warning) and logs it (`:289-290`).
2. Attempts to recolour a `wfbe_naval_marker` map marker (`:293-296`).
3. If the location is tagged `wfbe_is_carrier_hvt`, deletes the old owner's hangar and respawns one for the new owner via `WFBE_C_HANGAR`, writing `wfbe_hangar` + `wfbe_airfield_side` on a `wfbe_airfield_logic_ref` (`:300-314`).

Items 2 and 3 are **dead** at this commit — see below.

### Dead Vs Live Integration

This is the load-bearing accuracy point. The orchestrator tags each carrier logic with exactly `wfbe_is_naval_hvt` + `wfbe_naval_deckz` (`Init_NavalHVT.sqf:164-165,184-185,199-200`). It never sets `wfbe_is_carrier_hvt`, `wfbe_airfield_logic_ref`, or `wfbe_naval_marker`. A whole-mission grep confirms **zero** `setVariable` writers for all three.

| `server_town.sqf` reads | Set anywhere? | Effect |
| --- | --- | --- |
| `wfbe_is_naval_hvt` (`:283`) | Yes, `Init_NavalHVT.sqf:165,185,200` | LIVE — the naval post-capture block does run on carrier capture. |
| `wfbe_naval_marker` (`:293`) | No setter anywhere | DEAD — defaults to `""`, the marker recolour at `:294-296` never fires. |
| `wfbe_is_carrier_hvt` (`:300`) | No setter anywhere | DEAD — defaults to `false`, the entire hangar-respawn branch `:300-314` is skipped. |
| `wfbe_airfield_logic_ref` (`:301`) | No setter anywhere | DEAD — even if the branch entered, this is `objNull`. |

Practical consequence: capturing a carrier flips its `sideID`, fires the announcement, and (because of the deck-spawn integration below) makes it a friendly respawn — but it does **not** recolour a dedicated naval marker and does **not** stand up a carrier hangar / aircraft-sell shop on the deck. The aircraft-sell payoff described in the orchestrator header (`:6-8`) is aspirational; the airfield-side wiring it depends on is the dead `wfbe_airfield_logic_ref` path. Before "fixing" the hangar block, decide whether the carriers should be registered as `WFBE_Logic_Airfield` at all (they are not — see next section).

## Deck-Hangar / Airfield Respawn Integration

There are two airfield-respawn code paths that touch carriers; only one is live.

### Live: deck-spawn on GUER respawn

`Client_OnRespawnHandler.sqf:46-53` is the working integration. For a resistance/GUER respawn it picks a friendly town `_t` (honoring the player's selected town when valid, else a random GUER-held/neutral town), then:

- if `_t getVariable "wfbe_is_naval_hvt"` is true, it `setPosASL` the unit to the carrier's deck: `[x, y, deckZ + 2]` using `wfbe_naval_deckz` (default `16`) (`:50-51`);
- otherwise it uses the normal `GetRandomPosition` ground spawn (`:53`).

So once a carrier is GUER-held, respawning GUER players land on its deck rather than in the water. This is the real "carrier" payoff at this commit.

### Mostly inert: GetClosestAirport gate

`Client_GetClosestAirport.sqf:14` scans `nearEntities [WFBE_Logic_Airfield, _range]` and, for `sideJoined == resistance`, only accepts an airfield whose `wfbe_airfield_side == resistance`. This is the GUER airfield-ownership gate that the dead `server_town.sqf` block was meant to feed (it writes `wfbe_airfield_side` at `:312`). Because the carriers are **not** registered as `WFBE_Logic_Airfield` (the orchestrator never registers them; grep for airfield in `Init_NavalHVT.sqf` finds only a TODO comment at `:22`) and the carrier-hangar branch is dead, carriers never appear here. Treat the `wfbe_airfield_side` / `wfbe_hangar` carrier wiring as a designed-but-unwired path, not a live aircraft-sell shop.

The same `wfbe_hangar` / `wfbe_airfield_side` variables ARE live for ordinary land airfields via the Task-12 capture block at `server_town.sqf:460-557` (`:556` sets `wfbe_airfield_side`) — see [Town capture, garrison and airfield rebuild](Town-Capture-Garrison-And-Airfield-Rebuild). The naval block was copied from that pattern but its inputs were never populated.

### Map marker label

The one client-side naval display that *is* live: `updatetownmarkers.sqf:71-73` prefixes the carrier's town name onto its marker text for any `wfbe_is_naval_hvt` town, so the LHDs show up named on the map. (This is unrelated to the dead `wfbe_naval_marker` recolour.)

## The Naval CAP (defending air patrol)

Each carrier gets its own proximity-gated GUER combat air patrol, defined inline in the orchestrator (`Init_NavalHVT.sqf:289-376`) — one `spawn`ed thread per logic. This is the patrol the prompt asks to verify against [GUER Air Defense Loop](GUER-Air-Defense-Loop): they are **separate loops in separate files** and do not share code. The GUER Air Defense Loop (`Server/Server_GuerAirDef.sqf:1-2`) keeps Ka-137s/Mi-24s over active GUER-held *towns*; the naval CAP keeps a Mi24_P + An2 over each *carrier*. Cross-link them as related GUER air, not as one loop.

| Property | Value | Source |
| --- | --- | --- |
| Loop cadence | `sleep 10` per cycle | `Init_NavalHVT.sqf:301` |
| Arming radius | any player within `1800` m of the asset | `:309` |
| Arm condition | only while `sideID == WFBE_C_GUER_ID` (stops arming once captured) | `:319` |
| Gunship | `Mi24_P` spawned ~400m altitude NE, `flyInHeight 350` | `:324-331` |
| Biplane | `An2_1_TK_CIV_EP1` spawned ~600m altitude SW, `flyInHeight 550` | `:335-339` |
| Pilot class | `WFBE_GUER_PILOT_CLASS` (default `GUE_Soldier`) | `:326-327,337` |
| Group | fresh `createGroup resistance`, `AWARE` / combat `RED` / speed `FULL` | `:321,329-332` |
| GC protection | `wfbe_naval_cap=true` tagged on group + both aircraft | `:342-344` |
| Orbit | gunship orbits at 400m, biplane counter-orbits at 700m, `_orbitAng += 8` per cycle | `:350-356` |
| Despawn | inactivity timer hits `>= 120`s with no player in radius → delete crew + aircraft + group | `:361-371` |

The CAP "never burns FPS over empty ocean" (`:15-16`): it only arms with a player within 1800m and despawns 120s after the last player leaves. Because the arm gate checks GUER ownership (`:319`), a captured carrier stops generating defenders — but already-airborne CAP is not force-despawned on capture, only on the inactivity timeout.

## SCUD Pad (Charlie only)

The SCUD payoff lives on `Khe Sanh Charlie` and is its own page — [SCUD Saturation Strike Mechanic](Scud-Saturation-Strike-Mechanic) owns the cost/cooldown/warhead/flight numbers. What this page records is the *pad plumbing*:

- A `HeliHCivil` pad is created at the Charlie anchor (z=16), tagged `wfbe_is_scud_pad`, and linked back to the logic as `wfbe_scud_pad_ref` (`Init_NavalHVT.sqf:206-211`).
- `WFBE_NAVAL_HVT_PLATFORMS` is published as `[_lhdCharlieLogic]` (`:212`) — the SCUD validation in `Support_ScudStrike.sqf:36-39` iterates exactly this list and requires the caller's side to own a `wfbe_is_naval_hvt` platform in it.
- An addAction loop (`:215-255`) adds `STR_WF_SCUD_ACTION` to the owning side's *team leader* when within 50m of the pad; the action checks `WFBE_C_SCUD_COST` funds client-side, then opens the map and `RequestSpecial`s `"ScudStrike"` with the clicked target (`:243`). Server validation (owned platform + per-platform cooldown + funds) is re-done server-side on the [SCUD page](Scud-Saturation-Strike-Mechanic).
- A decorative erect `MAZ_543_SCUD_TK_EP1` is raised via the `scudLaunch` action and frozen static on the deck (`:262-277`) — visual only, not the launcher that fires.

The four SCUD strings (`STR_WF_SCUD_ACTION`, `STR_WF_SCUD_NO_FUNDS`, `STR_WF_SCUD_SELECT_TARGET`, `STR_WF_SCUD_LAUNCHED`) exist in `stringtable.xml:9564,9571,9578,9581`.

## Risk Register

| Status | Finding | Evidence |
| --- | --- | --- |
| Dead code | Carrier hangar / aircraft-sell respawn block reads three variables that no code sets; the aircraft-sell payoff is unwired. | `server_town.sqf:293,300-301` read `wfbe_naval_marker` / `wfbe_is_carrier_hvt` / `wfbe_airfield_logic_ref`; zero setters mission-wide. |
| Dead code | Naval HVT marker recolour on capture never fires. | `server_town.sqf:293-296`; `wfbe_naval_marker` unset. |
| Doc drift | Orchestrator header says "2 naval logics" but the code handles 3 (`towns[]` lookup, parts, CAP loops, `WFBE_NAVAL_HVT_LOGICS`). | `Init_NavalHVT.sqf:103` vs `:106-118,376,282`. |
| Needs in-engine review | LHD part offsets, deck-Z, and anchor coordinates are best-guess; flagged by the author. | `Init_NavalHVT.sqf:18-23,57-59`; `NAVALHVT-WARN` water check at `:131-135`. |
| Behavior note | Already-airborne CAP is not force-despawned when its carrier is captured; only the 120s inactivity timer or game-over removes it. Re-arming correctly stops after capture. | `Init_NavalHVT.sqf:300-373` (`:319` arm gate, `:363` despawn). |
| Typo (noted, unfixed) | `WFBE_GUERAIRPORTUNITS` vs `WFBE_GUEAIRPORTUNITS` air-sell typo called out by the author but left for the air-sell integration. | `Init_NavalHVT.sqf:22`. |

## Smoke Checklist

| Change type | Minimum smoke |
| --- | --- |
| Master gate | Boot with `WFBE_C_NAVAL_HVT=0`: no LHDs, no CAP, no SCUD action; RPT shows the skip line (`Init_NavalHVT.sqf:27`). |
| Placement | Boot on; confirm three named carriers over water (no `NAVALHVT-WARN` in RPT), hulls indestructible, decks at ~z16. |
| CAP | Approach within 1800m of a GUER carrier → Hind + An2 arm and orbit; leave for 120s → both despawn; capture the carrier, confirm CAP stops re-arming. |
| Capture | Flip a carrier; confirm `sideID` changes and the `naval-hvt-captured` log/announce fires; confirm (current limitation) no hangar/marker change. |
| Respawn | As GUER, with a friendly carrier, respawn and confirm you land on the deck (`deckZ+2`), not in the sea. |
| SCUD pad | On GUER-held Charlie, as team leader within 50m, confirm the SCUD action appears; full strike behavior is smoked on the SCUD page. |

## Continue Reading

- [SCUD Saturation Strike Mechanic](Scud-Saturation-Strike-Mechanic)
- [GUER Air Defense Loop](GUER-Air-Defense-Loop)
- [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas)
- [Chernarus map content reference](Chernarus-Map-Content-Reference)
- [Respawn and death lifecycle atlas](Respawn-And-Death-Lifecycle-Atlas)
