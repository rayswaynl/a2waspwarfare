# SEC_HARDENING Default Audit

Lane: `fleet-lane-143-sec-hardening-default-audit-2026-07-02`

Base checked: `origin/claude/build84-cmdcon36@6f2fc4bd10c8339fd13be087d327717ff58c85e8`

## Current Baseline

`WFBE_C_SEC_HARDENING` is still a dark master flag:
- Chernarus: `Common/Init/Init_CommonConstants.sqf:585`
- Takistan mirror: `Common/Init/Init_CommonConstants.sqf:585`
- Default: `0`

That default matters because the current live-lane handler guards are payload-bound. The A2 OA public-variable event
handler only gives the variable name and value; it does not provide a trusted sender object. `Common_SendToServer.sqf`
therefore cannot prove who sent a request unless that handler's payload already carries a useful actor/team object.

Do not flip the default until the handler-specific PRs have folded and a flag-on smoke pass has checked honest client,
HC, server-originated, and JIP paths.

## Baseline Guard Coverage

| Handler | Live anchor | Guard when `WFBE_C_SEC_HARDENING > 0` | Main false-positive risk |
| --- | --- | --- | --- |
| `RequestVehicleLock.sqf` | `Server/PVFunctions/RequestVehicleLock.sqf:12-31` | Requires a live player actor, rejects lock requests, rejects null vehicle, and enforces 12m range. `Skill_SpecOps.sqf:54` already sends the actor. | Stale clients or alternate callers that still send only `[vehicle, locked]` would be rejected. |
| `RequestChangeScore.sqf` | `Server/PVFunctions/RequestChangeScore.sqf:14-29` | Rejects null targets and single-event score deltas above `50000`. It deliberately does not require `isPlayer` because some legitimate score awards target AI team leaders. | A future very-large legitimate score grant could be clamped until the ceiling is revisited. |
| `RequestTeamUpdate.sqf` | `Server/PVFunctions/RequestTeamUpdate.sqf:23-25` | Rejects the whole-side `SIDE` branch. The array-team path remains available. | Any hidden admin/debug caller using the whole-side branch would stop working with the flag on. |
| `RequestNewCommander.sqf` | `Server/PVFunctions/RequestNewCommander.sqf:17-27` | Requires valid side logic and rejects assigning a non-null commander team whose leader side does not match the requested side. `objNull` AI-commander stand-down remains allowed. | Still not sender-authenticated; a forged same-side reassignment can only be reduced, not fully proven, without a trusted actor in the payload. |
| `RequestEnqueue.sqf` | `Server/PVFunctions/RequestEnqueue.sqf:27-39` | Requires the side's commander team to exist, be player-led, and belong to the requested side before queueing an upgrade. | A non-player-led scripted/admin queue path would be blocked while the flag is on. |

The same five guard sites exist in the maintained Takistan mirror.

## Active PR Context

The live baseline does not yet contain the rest of the fleet PVF hardening work. Open draft PRs at claim time:

| PR | Branch | Handler/theme |
| --- | --- | --- |
| `#205` | `codex/136-attackwave-shape-guard` | `AttackWave.sqf` payload shape guard |
| `#208` | `codex/139-autowall-isplayer` | `RequestAutoWallConstructinChange.sqf` requester guard |
| `#209` | `codex/137-request-on-unit-killed-shape-guard` | `RequestOnUnitKilled.sqf` short-array guard |
| `#210` | `codex/lane138-requestcommandervote-shape` | `RequestCommanderVote.sqf` side/name guard |
| `#203` | `codex/lane140-aicom-donate-isplayer` | `RequestAIComDonate.sqf` donor guard |
| `#207` | `codex/lane141-requestfobstructure-isplayer` | `RequestFOBStructure.sqf` caller guard |
| `#217` | `codex/142-requestspecial-siteclearance-guard` | `RequestSpecial.sqf` and `RequestSiteClearance.sqf` PVF-level guards |
| `#255` | `codex/lane129-afk-kick-server-request` | AFK kick authority moved through server validation |

There is also an older open lane-140 duplicate PR (`#202`). Pick one canonical AI-commander-donate branch before any
default flip so the final merged state is unambiguous.

## Why Not Flip Yet

The baseline still has unguarded or only partially covered client-callable paths that lane-specific PRs are trying to
close. Examples on this base:
- `AttackWave.sqf` reads `ATTACK_WAVE_DETAILS` payload indices directly.
- `RequestCommanderVote.sqf` reads `_this select 0/1` directly.
- `RequestOnUnitKilled.sqf` reads `_this select 0/1/2` before any shape guard.
- `RequestAIComDonate.sqf` validates amount and funds but does not prove the donor is a live player in this base.
- `RequestFOBStructure.sqf` validates token and placement but does not prove the caller/truck relationship in this base.
- `RequestAutoWallConstructinChange.sqf` trusts the supplied player object for side scope in this base.
- `RequestSpecial.sqf` is a bare `_this Spawn HandleSpecial`; tag-specific validation lives downstream and is uneven.

Flipping `WFBE_C_SEC_HARDENING` before these fold would not protect the unguarded handlers, and it could create a
mixed state where some old honest payloads are rejected while adjacent forged payloads still pass through.

## Rollout Plan

1. Fold or close the duplicate/overlapping PVF hardening PRs so the target branch has one canonical implementation per handler.
2. Re-run `rg -n "WFBE_C_SEC_HARDENING|SEC_HARDENING" Missions/[55-2hc]... Missions_Vanilla/[61-2hc]...` and refresh the guard table.
3. Run a flag-on smoke build before changing the source default. Use a temporary server/test override or a one-off test build; do not make the default flip the same commit that lands handler code.
4. Smoke the honest paths that the guards can accidentally reject:
   - Spec-ops vehicle unlock near/far from the target vehicle.
   - Score awards from town/camp capture, supply completion, HQ/structure kill, and AI leader credit.
   - Commander vote, AI-commander stand-down, commander claim, and upgrade enqueue.
   - Auto-wall toggle, site-clearance placement, FOB build, AI-commander donation, AttackWave, kill processing, and AFK kick.
   - HC-originated `RequestSpecial` tags such as town delegation and AICOM team lifecycle messages.
5. Watch RPT for `rejected` warnings from the guarded handlers. Any honest-path rejection blocks the default flip.
6. Only after a clean smoke/soak should the owner consider changing `WFBE_C_SEC_HARDENING` from `0` to `1`.

## Guardrail

This audit changes documentation only. It deliberately does not flip `WFBE_C_SEC_HARDENING`, alter PVF handlers, or
try to solve authenticated sender identity. That remains a larger transport/protocol problem, not a one-flag cleanup.
