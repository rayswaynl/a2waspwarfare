# Vehicle Marking And Texture Pipeline

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the experimental Miksuu vehicle-cosmetics pipeline that runs inside every `Common_CreateVehicle.sqf` call: per-side recognition **markings** (dim local `#lightpoint` glows) and side-gated body **tints/skins**. Both passes write into a single per-vehicle string variable, `wfbe_pending_texture`, which `Common_CreateVehicle` flushes in **one** JIP-safe `setVehicleInit`/`processInitCommands` broadcast. The existing [Vehicle-Equip-And-Rearm-Function-Reference](Vehicle-Equip-And-Rearm-Function-Reference) page documents only the per-class texture switch (`Common_AddVehicleTexture.sqf:1-230`) and omits the marking sibling, the `wfbe_pending_texture` append/broadcast architecture, the `wfbe_side_id` hand-off, and the two gate constants — all covered here.

None of these three functions has a `WFBE_CO_FNC_*` alias; only `Common_CreateVehicle.sqf` is registered (`WFBE_CO_FNC_CreateVehicle`, `Common/Init/Init_Common.sqf:116`). The two cosmetic functions are invoked inline via `Call Compile preprocessFile` (`Common/Functions/Common_CreateVehicle.sqf:35,37`).

## Gate constants

Two decoupled constants gate the pipeline. Both are defaulted in `Init_CommonConstants.sqf` only if still nil, so an external config/parameter can override them before this runs.

| Constant | Default (init) | getVariable fallback in code | Governs | Source |
|---|---|---|---|---|
| `WFBE_C_VEHICLE_MARKINGS` | `0` (OFF) | `1` (`Common_AddVehicleMarking.sqf:31`) | Master gate: the per-side `#lightpoint` markings **and** the side-gated body skins below | `Common/Init/Init_CommonConstants.sqf:602` |
| `WFBE_C_VEHICLE_TINTS` | `1` (ON) | `1` (`Common_AddVehicleTexture.sqf:257`) | Side-gated procedural body tint pass only (decoupled from markings) | `Common/Init/Init_CommonConstants.sqf:603` |

Gate nuance worth knowing: the marking function's runtime check is `if ((missionNamespace getVariable ["WFBE_C_VEHICLE_MARKINGS", 1]) != 1) exitWith {_vehicle}` (`Common_AddVehicleMarking.sqf:31`). The fallback is `1`, but the constant is initialized to `0` (`Init_CommonConstants.sqf:602`), so under the shipped config the marking pass exits early and never stamps `wfbe_side_id` — which means the tint pass downstream reads `wfbe_side_id = -1` and matches no side `case`. In other words, with the default config the markings are OFF and the side-skins effectively no-op; only the per-class texture switch (the part the other page documents) and the salvage tint actually fire. The `WFBE_C_VEHICLE_MARKINGS = 0` default is deliberate: the comment notes the marking impl attaches up to 3 dim local `#lightpoints` per created vehicle and the WEST skin repaints every blufor hull matte-black, both unverified in-engine and FPS-sensitive (`Init_CommonConstants.sqf:602`). `WFBE_C_VEHICLE_TINTS` is left ON for live measurement but, by the side-id dependency above, is inert unless markings are also flipped on.

## Common_AddVehicleMarking.sqf

**Signature / call site**: `[_vehicle, _side] Call Compile preprocessFile "Common\Functions\Common_AddVehicleMarking.sqf"`, called from `Common_CreateVehicle.sqf:35` **before** the texture pass.

**Params**: `_vehicle` (object, `:27`); `_side` (numeric side id — WEST 0 / EAST 1 / GUER 2, `:28`). **Returns**: `_vehicle` (`:79`).

**Behavior**:

1. Master gate (`:31`): if `WFBE_C_VEHICLE_MARKINGS != 1`, `exitWith {_vehicle}` — no markings, no side-skins (the skin pass keys off the variable this function stamps).
2. Stamp `_vehicle setVariable ["wfbe_side_id", _side]` (`:34`) so the texture pass can read the resolved side without re-deriving it.
3. Build a marking command string `_mk` via `switch (_side)` (`:38-54`). Each side gets a recognition glow + a side running light; an IR-strobe stand-in is appended for any marked side (`:59-61`).
4. APPEND `_mk` (never overwrite) into `wfbe_pending_texture` (`:73-77`).

Each light is created at runtime by the init string `'#lightpoint' createVehicleLocal (position this)`, brightness/colour set, then `attachTo` the vehicle. Because the whole string later runs on every machine (incl. JIP) via the broadcast, `createVehicleLocal` produces one local light per client — never network-replicated lights.

**Per-side light table** (colours are `[r,g,b]`; offsets are `attachTo` local positions):

| Side (`case`) | `mks_rec` recognition glow | `mks_run` running light | Source |
|---|---|---|---|
| WEST (`WFBE_C_WEST_ID` = 0) | orange `[0.9,0.45,0.0]`, bright `0.04`, offset `[0,0,1.4]` | blue `[0.0,0.2,1.0]`, bright `0.03`, offset `[0,-1,1.2]` | `:40-43` |
| EAST (`WFBE_C_EAST_ID` = 1) | orange `[0.9,0.45,0.0]`, bright `0.04`, offset `[0,0,1.4]` | red `[1.0,0.0,0.0]`, bright `0.03`, offset `[0,-1,1.2]` | `:45-48` |
| GUER (`WFBE_C_GUER_ID` = 2) | green `[0.0,0.7,0.0]`, bright `0.04`, offset `[0,0,1.4]` | green `[0.0,0.7,0.0]`, bright `0.03`, offset `[0,-1,1.2]` | `:50-53` |
| any marked side | — | `mks_ir`: white `[1.0,1.0,1.0]`, bright `0.015`, offset `[0,1,1.5]` (IR-strobe stand-in) | `:59-61` |

The side-id constants are defined at `Common/Init/Init_CommonConstants.sqf:30-32`.

**Stubbed (not active)**: the high-fidelity per-side SHAPE (WEST chevron / EAST inverted-V) as an attached billboard textured with a `.paa` is present only as commented-out code pending art + an in-engine attach test (`:63-68`). A kill-tally livery is a v2 TODO (`:70`).

## Common_AddVehicleTexture.sqf — tint/skin pass

**Signature / call site**: `[_vehicle] Call Compile preprocessFile "Common\Functions\Common_AddVehicleTexture.sqf"`, called from `Common_CreateVehicle.sqf:37` **after** the marking pass. **Returns**: `_vehicle` (`:300`).

The first ~230 lines are the per-class map-dependent texture switch documented on [Vehicle-Equip-And-Rearm-Function-Reference](Vehicle-Equip-And-Rearm-Function-Reference); those cases call `setVehicleInit` directly. Two later blocks belong to the cosmetic pipeline and use the append path instead:

**Salvage tint** (`case "Mi17_medevac_CDF"`, `:238-243`): stores `"this setObjectTexture [0,'#(argb,8,8,3)color(0.8,0.5,0.0,0.5,ca)']"` (amber) by APPENDING into `wfbe_pending_texture`, not overwriting — explicitly so a marking string set upstream survives (`:238`). The header block (`:230-238` region) documents *why* it does not call `setVehicleInit` directly: `Common_CreateVehicle` calls `setVehicleInit` again afterward (for `Init_Unit.sqf`), which would clobber the texture command before `processInitCommands` ran.

**Side-gated body skins** (`:257-296`), gated by `WFBE_C_VEHICLE_TINTS > 0`: reads `_side = _vehicle getVariable ["wfbe_side_id", -1]` (`:259`) — the value stamped by the marking pass — and selects a procedural `setObjectTexture` colour string for hull selections 0 and 1:

| Side (`case`) | Procedural colour (selections 0 + 1) | Description | Source |
|---|---|---|---|
| WEST (0) | `#(argb,8,8,3)color(0.04,0.04,0.05,1,ca)` | matte black motor-pool finish | `:266` |
| EAST (1) | `#(argb,8,8,3)color(0.20,0.24,0.16,1,ca)` | dark olive/forest tint | `:272` |
| GUER (2) | `#(argb,8,8,3)color(0.46,0.40,0.28,1,ca)` | desert tan/brown tint | `:278` |

The skin command is APPENDED into `wfbe_pending_texture` (`:293-295`). Clan-livery and medic-cross `.paa` skins are commented stubs pending art (`:284-289`). The function ends with its own `processInitCommands` (`:299`) for any direct `setVehicleInit` cases in the per-class switch; the appended pending strings are flushed separately by the caller (below).

## The wfbe_pending_texture append + single-broadcast architecture

`wfbe_pending_texture` is a per-vehicle string accumulator. Three producers may APPEND to it during one create, joined with `"; "`:

| Producer | Condition | Source |
|---|---|---|
| Marking string (`_mk`) | `WFBE_C_VEHICLE_MARKINGS == 1` and a matched side | `Common_AddVehicleMarking.sqf:73-77` |
| Salvage amber tint | `_type == "Mi17_medevac_CDF"` | `Common_AddVehicleTexture.sqf:241-243` |
| Side body skin | `WFBE_C_VEHICLE_TINTS > 0` and `wfbe_side_id` matches a side | `Common_AddVehicleTexture.sqf:293-295` |

Why APPEND and not overwrite: `setVehicleInit` keeps **only the last string** set on an object. If each producer called `setVehicleInit` independently, every write would clobber the previous one (`Common_AddVehicleMarking.sqf:7-11`; `Common_AddVehicleTexture.sqf:230-238` region). Accumulating into one variable lets all cosmetic commands ride a single init string.

**The single broadcast** happens in `Common_CreateVehicle.sqf:52-73`, on the global non-defender path only:

- Only runs when `_global` is true (`:52`), the creator is not a headless client (HC-delegated vehicles skip the broadcast, `:53-55`), and `_side != WFBE_DEFENDER_ID || WFBE_ISTHREEWAY` (`:57`). Defender-side vehicles in two-way mode take the `defenderSkipped` branch (`:69-71`) and never receive cosmetics — so town/garrison defender vehicles stay marker-light and cosmetic-free.
- It reads `_pendingTex = _vehicle getVariable ["wfbe_pending_texture", ""]` (`:64`), builds the Init_Unit init string `Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf'", _side]` (`:65`), appends the pending texture if non-empty (`:66`), then `setVehicleInit _initStr` + `processInitCommands` (`:67-68`).

This is the only path that guarantees JIP clients also receive the cosmetics: `setVehicleInit` stores exactly one init string and re-runs it for every joining client, so bundling Init_Unit + all cosmetic commands into that single string is what makes them JIP-safe (`:59-62`). `WFBE_ISTHREEWAY` is set at `Common/Init/Init_Common.sqf:293`; `WFBE_DEFENDER_ID` at `Common/Init/Init_Common.sqf:297`.

## End-to-end sequence (one create)

| Step | Action | Source |
|---|---|---|
| 1 | `createVehicle` (null-guarded) | `Common_CreateVehicle.sqf:18-24` |
| 2 | Marking pass: gate, stamp `wfbe_side_id`, APPEND `_mk` | `Common_CreateVehicle.sqf:35` → `Common_AddVehicleMarking.sqf` |
| 3 | Texture pass: per-class switch (direct `setVehicleInit`); salvage tint + side skin APPEND, reading `wfbe_side_id` | `Common_CreateVehicle.sqf:37` → `Common_AddVehicleTexture.sqf` |
| 4 | On global non-defender path: read `wfbe_pending_texture`, fold into the Init_Unit init string, `setVehicleInit` + `processInitCommands` (single JIP-safe broadcast) | `Common_CreateVehicle.sqf:52-73` |

Ordering is load-bearing: the marking pass must run before the texture pass so `wfbe_side_id` exists when the side-skin block reads it (`Common_CreateVehicle.sqf:32-37`).

## Continue Reading

- [Vehicle-Equip-And-Rearm-Function-Reference](Vehicle-Equip-And-Rearm-Function-Reference)
- [Spawn-Primitive-Function-Reference](Spawn-Primitive-Function-Reference)
- [Skin-Selector-And-Class-Swap-Reference](Skin-Selector-And-Class-Swap-Reference)
- [Networking-And-Public-Variables](Networking-And-Public-Variables)
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog)
