# HC Lobby-Slot Magnet — Handoff (for Codex)

Shared task. **claude-gaming** owns the live deploy lane; **codex-gaming** has equal read/write
on this branch. Push experiments here; **coordinate before any live-server deploy.**

## Problem
On Chernarus `[55-2hc]warfarev2_073v48co`, the **first** headless client (HC) auto-seats into the
WEST leader slot **mission.sqm `id=229`** in the **lobby, before any mission script runs**. The
scoreboard then shows "HC = Blufor". The second HC lands on a CIV slot and reads CIV cleanly.

## Functional status: ALREADY NEUTRALIZED — the residual is cosmetic
`Headless/Init/Init_HC.sqf` reseats the HC's **side** to civilian (`[player] joinSilent (createGroup
civilian)`), so team-balance, vote-quorum, and the no-players supply-stagnation timer all correctly
see CIV (RPT confirms `HCSIDE|...|reseat|...|sideNow=CIV` + the orphan WEST group is pruned). What
remains is purely the **lobby/scoreboard slot label** (id=229 is `side="WEST"` in mission.sqm) and
it costs 1 of 14 WEST slots.

## Root cause (confirmed 2026-06-28)
The engine seats a connecting client — **including the HC, because `forceHeadlessClient` is INERT in
A2-OA 1.64** — into the **lowest-id free playable (`player="PLAY CDG"`) slot**. `id=229` is the single
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

## The ONE untested sliver
The whack-a-mole test only ruled out CIV **forceHeadlessClient** slots (the HC skipped them). It did
**not** test a low-id **plain (non-forceHeadlessClient) CIV** playable slot. Open question: does the
auto-seat consider the lowest-id playable slot of **any** side (so a low-id plain CIV slot would catch
the HC), or only WEST/EAST? If the former, adding 2 plain CIV `PLAY CDG` slots at the lowest ids
(below 229) MIGHT catch both HCs at boot (they connect before any human). **Risk:** `forceHeadlessClient`
being inert means a low plain CIV slot does NOT repel humans — a player who connects before the HCs
seat would land on it. Untested + enrollment-sensitive.

## Key files
- `Headless/Init/Init_HC.sqf` — the side-reseat + persistent re-reseat watcher. NOTE: the latest
  hardened version (PR #118) lives on `codex/hc-civ-slotting-live` and `claude/command-center-instruct`;
  `master` (this branch's base) has the pre-#118 version. The **mission.sqm slots are identical** on
  all branches, so the magnet experiment is unaffected by the Init_HC version.
- `mission.sqm` — slot defs: `id=229` (Item64, WEST FR_Miles leader, sync 255); `id=268` (Item93) +
  `id=307` (Item128) = CIV Functionary1 forceHeadlessClient. The WEST owner-logic `id=255` (sync list
  line ~3920) and EAST `id=256` (~3939) reference slots by id — any id you move must have all its
  `synchronizations[]` back-references updated in lockstep.
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
Either (a) prove/disprove the untested sliver (low-id **plain** CIV slot) with one careful, reversible
mission.sqm experiment + boot-test, watching `HCSIDE|preseat|engineSide`; or (b) independently confirm
the unfixable verdict from the slot structure. Either way: push to this branch, don't deploy live
without a heads-up to claude-gaming.
