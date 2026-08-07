# VFTCAS Heli Terrain-Hugging — Closure Note

**Status: CLOSED-DUPLICATE. No code change. Documentation only.**

## Finding

The AI-heli terrain look-ahead climb guard proposed under this ticket is already built and
live. It ships in two cooperating parts:

- `Server\server_heli_terrain_guard.sqf` — server-local loop, world-scans `vehicles`,
  covers server-founded AI helis (paradrop/supply, GUER air-defence, W13 gunship, and any
  AICOM heli founded on the server when no Headless Client is connected).
- `Common\Functions\Common_AICOM_HeliTerrainGuard.sqf` — the HC-local twin, bounded-scanning
  each side's `wfbe_teams` commander-team groups instead of a world `vehicles` scan. This is
  the coverage for AICOM logistics/insertion/gunship flights delegated to a Headless Client,
  which is the live topology on the 2-HC production box.

Both use the same look-ahead-probe-and-climb technique: ground an invisible probe object
ahead of the heli's heading (A2 OA has no `getTerrainHeightASL`), read terrain height there
via `getPosASL`, and if clearance is short, command a climb via `flyInHeight` — reactive
only, never lowers the heli, so it cannot force one into terrain.

## Evidence checked in this worktree (branch `claude/vftcas-doc-closure`, base `6ea2bcf17b`)

- Shipped in three separate commits, not one:
  - **13c29b4e56** ("cmdcon29: AI vehicle crew self-repair + PR#122 QoL pack") — introduces
    `Server\server_heli_terrain_guard.sqf` itself, flag `WFBE_C_AIHELI_TERRAIN_GUARD`
    defaulted **0 (opt-in/off)** at that point.
  - **b99393d94b** ("fix(qol): enable AI-heli terrain guard by default") — flips
    `WFBE_C_AIHELI_TERRAIN_GUARD` from 0 to **1 (ON)** in `Init_CommonConstants.sqf`; no
    other files changed besides the matching header comment.
  - **474c222840** ("cmdcon41 wave-3f/.../3j/3k... — w3j aircraft: heli terrain-guard ported
    to HCs") — adds the new HC twin file `Common\Functions\Common_AICOM_HeliTerrainGuard.sqf`,
    registers it in `Headless\Init\Init_HC.sqf`, and in `Server\Init\Init_Server.sqf` appends
    an explanatory comment to the pre-existing `server_heli_terrain_guard.sqf` ExecVM line
    plus a new `spawn` call registering the HC-twin file on the server too (no-HC fallback
    coverage) — it does **not** introduce the server-local guard itself, which had already
    shipped (off, then ON) two commits earlier.
- Flag: `WFBE_C_AIHELI_TERRAIN_GUARD`, registered in
  `Common\Init\Init_CommonConstants.sqf`, **default 1 (ON)** as of `b99393d94b`.
- Registration confirmed on both hosts that can carry AICOM air:
  - `Server\Init\Init_Server.sqf` spawns `Common_AICOM_HeliTerrainGuard.sqf` on the server.
  - `Headless\Init\Init_HC.sqf` spawns the same file on every Headless Client.
- Coverage confirmed to include AICOM logistics/insertion flights, not just the
  server-local non-team air the original server-only guard predates: the HC twin walks
  each side's globally-broadcast `wfbe_teams` array (the same commander-team registry the
  sibling `Common_AICOM_HighClimb.sqf` / `Common_AICOM_AutoFlip.sqf` managers use) and acts
  on any `Helicopter` hull local to that machine — server or HC. A hull touched by both the
  server guard and the HC twin is harmless; both only ever raise `flyInHeight`.

## Conclusion

The shipped approach is materially the same design proposed by the VFTCAS mining card
(probe-ahead + terrain-height sample + compensating climb), already flag-gated and
defaulted ON, and already covers both server-local and HC-delegated AICOM air. No
functional gap was found. No implementation work is needed for this ticket.

This closure note exists so the ticket stops resurfacing in future mining passes; the
mining register / wiki triage entry should be marked CLOSED-DUPLICATE citing commits
13c29b4e56 (server-local guard shipped, opt-in), b99393d94b (flag flipped to default ON),
and 474c222840 (HC twin added, full coverage).
