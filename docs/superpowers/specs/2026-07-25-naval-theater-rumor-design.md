# Naval Theatre Rumor Announces

## Goal

Make the existing naval activity visible to players with opt-in, server-authored `DashboardAnnounce` messages, without changing any spawn, movement, ownership, or proximity gate behavior.

## Design

- Add `WFBE_C_NAVAL_THEATER_RUMOR`, default `0`, and `WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL`, default `120` seconds, beside the existing naval constants.
- In `Server_USVFlotilla.sqf`, keep the current `_gateWasActive` edge detection and add an announce only on the false-to-true transition. Keep one local last-announced timestamp so a close/reopen inside the interval is suppressed.
- In `Init_NavalHVT.sqf`, keep each carrier thread's existing `_armed` latch and add an announce only when that latch changes false-to-true after the existing GUER ownership check. Each carrier thread owns its own last-announced timestamp.
- Both snippets call the existing server broadcast path: `[nil, "DashboardAnnounce", [_message]] Call WFBE_CO_FNC_SendToClients;`.
- The existing `IS_naval_map` early exits remain before all new work, so Takistan and Zargabad never evaluate the rumor snippets. With the new flag at `0`, no broadcast or timing state transition occurs.

## Messages

- USV gate: `Hostile small craft are active on the coast.`
- Carrier CAP gate: `Carrier CAP airborne near <carrier name>.`

## Verification

- Targeted source assertions prove both announcements are under the new flag and use `DashboardAnnounce`.
- Full prescribed SQF lint selector, delimiter checks, `git diff --check`, mirror generation/check, and TK/ZG template validation run before commit.
- A flag-off static comparison confirms the only new executable branches are guarded by the default-off constant; no live server or deployment action is performed.
