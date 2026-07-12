# HC Slot Seating — Mechanism Analysis & Recommendation

**Branch:** `fable/hc-slot-seating`
**Worktree:** `C:/Users/Steff/a2wasp-hcseat`
**Base:** `origin/claude/build84-cmdcon36`

---

## 1. Problem Statement

The live server runs two headless clients:

- `HC-AI-Control-1` (scheduled task `MiksuuHC`, `hc_launch.cmd`)
- `HC-AI-Control-2` (scheduled task `MiksuuHC2`, `hc_launch.cmd`)

Both are launched with `-client -connect=127.0.0.1` — no slot-specifying flag.
On every deploy the engine seats them into **whichever free playable slot has the lowest `id`**.
In this mission, that lowest-id playable slot is `id=229` (`side="WEST"`, `vehicle="FR_Miles"`), so
HC-1 reliably lands on WEST and has to be script-reseated to CIV.  HC-2 lands on the next
lowest available slot, which varies depending on timing.

The deploy script (deploy45.ps1 lines 70-78) works around the non-determinism by:
1. Launch server → wait 40 s → launch HC1 → wait 55 s → launch HC2.
2. Kill the OLDEST ArmA2OA process (i.e., HC1 which has been online longest), relaunch it.
3. Kill all but the most-recent ArmA2OA process, relaunch HC2.

This dance assumes HC1 always precedes HC2 in process birth time and uses process age as a
proxy for HC identity. It is racy (two HCs launch asynchronously; a slow machine can invert
their PIDs) and wastes one WEST slot even after the script reseat.

---

## 2. A2 OA 1.64 Engine Slot-Assignment Mechanics

### 2.1 The deterministic fill rule (confirmed in code + RPT)

The A2/OA engine assigns an incoming client — human or HC — to the **lowest-numbered free
`player="PLAY CDG"` slot** in `mission.sqm`, scanning the `Groups` array in SQM item order.
"Item order" in A2 OA corresponds directly to the **`id=` field in ascending numeric order**.

Evidence:
- `docs/design/archive/HC-SLOT-MAGNET-HANDOFF.md` confirms this via live-test: converting
  `id=229` to CIV+`forceHeadlessClient` caused HC to grab `id=230` (the next-lowest WEST).
- The MAGNET-HANDOFF doc: "The engine seats a connecting client into the lowest-id free
  playable (`player="PLAY CDG"`) slot."
- The `HCSIDE|v1|preseat` telemetry (in `..a2wasp-cutmap/Server/Functions/Server_HandleSpecial.sqf:976`)
  logs what side the HC landed on before any mission script touched it.

### 2.2 `forceHeadlessClient=1` is not authoritative on A2 OA 1.64 `-client` launches

The field exists in A2 OA from 1.63 and is documented on the Bohemia wiki as instructing
the server to route a connecting HC to a matching slot. In practice, on this build with the
`-client` launch flag, the engine **does not enforce it for the auto-seat race**. The HC
skips the CIV `forceHeadlessClient` slot entirely and lands on the next-lowest WEST.
This was live-tested 2026-06-28 and documented in MAGNET-HANDOFF.

**Implication:** `forceHeadlessClient` is unreliable as a static slot-lock on A2 OA 1.64
`-client` mode. It cannot be the solution.

### 2.3 Side priority: WEST > EAST > CIV, or strict lowest-id?

The MAGNET-HANDOFF concluded the HC skips CIV `forceHeadlessClient` slots and only skips
them specifically (because `forceHeadlessClient` signals "I want an HC here, not a human").
A **plain CIV `PLAY CDG` slot** at a lower id than `id=229` was never tested in isolation.
The experiment (MAGNET-HANDOFF) placed two new CIV slots at `id=0` and `id=1`, but this is
a worktree experiment branch that has not been merged to `origin/claude/build84-cmdcon36`.

The question "does the engine prefer WEST before scanning CIV?" remains open, but MAGNET-HANDOFF
explicitly names it as the only untested static angle.

### 2.4 Connect ORDER does determine slot (empty-server scenario)

On an empty server (fresh boot / clean restart, no human players), the first HC to connect
gets `id=229` (lowest WEST); the second gets the next available slot. Since both HCs launch
as scheduled tasks ~55 s apart with no human activity, their connect order IS deterministic
in this environment. The deploy-script kill/relaunch is solving an imagined ordering problem
on top of real racy timing.

---

## 3. Candidate Mechanisms — Evaluated

### (a) mission.sqm playable-unit ORDER

**Mechanism:** The engine fills the lowest-id free playable slot first. Slot assignment is
determined at connect time; there is no pre-reservation. On an empty server, HC1 connects
first → gets `id=229` (WEST). HC2 connects ~55 s later → gets `id=230` or the next WEST.

**Does it give deterministic same-slot seating?** Yes — IF the server is empty when both
HCs connect and no human steals the slot in between. On a live restart with HCs launching
before player join, this is reliable in practice.

**What breaks it:** A human who connects before HC2 seats can steal the intended HC2 slot.
Nothing can prevent this; it is an inherent race in the A2 engine.

**Operational cost:** None. This is already what happens.

**Verdict:** The slot assignment is effectively deterministic on a fresh-restart server.
The real problem is not which slot is assigned — it is that the assigned slot is always
WEST (or EAST), burning a warfare player slot and injecting a phantom player into team-balance.

---

### (b) server.cfg / class Missions param overrides

**Mechanism:** `headlessClients[]` and `localClient[]` are valid A2 OA `server.cfg` settings:
the first allowlists HC source IPs, while the second grants trusted clients unlimited
bandwidth and nearly zero latency (available since OA build 99184). The committed
`server-config/server-pr8.cfg` uses both. They do not route a client to a particular lobby
slot, side, or role; there is still no `forcedSlot[]` or `headlessClientSlot[]` key.

**Does it work on A2 OA 1.64?** Yes for HC connection allowlisting and local-client network
handling; no for per-slot routing. See Bohemia's
[Arma 2 Server Config File](https://community.bohemia.net/wiki/Arma_2%3A_Server_Config_File)
under "Dedicated client in Headless Client mode."

**Verdict:** Keep these settings for their network purpose, but do not pursue them as a
slot-assignment fix.

---

### (c) `-name` / `-profile` flag on the HC launch command

**Mechanism:** The HC is launched with `ArmA2OA.exe -client -connect=127.0.0.1`. Adding
`-name=HC-AI-Control-1` sets the player name (used in `name player` within Init_HC.sqf line
120 of the cutmap version). The `-profile` flag sets the profile directory.

**Does it influence which slot is assigned?** No. The A2 engine ignores the player name
when selecting an empty lobby slot. The name is only applied AFTER the slot is taken.

**What does it help:** `-name` makes the HC name deterministic and matches the known-HC
list in `Init_HC.sqf` (`["HC-AI-Control-1", "HC-AI-Control-2", "HC"]`). The current
`hc_launch.cmd` presumably sets the name already (it is referenced in `StatsFlush.sqf`
and `Init_HC.sqf`).

**Verdict:** Cannot change slot assignment, but good practice for the name-based HC guard
in `Server_OnPlayerConnected.sqf` (B761 line 28).

---

### (d) Mission-side reseat after connect — current approach

**Mechanism:** `Headless/Init/Init_HC.sqf` (in the `..a2wasp-cutmap` worktree, which
represents the current advanced state):
1. Sends `hc-preseat` telemetry before any reseat.
2. Sets `wfbe_hc_magnet=true` on the engine-assigned group (for server-side pruning).
3. Calls `WFBE_HC_FNC_ReseatCivilian` — bounded ~60 s poll, retries `createGroup civilian`
   + `joinSilent` until `side group player == civilian`.
4. Sends `hc-reseat-result` telemetry.
5. Parks the HC body at sea (disarmed, far from play).
6. Sends `connected-hc` to the server → triggers `WFBE_HEADLESS_<uid>` registration.
7. Keeps a persistent 15 s watcher that re-reseats if a mission-restart re-grabs the HC.

The server-side `connected-hc` handler (cutmap `Server_HandleSpecial.sqf:985-1054`) waits
up to 60 s for `owner _hc != 0` and then waits up to 30 s for `side group _hc == civilian`
before completing registration. If CIV side never replicates, it emits `connect-deferred`
and waits for the HC re-announce.

The BAIL message `"[WFBE][B746 CONNECT] BAIL: [HC-AI-Control-2] unresolved after
playableUnits + wfbe_teams fallback window"` happens because:
- HC-2 connects and lands on a WEST slot.
- `Server_OnPlayerConnected.sqf` fires for HC-2 (before B761 guard is effective).
- The HC has not registered yet (`WFBE_HEADLESS_<uid>` nil) so B761 does not skip it.
- The enrollment resolver walks `playableUnits` and `wfbe_teams`, finds a WEST group with
  no `wfbe_side` stamp (it was not stamped at boot for the HC body's slot), so it bails.
- After three 30 s retries the HC re-announces via `connected-hc`, which now works because
  the HC has finished its reseat-to-CIV.

**Is it deterministic?** Not in slot assignment. The reseat itself is deterministic (always
creates a fresh CIV group), but timing is variable. The current mission code handles this
correctly once the cutmap changes are in master.

**What can be improved:** The B761 guard (`WFBE_HEADLESS_<uid>` check) should ideally fire
BEFORE the enrollment resolver attempts its 30 s walk. But this is a timing race: B761 sets
the stamp only after `connected-hc` arrives, which arrives only after reseat finishes, which
takes up to ~60 s. So the resolver sees the HC in the enrollment queue before the stamp lands.

The cleanest fix for the BAIL noise is covered in the recommendation section below.

**Verdict:** Functionally correct. The BAIL telemetry is diagnostic noise, not a functional
failure — the HC always recovers via re-announce. No slot-assignment improvement is possible
from this lever, but the retry architecture is solid.

---

### (e) Kickoff timing / serialized launches

**Mechanism:** Currently HC1 launches, waits 55 s, HC2 launches. Then the deploy script
kills HC1 and relaunches it. The kill/relaunch exists to "fix" HC1's slot assignment. But
since HC1 always lands on `id=229` (the lowest WEST) and the script reseat always reseats
it to CIV, the kill/relaunch is accomplishing nothing mission-functionally — the HC was
already correctly operating from CIV.

**Could serialized launch + readiness check replace the kill/relaunch?** Yes. If the goal
is only to ensure both HCs are alive and on CIV before players join, then:
1. Launch HC1, wait for `HCSIDE|v1|reseat|...|sideNow=CIV` in the RPT (or wait a fixed
   interval knowing the reseat finishes within ~80 s worst-case (hcInitDeadline 20 s + bounded 60 s reseat loop)).
2. Launch HC2.
3. No kill/relaunch needed.

The kill/relaunch is unnecessary complexity that risks killing the wrong process on a slow
machine. The only scenario where it matters is if HC1's reseat fails (CIV group cap or
engine bug), which is already handled by the persistent 15 s watcher.

**Verdict:** The kill/relaunch can be safely removed. Serialized launch with a fixed 75 s
wait (enough for the bounded reseat loop to finish) is sufficient.

---

### (f) Reserved slots via description.ext or lobby scripting

**Mechanism:** `headlessClients[]` and `localClient[]` are server configuration settings,
not `description.ext` slot declarations, in both A2 OA and A3. They allowlist/classify
network clients but do not reserve or select a lobby slot. The `description.ext` file in
this mission (`Header.hpp`) does not have any slot-reservation feature.

Lobby scripting via `JIPCompatible` init or pre-mission scripts cannot run before the engine
assigns a connecting client to a slot — the earliest init script is hundreds of frames after
lobby seating.

**Verdict:** Not applicable on A2 OA 1.64.

---

## 4. Root Cause Summary

```
Engine allocates slot at connect time → always picks lowest-id free PLAY CDG slot.
Lowest-id PLAY CDG in this mission is id=229 (WEST FR_Miles leader).
forceHeadlessClient=1 on a CIV test slot was not honored by A2 OA 1.64 -client (MAGNET-HANDOFF worktree experiment; the live mission.sqm contains no forceHeadlessClient slots).
No engine mechanism can reserve a specific slot for an HC before it connects.
```

The consequence is not a functional failure. The mission's Init_HC.sqf reseat-to-CIV loop
reliably moves the HC off WEST and the server's `connected-hc` handler registers the correct
CIV group. The only real costs are:
1. One WEST lobby slot is cosmetically burned (HC shows up in BLUFOR scoreboard briefly).
2. A WEST group with no players exists for the ~80 s worst-case reseat window (hcInitDeadline 20 s + bounded 60 s reseat loop), injecting a ghost team
   into team-balance math and supply-stagnation timers.
3. The B746 BAIL line appears in the server RPT for HC-2 (enrollment resolver runs before
   the HC is registered, bails, recovers via re-announce).

---

## 5. What "Same Slot Always" Actually Means

On this server, with no human players present during boot:

| HC | First slot grabbed | After reseat | Always the same? |
|----|-------------------|-------------|-----------------|
| HC-1 | `id=229` WEST | CIV own group | Yes — id=229 is always the lowest WEST |
| HC-2 | `id=230` WEST | CIV own group | Yes — id=230 is always the second WEST if HC-1 took 229 |

Both HCs land in the **same logical slots on every restart** as long as no human has
connected before HC-2 seats. The deploy-script's kill/relaunch attempts to guarantee this
but is not actually needed for it.

---

## 6. Recommendation

### 6.1 Static slot modification — one untested angle

The only remaining untested static angle is: **add two plain (non-`forceHeadlessClient`) CIV
`Functionary1 PLAY CDG` slots at ids lower than 229, so the HC lands on CIV natively.**

Evidence from MAGNET-HANDOFF:
- Tested: CIV slot with `forceHeadlessClient=1` → HC skips it.
- NOT tested: Plain CIV `PLAY CDG` at id < 229 (no `forceHeadlessClient`).

If the engine's lowest-id scan is truly side-agnostic (CIV included), then two CIV slots
at e.g. `id=5` and `id=6` would catch HC1 and HC2 before any human could, and no reseat
would be needed. Risk: without `forceHeadlessClient`, a human joining before the HCs on a
fresh restart could grab the CIV slot and spawn as civilian (harmless but confusing).

**This is a low-risk, low-cost experiment.** See implementation proposal in section 7.

### 6.2 Deploy script simplification (launch-script side)

The kill/relaunch dance in deploy45.ps1 lines 73-78 is unnecessary. Replace with:

```powershell
# After server start:
Start-Service 'Arma2OA-PR8'; Start-Sleep 40
Run-Task 'MiksuuHC'; Start-Sleep 75; Run-Task 'DismissACR'  # HC1: 75s covers bounded 60s reseat + slack
Run-Task 'MiksuuHC2'; Start-Sleep 75; Run-Task 'DismissACR' # HC2: same
# No kill/relaunch. Both HCs reseat themselves to CIV reliably.
```

This is strictly deploy-script-side and does not touch any mission files. It eliminates the
process-age-as-proxy logic and the risk of killing the wrong process.

### 6.3 B761 early-guard for enrollment BAIL noise (mission side)

The B746 BAIL for HC-2 happens because `WFBE_HEADLESS_<uid>` is nil when `onPlayerConnected`
fires (the HC hasn't finished its reseat and re-announce yet). This is addressed in the
cutmap's B761 block, but only for HCs that are ALREADY in the registry. A complementary
guard: check the player NAME against the known-HC name list before running the enrollment
resolver. This is simpler and fires immediately regardless of registry state.

This is a mission-side change but it is a correctness fix (eliminates misleading BAIL lines
that could mask real enrollment failures), not a feature addition, so it ships without a flag.

---

## 7. Implementation Proposal (Flag-Gated)

Two independent changes:

### 7.A: Plain CIV low-id slot experiment (mission.sqm)

**Flag:** `WFBE_C_HC_CIV_MAGNET` (default 0)

**Change:** In `mission.sqm`, add two `CIVILIAN PLAY CDG Functionary1` groups at `id=5`
and `id=6` (below any existing WEST slot at id=10+). No `forceHeadlessClient`.
`description="HC Magnet (CIV)"`.

With the flag at 0, no mission-script reads these slots, so they are pure lobby slots —
the HC may or may not land on them. With the flag at 1, the slots are live and the HCSIDE
telemetry will show whether the HC grabbed CIV natively.

**Risk assessment:**
- If the HC lands on CIV natively: reseat is a no-op (already civilian), the 1-slot WEST
  burn is eliminated, B746 BAIL disappears, and the ghost WEST team for ~80 s worst-case is gone.
- If a human lands on CIV: they spawn as a civilian with no warfare team — the existing
  enrollment guard bails them harmlessly (no `wfbe_side` on the CIV group). They see an
  error and rejoin on a WEST/EAST slot.
- If the engine still prefers WEST before CIV: no change. The reseat path still handles it.

**Smoke test:** Boot the server with the flag at 1, observe `HCSIDE|v1|preseat|engineSide=CIV`
in the RPT for both HCs. If WEST still appears, the static angle is refuted and the doc
is updated accordingly.

**Status:** Not implemented in this PR — mission.sqm edits for this experiment require
owner approval of the human-landing-on-CIV risk before proceeding. This is an **options PR
for the owner** so he can decide.

### 7.B: Stamp-only HC guard (HCGUARD name check removed)

**Files edited:**
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_OnPlayerConnected.sqf`
- (mirrors: TK, ZG)

**Change applied (correctness fix, no flag required):** The name-based HCGUARD block was
**removed**. The B761 stamp-based guard (`WFBE_HEADLESS_<uid>`) is the sole HC-identification
mechanism. The guard comment was updated to state this explicitly.

**Why the name guard was wrong:**
A human player named "HC" (or any of the three HC names) would have hit the `exitWith` at
the HCGUARD, skipped enrollment entirely, and been lobby-stuck indefinitely. Player names
are user-set and cannot serve as an authentication signal.

**Why the stamp-only approach is correct:**
`WFBE_HEADLESS_<uid>` is written server-side only (Server_HandleSpecial, `connected-hc` PVF
handler). No client-side action can set it. A human with any name cannot match this condition.

**Human enrollment walk (name="HC", any uid):**
1. `__SERVER__` / empty-uid / `local player` check → false (human client, remote). Continue.
2. B761 stamp check: `WFBE_HEADLESS_<uid>` nil → false (no stamp for humans). Continue.
3. Full enrollment resolver runs. Team found. Human enrolls normally.

**HC path (stamped, post connected-hc):**
1. `__SERVER__` check → false. Continue.
2. B761 stamp check: `WFBE_HEADLESS_<uid>` set → `exitWith` fires. BAIL loop never runs.

**Pre-stamp HC window (~0–80 s after boot):** HC connects, stamp not yet set, resolver runs,
bails (CIV group has no `wfbe_side`), re-arms up to 3×. After `connected-hc` fires and stamp
lands, subsequent connects (e.g., round-restart) exit cleanly at B761. This is unchanged
behavior — the HCGUARD did not improve this window because it only fired for the 3 hard-coded
names, and the real BAIL was already happening for HC-2 before the name check mattered.

---

## 8. What Was Ruled Out (Do Not Re-Propose)

1. **`forceHeadlessClient=1` as slot lock** — confirmed inert on A2 OA 1.64 `-client`
   (MAGNET-HANDOFF live-test 2026-06-28).
2. **Runtime slot deletion before HC connects** — impossible; earliest init is ~240 s after
   lobby seating (MAGNET-HANDOFF).
3. **Static slot renumber (whack-a-mole)** — tested 2026-06-17; HC always takes the next
   lowest available WEST regardless of what we rename (MAGNET-HANDOFF).
4. **Delay-only approach (JIP timing)** — no effect; engine takes lowest slot regardless
   of when HC connects on an empty server (MAGNET-HANDOFF).
5. **server.cfg `headlessClients[]` / `localClient[]`** — valid A2 OA connection-allowlist
   and bandwidth/latency settings, but they cannot reserve a lobby slot or choose its side/role.
6. **description.ext reserved slots** — no such feature in A2 OA.

---

## 9. Existing Code State (origin/claude/build84-cmdcon36 vs cutmap)

The advanced HCSIDE telemetry (B746/B761/B762), the persistent reseat watcher, the sea-park,
and the JIPFUNDS latch are all in `..a2wasp-cutmap` and **not yet merged to `origin/master`
or `origin/claude/build84-cmdcon36`**. The current master has only the basic Init_HC.sqf
(15 lines, no telemetry). If those cutmap changes are intended to ship, they should be the
base for any further HC seating work.

---

## 10. Decision Options for the Owner

| Option | Cost | Risk | Gain |
|--------|------|------|------|
| A: Deploy script simplification only | Zero mission changes | None | Removes kill/relaunch racy dance |
| B: Name-based HC guard in enrollment (correctness fix) | 5-line SQF change, no flag | None | Eliminates misleading B746 BAIL lines |
| C: Low-id CIV slot experiment (mission.sqm) | mission.sqm edit + smoke test | Human could grab CIV slot on connect-before-HC | May eliminate WEST slot burn entirely |
| D: B+C together | Small | As per C | Cleanest outcome |
| E: Accept current state | None | None | Reseat path is functionally correct |

The owner's softened constraint ("HC seating logic and launch scripts MAY be changed") makes
Options A, B, and D safe to proceed with. Option C (mission.sqm) needs explicit approval
given the CIV-slot-for-humans edge case.

**Recommended path (do now):** A + B — deploy simplification + enrollment guard fix.
These are zero-risk, the deploy is cleaner, and the RPT is quieter.
**Recommended path (next experiment):** C with WFBE_C_HC_CIV_MAGNET flag=0, boot-smoke
to answer the "is the engine's fill side-agnostic?" question once and for all.
