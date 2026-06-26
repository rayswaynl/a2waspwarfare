# WASP Warfare — Server Anti-Cheat (v1)

Layered, performance-first anti-cheat for the Arma 2 OA 1.64 WASP Warfare mission.
This document is the design reference for the `hardening/anti-cheat-v1` change set.

## Design principle: push work to the cheapest layer

Arma 2 OA has **no native server-side trust model** and `addPublicVariableEventHandler`
carries **no sender identity**. So anti-cheat is defense-in-depth across layers with very
different runtime costs:

| Tier | Mechanism | Runs in | Server-FPS cost |
|------|-----------|---------|-----------------|
| A | BattlEye filter files | BE engine (C++) | **zero** |
| B | Event-driven SQF validation (at a request) | script scheduler | low |
| C | Per-frame SQF scanning loops | script scheduler | high — **avoided** |

Rules followed: maximise Tier A; keep SQF checks event-driven (never per-frame); reject
forged input at the trust boundary; **validate against server-derived state a forged payload
cannot fake** (the only thing that actually holds without sender identity); A2 OA 1.64 syntax
only; edit Chernarus source then regenerate Takistan via `Tools/LoadoutManager`.

## Threat status (re-baselined against current `master`)

Two issues from the original audit were **already fixed on `master`** and are not re-touched:
the `Call Compile` RCE (now a `missionNamespace getVariable` + `CODE` typecheck lookup) and the
supply-clamp windfall bug (B66 floor-to-0). The remainder:

| ID | Issue | This change set |
|----|-------|-----------------|
| T1 | PVF dispatcher: lookup-only, no allow-list (a forged name can resolve *any* `CODE` global) | **Layer 3** — registered-handler allow-list |
| T8 | ICBM forgery → map-wide kill (no commander/upgrade/cooldown check) | **Layer 6a** |
| T9 | Attack-wave: server trusts client supply → free/negative unit pricing | **Layer 6b** |
| T7 | Score forgery (absolute score from client payload) | **Layer 6c** (partial) |
| T6 | Supply channel: side taken from payload, no caller identity | **Layer 5b** (partial) |
| T2 | BattlEye filters effectively empty (`5 "kickAFK"` only) | **Layers 1 & 2** |
| T3 | `SEND_MESSAGE` compiles payload text (RCE) | deferred (refactor; see Residuals) |
| T4 | Funds client-authoritative | deferred (architectural; see Residuals) |

## What this change set does

### Layer 1 — `BattlEyeFilter/publicvariable.txt`  (zero cost)
Default-deny **log-only** (`1 ""`) catch-all + exact-match (`!=`) whitelist of the 39 legitimate
client→server channels; the `5 "kickAFK"` feature rule is preserved. Ships log-only because the
mission has 39 legitimate channels plus engine/mod traffic — arming blind would mass-kick.
Tuning→arm workflow and the external-`BEpath` caveat are in `BattlEyeFilter/README-anticheat.md`.

### Layer 2 — `BattlEyeFilter/scripts.txt`  (zero cost)
`0 ""` default (no log-spam) + **armed kicks** (`7`) for five tokens with **zero** legitimate
occurrences in the mission (`remoteExec`, `remoteExecCall`, `BIS_fnc_MP`, `createAgent`,
`setGroupOwner`) + **log-only** (`1`) for dual-use commands WASP itself uses (createVehicle,
setPos, setDamage, setVehicleInit, …) pending a tuning pass.

### Layer 3 — PVF dispatcher allow-list  (perf-neutral)
`Init_PublicVariables.sqf` builds `WFBE_SE_PVF_ALLOWED` / `WFBE_CL_PVF_ALLOWED` from the
registered command lists (case-folded with `toUpper`); both dispatchers reject any handler name
not on the list before the namespace lookup. Closes the residual "name any `CODE` global" surface
that the lookup-only guard left open. The out-of-band `GuerVbiedBounty` handler is allow-listed in
`Init_Common.sqf`. Membership is case-insensitive to match the engine's case-insensitive
`getVariable` (legacy direct-dispatch sites use ALL-CAPS handler names). Fail-closed if the list is
nil — which can only happen if `Init_PublicVariables` never ran, in which case the handler globals
are also absent and legitimate dispatch is a no-op anyway, so this rejects nothing legitimate.

### Layer 6a — ICBM server validation  (`Server_HandleSpecial.sqf`)
An ICBM is a map-wide kill. Gated on **server-derived** state a forged payload cannot fake:
side ∈ {west,east}, the side actually **owns the ICBM upgrade** (`WFBE_CO_FNC_GetSideUpgrades`,
bounds-guarded), a live target, and a **global cooldown** (`WFBE_SE_ICBM_LASTFIRE`, default 60s,
`WFBE_C_ICBM_MIN_INTERVAL`-tunable) — global rather than per-side so a forged payload side cannot
rotate cooldown keys to bypass the throttle.

### Layer 6b — attack-wave re-derivation  (`Server_AttackWave.sqf` + `PVFunctions/AttackWave.sqf`)
`ATTACK_WAVE_INIT` ignores the client-sent supply and **re-derives** it server-side
(`GetSideSupply`), clamps the price modifier to `[0.28, 1]`, and validates the side. The directly
broadcastable `ATTACK_WAVE_DETAILS` channel is independently hardened (malformed-payload guard +
side/scalar checks + the same clamp) so it cannot be used to bypass the INIT path. Fully closes
the free/negative-priced-units exploit.

### Layer 6c — score validation  (`RequestChangeScore.sqf`, partial)
Rejects null target, non-scalar score, and absurd absolute values. Stops the egregious forgeries;
the full fix (server-owned award deltas) needs sender authentication — see Residuals.

### Layer 5b — supply channel  (`Server_ChangeSideSupply.sqf`, partial)
Each per-side PVEH derives its side from the **channel name** (ignoring the payload side, killing
cross-side forgery) and type-checks the amount. Amount/caller authority needs the economy redesign.

## Residuals (explicitly out of scope for v1)

Without sender identity, payload-only checks are forgeable; these need the **DR-55 sender-auth
redesign** (per-session nonce, as the clean-room rebuild implements) and/or server-authoritative
economy:
- **T3 `SEND_MESSAGE`** — a second compile-on-payload RCE surface; fix = structured stringtable
  keys instead of compiling text (broad call-site refactor). Interim: the armed BE filter kicks
  client broadcasts of it once enforcement is on.
- **T4 funds** — full client→server-authoritative wallet migration.
- **T7 score / T6 supply / T8 ICBM residual** — a cheater on a side that legitimately owns the
  capability can still act once per cooldown; closing this fully requires authenticated requesters.

## Verification done

- Threat model re-baselined against `master` (6-agent recon).
- BattlEye syntax/action-codes verified against BattlEye + Bohemia community docs.
- Every referenced symbol verified present and server-available.
- Two adversarial review passes (find→verify, with A2-1.64 false-positive guards); all confirmed
  findings fixed or consciously deferred.
- Takistan variant regenerated via `Tools/LoadoutManager`.

**Not** verified in-engine (no live A2 server in this change): the BattlEye filters need a populated
tuning session before arming (`1`→`5`); the SQF changes need a hosted/dedicated smoke test.
BattlEye must be enabled server-side (`BattlEye=1`) and load these filters from its `BEpath`.
