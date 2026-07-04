# GUER Air Defence Loop Reference

Target ref: `claude/build84-cmdcon36` at `33cab11c` when this page was written.

Scope: this is a read-only source reference for the current server-only GUER air-defence loop. It documents the existing Chernarus source root and adjacent design docs. It does not change `Server_GuerAirDef.sqf`, mission runtime behavior, generated map mirrors, packages or live server state.

Prior art:

- `docs/design/UNUSED-ASSETS.md` lists `Server_GuerAirDef.sqf` as a spawned-asset source and notes Ka-137 / AN-2 / Avenger ideas that should not be confused with this already-live loop.
- `docs/design/EASA-FOR-AI.md` treats GUER air defence as the proven server-side precedent for hardcoded AI aircraft kit swaps.
- `docs/design/GUER-KILL-TECH-SYSTEM-REFERENCE.md` covers the player kill-tech side of GUER progression; this page covers the autonomous town-defence air loop.

## Lifecycle Map

| Phase | Primary owner | Current source anchors | What to check |
| --- | --- | --- | --- |
| Server startup | `Server/Init/Init_Server.sqf` | `:936-941` | Starts `Server\Server_GuerAirDef.sqf` when `isServer` and `WFBE_C_GUER_AIRDEF_ENABLE` are on. |
| Self-guard and constants | `Server/Server_GuerAirDef.sqf`, `Init_CommonConstants.sqf` | `Server_GuerAirDef.sqf:42-100`, `Init_CommonConstants.sqf:220-250`, `:356-358` | Loop exits off-server or when disabled, then reads cadence, caps, aircraft classes, chance gates, flares, swarm and paradrop settings. |
| World readiness | `Server_GuerAirDef.sqf` | `:103-106` | Waits for `towns` and the GUER side logic before sleeping 45 seconds for ownership to settle. |
| Live registries | `Server_GuerAirDef.sqf` | `:140-155` | Keeps script-local `_defenders` and `_drops`; publishes initial empty `WFBE_ACTIVE_GUER_AIR` for clients. |
| Maintain pass | `Server_GuerAirDef.sqf` | `:158-218`, `:220-269` | Every interval, prunes/deletes dead, quiet, expired, inactive or non-GUER defenders and paradrop squads. |
| Spawn selection | `Server_GuerAirDef.sqf` | `:271-327` | For active GUER towns without live air, picks AA, paradrop, Mi-24, AT Ka-137 or default Ka-137 in priority order. |
| Airframe spawn and kit | `Server_GuerAirDef.sqf` | `:332-385` | Spawns airborne hull, creates GUER group, crews driver/gunner, applies AT/AA turret swaps and Ka-137 flare stock. |
| Patrol and combat posture | `Server_GuerAirDef.sqf` | `:390-400` | Calls `AIPatrol` first, then stamps `COMBAT` / `RED` / `NORMAL` so the airframe is never idle. |
| Ka-137 swarm | `Server_GuerAirDef.sqf` | `:408-491` | Optional extra Ka-137s join the same group, inherit the leader's orders, count toward `_maxAir` and get separate registry entries. |
| Paradrop stick | `Server_GuerAirDef.sqf` | `:498-592` | Optional cargo-drop variant registers a GUER infantry group, chutes soldiers near the town, then orders the squad to defend. |
| RPT and marker feed | `Server_GuerAirDef.sqf`, `Client/FSM/updatepatrolmarkers.sqf` | `Server_GuerAirDef.sqf:601`, `:623-630`; `updatepatrolmarkers.sqf:99-126` | Emits `GUERAIRDEF|...` telemetry and rebroadcasts `WFBE_ACTIVE_GUER_AIR` for GUER-only "GUER Air" map arrows. |

## Tunables

All values below are read from `missionNamespace` in `Server_GuerAirDef.sqf:50-100` and registered in `Init_CommonConstants.sqf`.

| Constant | Default | Meaning |
| --- | ---: | --- |
| `WFBE_C_GUER_AIRDEF_ENABLE` | 1 | Master switch. Both `Init_Server.sqf` and the script self-guard read it. |
| `WFBE_C_GUER_AIRDEF_INTERVAL` | 120 | Seconds between maintain sweeps. |
| `WFBE_C_GUER_AIRDEF_MAX` | 4 | Global live airframe cap. Swarm extras also count toward it. |
| `WFBE_C_GUER_AIRDEF_AT_CHANCE` | 0.20 | Chance for a non-AA, non-drop, non-Mi-24 Ka-137 to get the AT-5 loadout. |
| `WFBE_C_GUER_AIRDEF_MI24_CHANCE` | 0.25 | Chance for a large contested GUER town to field `Mi24_P`. |
| `WFBE_C_GUER_AIRDEF_AA_CHANCE` | 0.75 | Chance to field the Igla AA Ka-137 when enemy air is near the town; this has top priority. |
| `WFBE_C_GUER_AIRDEF_CLASS_KA` | `Ka137_MG_PMC` | Default light air defender. |
| `WFBE_C_GUER_AIRDEF_CLASS_MI24` | `Mi24_P` | Heavy gunship candidate for large contested towns. |
| `WFBE_C_GUER_AIRDEF_LIFETIME` | 900 | Maximum seconds before forced recycle. |
| `WFBE_C_GUER_AIRDEF_QUIET_DESPAWN` | 300 | Despawn after no west/east enemy is near the town for this long. |
| `WFBE_C_GUER_AIRDEF_LARGE_SV` | 2500 | `maxSupplyValue` threshold for large-town Mi-24 eligibility; Large/Huge town types also qualify. |
| `WFBE_C_GUER_AIRDEF_HEIGHT` | 120 | `flyInHeight` for spawned GUER air. |
| `WFBE_C_GUER_AIRDEF_DROP_CHANCE` | 0.18 | Ka-137 paradrop chance when a GUER town is under ground attack. |
| `WFBE_C_GUER_AIRDEF_DROP_COUNT` | 5 | Troopers per paradrop stick. |
| `WFBE_C_GUER_AIRDEF_DROP_MAX` | 2 | Global live paradrop-squad cap. |
| `WFBE_C_GUER_KA137_SWARM` | 1 | Enables optional extra Ka-137s in the same group. |
| `WFBE_C_GUER_KA137_SWARM_CHANCE` | 0.25 | Chance for a second combat Ka-137. |
| `WFBE_C_GUER_KA137_SWARM_CHANCE3` | 0.15 | Chance for a third Ka-137 after the second one rolls. |
| `WFBE_C_GUER_KA137_FLARES` | 1 | Enables rolled Ka-137 auto-CM budget. |
| `WFBE_C_GUER_KA137_FLARES_MIN` / `MAX` | 5 / 20 | Inclusive `FlareCount` range. `MAX` is clamped up to `MIN` if misconfigured. |

## Spawn Decision Priority

`Server_GuerAirDef.sqf:271-327` gives each active GUER-held town at most one live air-defence entry at a time. The town must be active, GUER-owned, below the global air cap, and absent from `_townsWithAir`.

The choice order is:

1. **Enemy air nearby:** if a west/east crewed `Air` vehicle is within town range, roll `WFBE_C_GUER_AIRDEF_AA_CHANCE`. A success spawns a Ka-137 with the Igla AA kit.
2. **Ground attack paradrop:** if there is a ground threat, no live drop on that town, the global drop cap has room, and `WFBE_C_GUER_AIRDEF_DROP_CHANCE` passes, the Ka-137 flies in as a cargo-drop delivery bird.
3. **Large-town gunship:** if the town is large and under attack, roll `WFBE_C_GUER_AIRDEF_MI24_CHANCE` for `Mi24_P`.
4. **AT Ka-137:** if the previous branches did not win, roll `WFBE_C_GUER_AIRDEF_AT_CHANCE` for the AT-5 kit.
5. **Default Ka-137:** fallback is the armed recon MG Ka-137.

The paradrop branch deliberately checks `_enemies - _enemyAir > 0`, so a pure air raid does not pull an infantry stick.

## Airframe And Kit Handling

The live air path starts at `Server_GuerAirDef.sqf:332`. It creates the chosen hull with the mission vehicle helper in `FLY` mode, then creates a resistance group tagged `guer-airdef`. Both Ka-137 and Mi-24 paths receive a pilot and a gunner; the Ka-137 needs the gunner because its main turret fires the weapon swap.

The hardcoded kit swaps are server-side because the client EASA tables are not present on server/HC machines:

- AT kit at `Server_GuerAirDef.sqf:352-357`: strips `PKT` / `100Rnd_762x54_PKT`, then adds `AT5Launcher`, `57mmLauncher`, `5Rnd_AT5_BRDM2` and `64Rnd_57mm` on turret path `[-1]`.
- AA kit at `Server_GuerAirDef.sqf:362-367`: strips the same default MG and adds `Igla_twice` plus two `2Rnd_Igla` magazines on turret path `[-1]`.
- Manual flare backing and auto-CM budget come from `Server_GuerAirDef.sqf:95-130` and are applied to Ka-137 leaders/extras at `:378-385` and `:464-470`.

Classname proof is already in-tree:

- `Core_GUE.sqf:126-129` registers `Ka137_MG_PMC` and `Mi24_P` for GUER pricing / air-tier correction.
- `Core_PMC.sqf:70` and `Core_RU.sqf:128` carry the canonical Ka-137 / Mi-24 sources.
- `EASA_Init.sqf:673-679` carries the Ka-137 EASA AT and AA loadout rows mirrored by the server-side swaps.
- `EASA_Equip.sqf:28` identifies `Ka137_MG_PMC` as a turret-path special case.

## Cleanup And Anti-Accumulation

The air and drop registries are script-local arrays, not persistent mission state. The maintain loop cleans them every interval.

Air entries are dropped when:

- the hull is null or dead;
- the town is no longer GUER-held;
- the town is no longer active;
- no west/east enemy has been near the town for `WFBE_C_GUER_AIRDEF_QUIET_DESPAWN`;
- the hull exceeds `WFBE_C_GUER_AIRDEF_LIFETIME`.

The teardown at `Server_GuerAirDef.sqf:198-211` is player-safe: if a player is in the hull crew, the hull is not deleted; non-player group units are deleted and the registry entry is dropped either way.

Paradrop squads follow the same town/quiet/lifetime logic at `Server_GuerAirDef.sqf:220-269`, plus a wiped-squad prune. They delete only non-player bodies before deleting the group.

## Player And Marker Surfaces

The server rebroadcasts `WFBE_ACTIVE_GUER_AIR` every maintain pass at `Server_GuerAirDef.sqf:623-630`. The feed shape is:

```text
WFBE_ACTIVE_GUER_AIR = [[vehicle, WFBE_C_GUER_ID], ...]
```

`Client/FSM/updatepatrolmarkers.sqf:99-126` consumes that feed, gates it to the GUER client side, and creates blue local arrow markers named `wfbe_guerairmarker_%1` with text `GUER Air`. It also drops markers for airframes removed from the feed even if the hull is still alive, which matters when a player takes over a hull and the server stops tracking it.

## RPT Tokens

Useful telemetry families from the current loop:

```text
GUERAIRDEF|START|interval=...|cap=...|atChance=...|mi24Chance=...|aaChance=...|ka=...|mi24=...
GUERAIRDEF|SPAWN|town=...|class=...|load=...|mi24=...|drop=...|enemies=...|enemyAir=...|large=...|alive=...|dropsAlive=...
GUERAIRDEF|SPAWNFAIL|town=...|class=...|reason=...
GUERAIRDEF|DESPAWN|town=...|reason=...|alive=...
GUERAIRDEF|DROPDESPAWN|town=...|reason=...|dropsAlive=...
GUERAIRDEF|KA137_FLARES|n=...|town=...|load=...
GUERAIRDEF|KA137_SWARM|n=...|town=...|load=...|alive=...
GUERAIRDEF|DROP|town=...|dropped=...|alive=...
GUERAIRDEF|DROPFAIL|town=...|reason=...
```

For a smoke test, follow one active GUER-held town through `START`, `SPAWN`, optional `KA137_FLARES` / `KA137_SWARM` / `DROP`, the client `GUER Air` marker, and finally `DESPAWN` or `DROPDESPAWN` when the town quiets, deactivates, changes owner or the lifetime expires.

## Editing Boundaries

Use this page as a route map before editing anything around GUER air.

- `Server_GuerAirDef.sqf` owns behavior. This lane intentionally does not edit it because it is listed as a hot in-flight runtime file in the fleet directive.
- `Init_CommonConstants.sqf` owns defaults and should only be touched by a tuning lane with explicit evidence.
- `updatepatrolmarkers.sqf` owns the GUER-visible marker surface, not spawn behavior.
- `UNUSED-ASSETS.md` proposals that mention `Server_GuerAirDef` are not proof that the loop is dormant; the loop is live and default-on.
- Source edits would need the normal Chernarus-first edit, maintained mirror pass, SQF trap scan, bracket balance check, no-package guard and draft PR validation. This reference PR is docs-only, so LoadoutManager is intentionally not run.
