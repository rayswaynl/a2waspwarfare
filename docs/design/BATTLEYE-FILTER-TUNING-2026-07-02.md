# BattlEye Filter Tuning - 2026-07-02

Lane: 70, BattlEye filter tuning (log-only)
Base checked: `origin/claude/build84-cmdcon36@24604e9f`
Scope: docs/config report only. No filter was armed, no server runtime config was edited, and no mission source was changed.

## Summary

The repo currently ships one BattlEye public-variable filter rule:

| File | Live rule | Source-backed purpose |
| --- | --- | --- |
| `BattlEyeFilter/publicvariable.txt:2` | `5 "kickAFK"` | Intentional AFK-kick path. `RequestAFKKick.sqf:34-36` describes this as the BattlEye kick mechanism and publishes `kickAFK` after server-side validation. |

The current server posture documented in this repo is still inert for BattlEye: `OPTIONAL-CLIENT-MODS.md` records `BattlEye=0`, no `BattlEye\` folder, `verifySignatures=0`, and `equalModRequired` absent. That means the in-repo filter is a reference/staging artifact unless the owner enables BE on the box and installs matching filter files under the active BE path.

No captured `publicvariable.log` sample is available in the source tree or the refreshed brain scan for this lane. Because this mission has many legitimate public-variable channels, the safe output is a staged log plan and false-positive analysis, not a new armed filter.

## Current Evidence

- `BattlEyeFilter/publicvariable.txt:2` contains only `kickAFK`.
- `Client/FSM/updateclient.sqf:138-149` still has the older client-side AFK publisher path.
- `Client/Module/AFKkick/monitorAFK.sqf:24-28` reports AFK to the server through `WFBE_PVF_RequestAFKKick`.
- `Server/PVFunctions/RequestAFKKick.sqf:19-36` validates null, non-player and dead/disconnected objects before publishing `kickAFK`.
- `Common/Init/Init_PublicVariables.sqf:9-32` registers 24 server-bound PVF command names, including structure, defense, MHQ repair, special, upgrade and AFK request handlers.
- A Chernarus grep found 127 public-variable call/comment lines and 46 literal public-variable keys, before counting dynamic `WFBE_PVF_%1` expansions and dynamic supply keys.

## Log-Only Candidate Matrix

These are observation candidates for a test-night or staging copy only. They should not be turned into kicks from source review alone.

| Candidate exact name | Why observe | False-positive / normal-use risk | Arm as kick? |
| --- | --- | --- | --- |
| `kickAFK` | Confirms the existing AFK filter sees only intentional AFK kicks. | Normal AFK kicks are expected. A forged client broadcast would also match this name. | Already the only armed repo rule; keep as-is unless Ray disables BE kicking entirely. |
| `WFBE_PVF_RequestSpecial` | High-value generic server request bus used by artillery, SCUD/TEL, paradrops, commander actions, GUER mortar/VBIED and many AICOM status messages. | Very high. Normal play emits this constantly through `WFBE_CO_FNC_SendToServer`. Kick rules would break core gameplay. | No. Log/sample only. |
| `WFBE_PVF_RequestStructure` | CoIn player structure placement path. | High. Normal commander/build actions use it. | No. Log/sample only. |
| `WFBE_PVF_RequestDefense` | CoIn defense placement path. | High. Normal defenses use it. | No. Log/sample only. |
| `WFBE_PVF_RequestMHQRepair` | MHQ paid repair request path. | Medium. Legitimate but lower frequency than `RequestSpecial`. | No. Log/sample only. |
| `WFBE_PVF_RequestUpgrade` | Upgrade menu server-authoritative request path. | High. Normal commander upgrade flow uses it. | No. Log/sample only. |
| `ATTACK_WAVE_INIT` | Direct public-variable attack-wave activation path. | Medium to high. Legitimate heavy-attack use emits it from `Common_AttackWaveActivate.sqf:6-8`. | No. Log/sample only. |
| `ATTACK_WAVE_DETAILS` | Attack-wave detail payload broadcast path. | Medium. Server code currently publishes it at `Server_AttackWave.sqf:29-42`. | No. Log/sample only. |
| `SEND_MESSAGE` | Direct client message channel. The RCE shape is already fixed in source, but the channel remains broad. | High. Normal localized messages broadcast on this exact name. | No. Log/sample only. |
| `REQUEST_SUPPLY_VALUE` | Pull-query path for side supply. | Medium. Normal UI/economy reads can use it. | No. Log/sample only. |
| `WFBE_ReqAicomFeed` | JIP catch-up request for AICOM marker feed. | Medium. Legitimate JIP clients can send it once. | No. Log/sample only. |

## Filter Guidance

- Do not wildcard `WFBE_` or `WFBE_PVF_`. The mission deliberately expands many legal handler names as `WFBE_PVF_%1`; broad matches would log or kick normal play.
- Do not add a default-deny public-variable rule until a representative `publicvariable.log` sample proves the normal mission envelope.
- Treat BattlEye as defense-in-depth only. Server-side payload validation remains the primary fix for forged request variables.
- Keep `remoteexec.txt` out of Arma 2 OA filter lists; `remoteExec` is not an A2 OA command path.
- If BE is enabled on the box, first collect a round with the current single `kickAFK` rule plus staging/log observation entries, then tune from the observed variable names, directions and payload examples.

## Requested Log Drop

A useful PR follow-up from the owner would attach or paste a redacted `publicvariable.log` from a normal round with BE enabled. Minimum useful fields:

- timestamp and filter index
- player name or redacted unique id
- public-variable name
- payload/value text, redacted if it contains player identifiers
- match context: player count, map, whether AFK kick happened, and whether commander/SCUD/paradrop/CoIn actions occurred

With that sample, a future lane can separate normal high-volume variables from anomalous forged payloads and propose exact log or kick lines with measured false-positive risk.

## Verification

- Source read only; no SQF/SQM/HPP/EXT files were changed.
- `BattlEyeFilter/publicvariable.txt` was intentionally not changed.
- LoadoutManager was not run because this is a docs/config-only lane.
- Source grep confirmed the Chernarus mission has 127 public-variable call/comment lines and 46 literal public-variable keys, so broad filter patterns are unsafe without live logs.
