# Supply Mission Authority Cleanup Playbook

This is the implementation handoff for the `supply-mission-authority-cleanup` lane. It covers the existing truck flow and PR #1-style supply helicopters/cash runs/interdiction rewards that extend the same trust model.

Scope: patch source Chernarus first, then propagate generated missions with `Tools/LoadoutManager`. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

> **✅ UPDATE 2026-06-03 (Claude): several items below are now DONE** (release `4cf443fe`): (1) cooldown casing standardized on `LastSupplyMissionRun` — `Init_Town.sqf` now seeds the correct key (XR4 / DR-18); (2) dead twin `supplyMissionActive.sqf` **removed** (plus `checkCCProximity.sqf`); (3) the command-center scan is **already narrowed** (class-filtered + heli 400 m / truck 80 m + heli 2D gate, `supplyMissionStarted.sqf:48-56`); (4) `SupplyByHeli` is now **cleared on completion** (XR3). **Still open:** server-owned mission state, `Killed`-handler idempotency, duplicate-start guard (XR6), server-side cargo validation, friendly-side check on the delivery CC (XR15).

## Current Status

| Item | Status | Notes |
| --- | --- | --- |
| Truck supply mission map | Working but risky | Server tracks return-to-base, but start cargo facts are client-stamped. |
| Supply helicopter extension | Partial / owner-risk | Additive feature shape needs loaded-state and `Killed` handler cleanup before public baseline. |
| Cooldown model | Partial | Pull-based JIP query is useful, but casing and start-time race need cleanup. |
| Dead twin script | ✅ Removed 2026-06-03 | `supplyMissionActive.sqf` deleted + its `Init_Server.sqf` compile removed (release `4cf443fe`). |
| Authority posture | Open hardening | A small server-owned mission record can improve integrity without redesigning all economy flows. |
| Command-center scan narrowing | ✅ Shipped | `supplyMissionStarted.sqf:56` is class-filtered (`["Base_WarfareBUAVterminal"]`), heli 400 m / truck 80 m, + heli 2D gate at `:48-54`. |

## Current Flow

1. SpecOps action wiring runs `Client/Module/supplyMission/supplyMissionStart.sqf`; the local condition checks town distance and supply truck/heli class or upgrade gates.
2. Client start code asks the server for cooldown, immediately reads local cached cooldown state, validates cursor target class/distance, stamps `SupplyFromTown`, `SupplyByHeli` and `SupplyAmount` on the vehicle, then sends `WFBE_Client_PV_SupplyMissionStarted`.
3. Server start handler records cooldown, attaches a `Killed` handler, starts the timer and loops while the vehicle is alive.
4. The loop checks command-center proximity, then emits `WFBE_Server_PV_SupplyMissionCompleted`.
5. Completion reads vehicle object vars for source/amount/heli state, pays side supply or commander funds, clears amount/source vars and broadcasts presentation.

## Confirmed Findings

| Finding | Evidence | Why it matters |
| --- | --- | --- |
| Client-stamped cargo remains authority-bearing. | `supplyMissionStart.sqf` stamps object vars; `supplyMissionCompleted.sqf` reads them for reward. | Forged or stale values can influence reward unless the server owns accepted mission state. |
| `Killed` handler can stack on reused vehicles. | `supplyMissionStarted.sqf` adds a handler on each start with no proven guard/removal. | Future side effects can multiply; owner should enforce one loaded/tracking handler. |
| Duplicate starts are not explicitly guarded. | Start and tracking scripts can be reached again for a reused/rapidly reloaded vehicle. | Parallel loops and repeated handlers can appear without server-owned state. |
| Cooldown key casing is inconsistent. | ✅ FIXED 2026-06-03 (release `4cf443fe`): `Init_Town.sqf` now seeds `LastSupplyMissionRun` to match the server read/write key. | Was: town init seeded lowercase `lastSupplyMissionRun` so the first cooldown check read nil. |
| Start flow races the cooldown response. | Client requests cooldown and immediately reads local cache. | Keep JIP pull model, but make server start the authority decision. |
| Command-center scan is broader than needed. | Current source still scans all classes in 80m, then filters `Base_WarfareBUAVterminal`; the 8m nearby-player/object scan remains intentionally broad. | Low-risk performance cleanup remains open. |
| `supplyMissionActive.sqf` is a dead twin. | Compiled in server init, but no static caller found. | Future owners should not patch the wrong script as the live path. |

## Safe Implementation Shape

1. Add server-owned mission state before changing reward math: loaded/tracking flags, source town, amount, heli/cash-run state, owner UID and `Killed` handler identity.
2. Guard idempotency: reject/no-op already-loaded or already-tracking vehicles, attach at most one `Killed` handler, and clear state on completion, death or rejection.
3. Standardize cooldown casing, preferably around the live server read/write key `LastSupplyMissionRun`, and seed the same key in town init.
4. Recompute or validate cargo on the server: requester side, friendly source town, range, vehicle class, upgrade gate and amount.
5. Preserve intended PR #1 semantics unless the owner asks for a design change: truck/light heli side supply, heavy heli upgrade-3 cash run, no-commander fallback and one-time interdiction reward.
6. Narrow the command-center scan in source Chernarus, then propagate generated Vanilla Takistan. Keep the 8m nearby-player/object scan broad unless runtime evidence says otherwise.
7. Retire or explicitly mark `supplyMissionActive.sqf` as dead twin so future agents do not patch it.

## Validation Plan

| Gate | Checks |
| --- | --- |
| Source-only | Start handler owns accept/reject; repeated starts cannot stack loops or handlers; cooldown key is consistent; command-center scan is narrowed only for the 80m terminal search. |
| Hosted/dedicated smoke | Truck mission loads, delivers and rewards once; cooldown rejection works; reused truck does not duplicate delivery or handlers. |
| Helicopter smoke | Supply helicopter class/upgrade gates work; heavy-heli cash run and no-commander fallback behave as intended. |
| JIP/disconnect/HC | Confirm in OA smoke that JIP cooldown display remains correct, starter disconnect does not orphan loaded state, and HC presence does not change server/client supply flow. |
| Generated mission | Run LoadoutManager after source edits and inspect generated Vanilla Takistan diff before publishing. |

## Continue Reading

Architecture: [Supply mission architecture](Supply-Mission-Architecture) | Scan sub-step: [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) | Current truth: [Current source status snapshot](Current-Source-Status-Snapshot)

## Supply authority playbook addendum (2026-06-03)

### Miksuu commit mapping
- PR #5 / commit 91d0f36
- PR #10 / commit 97dfff26
- PR #11 / commit 8164cc33
- PR #12 / commit 86ec28d6

### Glitch-fix ledger

- PR #5/10/11/12 fixed multiple transport/runtime edges that were then moved out of the "unpatched" lane state.
- Remaining source-hardening priorities are replay/idempotency and one-sided authority proof: loaded-state record, duplicate handler dedupe and command-origin validation.

### Current known gaps after this set
- Supply completion path still uses client-attached mission vars (SupplyAmount, SupplyByHeli, SupplyFromTown) as direct reward inputs.
- Start/dead handlers can register repeatedly depending on mission restart behavior, creating duplicate event paths.
- Commander assignment still emits duplicate new-commander events in request + assign layers.

### Required next actions
- Introduce server-owned mission state object; deny completion when client vars do not match the server snapshot.
- Keep supply run completion reward logic single-entry only in supplyMissionCompleted.sqf with explicit idempotent transaction flags.
- Gate commander assignment/notification flow to one authoritative branch.
