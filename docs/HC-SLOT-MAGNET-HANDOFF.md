# HC Lobby-Slot Magnet — Handoff (for Codex)

Shared task. **claude-gaming** owns the live deploy lane; **codex-gaming** has equal read/write
on this branch. Push experiments here; **coordinate before any live-server deploy.**

## Problem
On Chernarus `[55-2hc]warfarev2_073v48co`, the **first** headless client (HC) auto-seats into the
WEST leader slot **mission.sqm `id=229`** in the **lobby, before any mission script runs**. The
scoreboard then shows "HC = Blufor". The second HC lands on a CIV slot and reads CIV cleanly.

## Final verdict (Codex boot-test 2026-06-28)
The one remaining sliver is **disproved**. A reversible mission.sqm probe converted the two lowest
playable ids (`229` + `230`) into plain CIV `Functionary1` `PLAY CDG` slots with **no**
`forceHeadlessClient`, moved the displaced WEST roster slots to `268` + `307`, and updated the WEST
owner-logic sync list (`id=255`) to keep 14 WEST synced slots intact.

This also refutes the lower-id `0`/`1` version staged in this PR: if the allocator honored plain CIV
slots by playable id, it would have taken CIV `229` before WEST `231` during the boot test. It did not.
The branch tip therefore restores the original mission.sqm slot layout and keeps only the runtime HC
hardening plus this documented verdict.

Local A2-OA dedicated boot-smoke (`1.64.144629`, temporary `HCSlotMagnetProbe.Chernarus`, no live
deploy) still produced:

```text
[4659,43.922,0,"XEH: PreInit Started. v1.0.1.196. MISSINIT: missionName=HCSlotMagnetProbe, worldName=Chernarus, isMultiplayer=true, isServer=true, isDedicated=true"]
"HCSIDE|v1|preseat|name=codex_hc1|engineSide=WEST"
"HCSIDE|v1|reseat|name=codex_hc1|result=done|sideNow=CIV"
"TEAMREG|side=EAST|registered=14|syncedUnits=14"
"TEAMREG|side=CIV|registered=14|syncedUnits=14"
"HCSIDE|v1|connect|uid=76561198046825568|owner=3|side=CIV"
"HCSIDE|v1|teamprune|uid=76561198046825568|side=WEST|removed=1"
```

The `TEAMREG|side=CIV|registered=14` line is the WEST roster logging under the HC's post-reseat
runtime side; `syncedUnits=14` confirms enrollment stayed intact. There were zero mission SQF errors
after MISSINIT. The local RPT had only known local noise (ACR DLC missing-class warnings, two
informational supply "Error: No vehicle." lines, and shutdown/disconnect chatter).

Conclusion: **a plain low-id CIV playable slot does not catch the first HC.** In this mission, the
engine skips CIV lobby slots (both `forceHeadlessClient` and plain CIV) and seats the HC into the
lowest available WEST playable slot. No mission.sqm-only, enrollment-safe fix remains for the lobby
label. Treat the residual as cosmetic and accept the existing runtime CIV reseat/prune behavior.

## Functional status after this PR
Runtime safety is carried forward from PR #118: HC-local reseat keeps gameplay-side, team-balance,
vote-quorum, supply-stagnation, HC registry and HC disconnect cleanup authoritative even when the
lobby allocator seats an HC on WEST. What remains is purely the **lobby/scoreboard slot label** and a
temporary burn of 1 of 14 WEST slots before runtime pruning.

`Headless/Init/Init_HC.sqf` reseats the HC's **side** to civilian (`[player] joinSilent (createGroup
civilian)`), so team-balance, vote-quorum, and the no-players supply-stagnation timer all correctly
see CIV (RPT confirms `HCSIDE|...|reseat|...|sideNow=CIV` + the orphan WEST group is pruned).

## Root cause (confirmed 2026-06-28)
The engine seats a connecting HC before mission scripts run. In A2-OA 1.64, `forceHeadlessClient` is
inert, and the engine does **not** honor CIV slots as HC magnets: it skips both CIV
`forceHeadlessClient` slots and low-id plain CIV `PLAY CDG` slots. On this mission it auto-seats the
first HC into the **lowest-id free WEST playable slot**. `id=229` is the lowest WEST player slot in
the baseline mission.sqm, so the lobby/scoreboard labels the first HC as Blufor until runtime code
reseats its actual side to CIV.

## THREE angles already exhausted — DO NOT repeat
1. **Runtime delete** (kill the magnet slot before the HC seats): **impossible**. The earliest
   mission script (`Init_Server`) runs ~240s in (frameno ~13k), long after the lobby seating.
2. **Static mission.sqm slot renumber/convert**: **whack-a-mole — live-tested 2026-06-17.**
   Converting `id=229` → CIV `forceHeadlessClient` and swapping a `Functionary` → WEST (kept 14 WEST
   + 2 HC, clean boot) just made the HC grab `id=230` (the next-lowest WEST). The HC takes *whichever
   WEST slot is lowest* and skips CIV/forceHeadlessClient slots.
3. **Delay the HC launch (JIP)**: **no effect — analyzed 2026-06-28.** The engine seats lowest-WEST
   whenever the HC connects; on an empty server id=229 is free regardless of timing. (HCs launch on
   the box via scheduled tasks `MiksuuHC`/`MiksuuHC2` → `C:\WASP\hc_launch.cmd`, `ArmA2OA.exe -client
   -connect=127.0.0.1`.) Note: a late/JIP HC is *safe* for the AI commander — it does NOT require HCs
   at start (delegation is lazy/per-founding-tick, `connected-hc` handler is built for late joins) —
   it just leaves the first ~minute of teams server-local. But there is no upside on the magnet.

## The final sliver: tested and dead
The whack-a-mole test had ruled out CIV **forceHeadlessClient** slots. Codex then tested low-id
**plain (non-forceHeadlessClient) CIV** playable slots by making `229` + `230` plain CIV `PLAY CDG`
slots and preserving the 14-slot WEST roster at higher ids. The first HC still reported
`HCSIDE|v1|preseat|...|engineSide=WEST`. Do **not** repeat this angle.

## Key files
- `Headless/Init/Init_HC.sqf` — side-reseat + persistent re-reseat watcher + cold-start reannounce from
  PR #118.
- `mission.sqm` — baseline slot defs are restored at branch tip: `id=229` (Item64, WEST FR_Miles
  leader, sync 255); `id=268` (Item93) + `id=307` (Item128) = CIV Functionary1
  `forceHeadlessClient`. The attempted plain-CIV `id=0`/`id=1` magnet layout is refuted and not left
  active.
- The WEST owner-logic `id=255` and EAST `id=256` reference combat slots by id, so any future slot
  experiment must keep all `synchronizations[]` back-references in lockstep.
- `Server/Functions/Server_HandleSpecial.sqf` — the `connected-hc` owner-keyed registration.

## Constraints (HARD)
- **A2-OA 1.64 only** — no A3 commands; `==`/`!=` reject Booleans (use if/else).
- **Do NOT break player enrollment** — the mission.sqm slots are enrollment-critical; keep ids unique
  and all `synchronizations[]` intact.
- **Boot-smoke every change** (MISSINIT + TEAMREG 14/14 + zero errors) and, for HC work, check the
  live `HCSIDE|...|preseat|...|engineSide=` line to see which slot the HC actually grabbed.
- Prior verdict was **"effectively unfixable — accept it."** This handoff exists so a fresh agent can
  confirm that, or find a missed angle.

## Suggested next step
No further slot-magnet fix is recommended. Keep the runtime HC CIV reseat/prune hardening, accept the
remaining lobby/scoreboard label as cosmetic, and do not live-deploy anything from this branch without
a heads-up to claude-gaming.
