# Supply Mission Authority Cleanup Playbook

This is the implementation handoff for the `supply-mission-authority-cleanup` lane. It covers the existing truck flow and PR #1-style supply helicopters/cash runs/interdiction rewards that extend the same trust model.

Scope: patch source Chernarus first, then propagate generated missions with `Tools/LoadoutManager`. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

Upstream-history companion: [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) documents the PR #10 -> #11 -> #12 supply-run sequence: remote activation exploit fix, too-far feedback, then JIP notification regression fix. The deeper history pass also found supply-performance reverts (`7bc4b7ac` -> `3c2efb8a`, `008ac5aa` -> `33fb2676`) where server-side optimization used the wrong object context. Keep both sequences in mind when changing supply mission start/reward behavior.

> **Branch-scope update (2026-06-22): do not collapse the supply branches.** The canonical branch/root table lives in [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix). Short version: docs/source `15563691` carries the truck-only typed scan; current stable `origin/master@0139a346` carries the heli-aware typed scan, cooldown casing fix and dead-twin removal/comment in both maintained roots; direct current Miksuu `b8389e74` and `perf/quick-wins` `0076040f` still enumerate the 80 m command-center scan with `nearestObjects [..., [], 80]` and then post-filter by `Base_WarfareBUAVterminal`. Historical release commits `a96fdda2` / `7ff18c49` carry release-line typed-scan evidence, but current origin exposes no live `release/*` head. **Still open across public-baseline hardening:** server-owned mission state, duplicate-start guard, server-side cargo validation, friendly-side delivery-CC checks, player-object rescan/disconnect cleanup and runtime smoke for repeated load/deliver/destroy cycles.

## Current Status

| Item | Status | Notes |
| --- | --- | --- |
| Truck supply mission map | Working but risky | Server tracks return-to-base, but start cargo facts are client-stamped. |
| Supply helicopter extension | Partial / owner-risk | Additive feature shape needs loaded-state and `Killed` handler cleanup before public baseline. |
| Cooldown model | Partial | Pull-based JIP query is useful, but casing and start-time race need cleanup. |
| Dead twin script | Branch-scoped | Still present/compiled in docs/source, Miksuu and perf; current stable `0139a346` comments the compile at `Init_Server.sqf:97` and removes the twin files in both maintained roots. Historical release commits do the same with older line drift. Do not patch it as the live handler. |
| Authority posture | Open hardening | A small server-owned mission record can improve integrity without redesigning all economy flows. |
| Command-center scan narrowing | Current stable source-present / Miksuu-perf old-shape | Docs/source `15563691` has the truck-only typed scan at `supplyMissionStarted.sqf:25,28,44`; current stable `origin/master@0139a346` has the heli-aware typed scan at `:7,55,61,83`; direct current Miksuu `b8389e74` and perf `0076040f` still use broad enumeration/post-filter at `:25,28,44`. Use [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) for the matrix. |

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
| `Killed` handler lifecycle still needs a public-baseline decision. | Current docs/source truck flow has no interdiction `Killed` handler; PR/release heli code guards attachment with `wfbe_supply_killed_eh_set`, but no handler-ID removal/re-arm policy is documented. | The old "stacked handler" claim is stale for current PR/release code; keep repeated load/deliver/destroy smoke and decide whether persistent guard state is intended. |
| Duplicate starts are not explicitly guarded. | Start and tracking scripts can be reached again for a reused/rapidly reloaded vehicle. | Parallel loops and repeated handlers can appear without server-owned state. |
| Cooldown key casing is inconsistent. | ✅ FIXED 2026-06-03 (release `4cf443fe`): `Init_Town.sqf` now seeds `LastSupplyMissionRun` to match the server read/write key. | Was: town init seeded lowercase `lastSupplyMissionRun` so the first cooldown check read nil. |
| Start flow races the cooldown response. | Client requests cooldown and immediately reads local cache. | Keep JIP pull model, but make server start the authority decision. |
| Older performance attempts regressed authority context. | `7bc4b7ac` reverted by `3c2efb8a`; `008ac5aa` reverted by `33fb2676`; upstream history notes server supply logic checking `getPos player` rather than the truck position. | Performance changes must use authoritative mission objects and dedicated-server/JIP smoke, not implicit client globals. |
| Client notification/action guards have JIP history. | PR #12 / `b76f9645` fixed a "too far" notification firing during JIP/non-truck contexts. | Snapshot `cursorTarget`, type-check before distance messages and gate feedback on actual player action. |
| Command-center scan status is branch-scoped. | Docs/source `15563691` uses `["Base_WarfareBUAVterminal"]` at `supplyMissionStarted.sqf:28`; current stable `origin/master@0139a346` uses `["Base_WarfareBUAVterminal"]` plus heli 400/truck 80 at `:61`; current Miksuu `b8389e74` and perf `0076040f` still use broad `nearestObjects [..., [], 80]` at `:28` and post-filter at `:25`. Historical release commits `a96fdda2` and `7ff18c49` also carry the heli-aware typed scan. The 8 m nearby-player/object scan remains intentionally broad. | Do not reopen the typed scan on current stable. During authority rewrites, preserve the terminal post-filter and keep Miksuu/perf old-shape ports separate from server-owned reward/cargo hardening. |
| `supplyMissionActive.sqf` is a dead twin in docs/source, Miksuu and perf; current stable and historical release remove it. | Docs/source, Miksuu and perf compile it as `WFBE_SE_FNC_SupplyMissionActive`, but the live start path is `supplyMissionStarted.sqf`; current stable comments the compile at `Init_Server.sqf:97` and removes the twin plus `checkCCProximity.sqf` from both maintained roots. | Future owners should not patch the wrong script as the live path; either retire it in old-shape targets or keep it clearly marked as dead until merged. |

## Safe Implementation Shape

1. Add server-owned mission state before changing reward math: loaded/tracking flags, source town, amount, heli/cash-run state, owner UID and `Killed` handler identity.
2. Guard idempotency: reject/no-op already-loaded or already-tracking vehicles, attach at most one `Killed` handler, and clear state on completion, death or rejection.
3. Standardize cooldown casing, preferably around the live server read/write key `LastSupplyMissionRun`, and seed the same key in town init.
4. Recompute or validate cargo on the server: requester side, friendly source town, range, vehicle class, upgrade gate and amount.
5. Preserve intended PR #1 semantics unless the owner asks for a design change: truck/light heli side supply, heavy heli upgrade-3 cash run, no-commander fallback and one-time interdiction reward.
6. If touching the command-center search on old-shape targets, port or recreate the current-stable typed scan deliberately. Current stable already uses the heli-aware typed command-center scan; current Miksuu/perf still enumerate `nearestObjects [..., [], 80]` before the terminal post-filter. Keep the 8 m nearby-player/object scan broad unless runtime evidence says otherwise.
7. Retire or explicitly mark `supplyMissionActive.sqf` as dead twin in old-shape targets; current stable already removed/commented it in both maintained roots.

## Validation Plan

| Gate | Checks |
| --- | --- |
| Source-only | Start handler owns accept/reject; repeated starts cannot stack loops or handlers; cooldown key is consistent; command-center search preserves the terminal class guard and ports the release typed scan only if that cleanup is in scope. |
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
