# HC Lobby-Slot Magnet — Handoff (for Codex)

Shared task. **claude-gaming** owns the live deploy lane; **codex-gaming** has equal read/write
on this branch. Push experiments here; **coordinate before any live-server deploy.**

## Problem
On Chernarus `[55-2hc]warfarev2_073v48co`, the **first** headless client (HC) auto-seats into the
WEST leader slot **mission.sqm `id=229`** in the **lobby, before any mission script runs**. The
scoreboard then shows "HC = Blufor". The second HC lands on a CIV slot and reads CIV cleanly.

## Functional status after this PR
This PR makes the branch self-contained and tries the remaining static fix:

- Runtime safety is carried forward from PR #118: HC-local reseat keeps gameplay-side, team-balance,
  vote-quorum, supply-stagnation, HC registry and HC disconnect cleanup authoritative even if the lobby
  allocator still seats an HC on WEST.
- The two HC lobby bodies are now **plain CIV playable magnets at ids `0` and `1`**. The displaced
  non-playable LOGIC ids `0` and `1` were moved to unused high ids `9007` and `9008`; they had no
  `synchronizations[]` back-references.
- `forceHeadlessClient=1` was removed from the two CIV HC slots because the live failure proved it is
  not authoritative for `-client` lobby auto-seat in this mission on A2-OA 1.64.

Expected smoke result if the allocator is side-agnostic: `HCSIDE|v1|preseat|...|engineSide=CIV` for both
HCs, with no WEST scoreboard slot burn. If the engine only auto-fills WEST/EAST, the RPT will still show
WEST at preseat, but the runtime reseat/registration fallback keeps gameplay correct.

## Previous functional status: ALREADY NEUTRALIZED — residual was cosmetic
`Headless/Init/Init_HC.sqf` reseats the HC's **side** to civilian (`[player] joinSilent (createGroup
civilian)`), so team-balance, vote-quorum, and the no-players supply-stagnation timer all correctly
see CIV (RPT confirms `HCSIDE|...|reseat|...|sideNow=CIV` + the orphan WEST group is pruned). What
remains is purely the **lobby/scoreboard slot label** (id=229 is `side="WEST"` in mission.sqm) and
it costs 1 of 14 WEST slots.

## Root cause (confirmed 2026-06-28)
The engine seats a connecting client — **including the HC, because `forceHeadlessClient` is not
authoritative for this A2-OA 1.64 `-client` lobby race** — into the **lowest-id free playable
(`player="PLAY CDG"`) slot**. `id=229` is the single
lowest-numbered playable slot in the whole mission.sqm (ids 200–228 are all town/LOGIC entities, not
slots). The two intended CIV `Functionary1` `forceHeadlessClient=1` slots are `id=268` + `id=307`
(far higher) — and the HC **skips** forceHeadlessClient CIV slots.

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

## The sliver implemented here
The whack-a-mole test only ruled out CIV **forceHeadlessClient** slots (the HC skipped them). It did
**not** test a low-id **plain (non-forceHeadlessClient) CIV** playable slot. Open question: does the
auto-seat consider the lowest-id playable slot of **any** side (so a low-id plain CIV slot would catch
the HC), or only WEST/EAST? If the former, adding 2 plain CIV `PLAY CDG` slots at the lowest ids
(below 229) MIGHT catch both HCs at boot (they connect before any human). **Risk:** `forceHeadlessClient`
being inert means a low plain CIV slot does NOT repel humans — a player who connects before the HCs
seat would land on it. This PR takes that risk deliberately but keeps it bounded: the public slot
descriptions still identify them as Headless Client slots, and HC scheduled tasks normally connect before
humans after a restart.

## Key files
- `Headless/Init/Init_HC.sqf` — side-reseat + persistent re-reseat watcher + cold-start reannounce from
  PR #118.
- `mission.sqm` — new low-id CIV slot defs: `id=0` (Item93) + `id=1` (Item128), both plain CIV
  `Functionary1` `PLAY CDG` slots. Former LOGIC ids `0` and `1` now use `9007` and `9008`.
- Historical slot defs: `id=229` (Item64, WEST FR_Miles leader, sync 255) was the first WEST magnet;
  the WEST owner-logic `id=255` and EAST `id=256` reference combat slots by id, so those sync rosters
  were not renumbered for this experiment.
- `Server/Functions/Server_HandleSpecial.sqf` — the `connected-hc` owner-keyed registration.

## Constraints (HARD)
- **A2-OA 1.64 only** — no A3 commands; `==`/`!=` reject Booleans (use if/else).
- **Do NOT break player enrollment** — the mission.sqm slots are enrollment-critical; keep ids unique
  and all `synchronizations[]` intact.
- **Boot-smoke every change** (MISSINIT + TEAMREG 14/14 + zero errors) and, for HC work, check the
  live `HCSIDE|...|preseat|...|engineSide=` line to see which slot the HC actually grabbed.
- Prior verdict was **"effectively unfixable — accept it."** This handoff exists so a fresh agent can
  confirm that, or find a missed angle.

## Boot-smoke checklist
1. Confirm `MISSINIT` and `TEAMREG` still show 14 WEST / 14 EAST player teams.
2. Confirm both HCs register and delegation starts: `HCSIDE|v1|connect|...|side=CIV`.
3. Check the decisive line: `HCSIDE|v1|preseat|...|engineSide=CIV` means the low-id CIV magnet worked.
4. If preseat still logs WEST, keep the PR as runtime-safe but mark the static lobby-label part refuted.
