# Bomb Stage-A Verification Runbook

> **For Codex:** REQUIRED SUB-SKILL: none — this is an operator runbook (owner/agent running a
> throwaway dedicated test box), not an implementation task. Read alongside
> `docs/plans/2026-07-24-ai-air-easa-loadouts.md` (the governing Stage A spec) and
> `Common/Functions/Common_RunCommanderTeam.sqf:478-585` (the EASA-AI kit table this harness copies).

**Purpose:** operate `Server/Functions/Server_BombProbe.sqf` (flag `WFBE_C_BOMB_PROBE`, default 0) on
a **secondary/throwaway test box only** to answer, with RPT evidence, the two open questions from the
2026-07-24 and 2026-07-28 audits:

1. Does an OA 1.64 AI pilot/gunner actually **release** an unguided bomb (FAB/Mk82/GBU) at a revealed
   ground target once the EASA-AI kit table has applied a bomb-bearing loadout, with **no scripted
   forcing** of the shot?
2. Does the EASA-AI kit table's **HULL** treatment of `Mi24_P` and `Su34` (`kTur=false` →
   `addWeapon`/`removeWeapon`) actually reach their real weapon slot, or does their bomb/AG armament
   live on a config `Turrets` subclass that only `addWeaponTurret`/`removeWeaponTurret` can touch?

**Never run this on the live server.** `WFBE_C_BOMB_PROBE` must stay `0` (its Init_CommonConstants.sqf
default) everywhere except the disposable test box described below.

---

## 1. What the harness does (summary — see the file header for the full contract)

With the flag armed, `Server_BombProbe.sqf` (server-only):

1. Spawns 5 AI-crewed, EAST-flagged hulls — `Mi24_P`, `Su34`, `A10`, `AV8B2`, `Su25_TK_EP1` — at a
   fixed offshore/corner position, `WFBE_C_BOMB_PROBE_ORIGIN` (default `[500,500,300]`, a best-effort
   SW-corner-of-Chernarus guess — **verify in the editor/3D view that it is clear terrain or water
   before arming**, and override the constant in your test-box `Init_CommonConstants.sqf` if it is
   not).
2. Logs `BOMBPROBE|v1|baseline|` gear for each hull: hull weapons/magazines, the pseudo `turret:[-1]`
   slot, and every real config turret path (from `WFBE_CO_FNC_GetVehicleTurretsGear`), each with the
   live `weaponsTurret`/`magazinesTurret` read next to the static `CfgVehicles>>Turrets` reference
   array.
3. Applies the EASA-AI kit table — a **verbatim copy** of `Common_RunCommanderTeam.sqf:498-545**,
   including the `WFBE_C_AICOM_AIR_BOMBS`-gated bomb-preserve/-grant mutation, read from the **same
   live flag** — then logs `BOMBPROBE|v1|post-kit|` the same way. Diff this against `baseline` to see
   exactly what the kit changed, and whether it landed on the turret or not.
4. Spawns a small WEST ground cluster (4 infantry + one empty truck) 800 m away, reveals it once, then
   re-issues `doTarget`/`doFire` (no `selectWeapon`, no `fireAtTarget`, no forcing of any kind) every
   20 s for 5 minutes. A `Fired` EH on each hull logs `BOMBPROBE|v1|fired|` per shot.
5. Logs one `BOMBPROBE|v1|verdict|class=...|totalFired=N|bombFired=true/false` per airframe, then
   deletes every object it created.

All log lines are `diag_log`, i.e. server RPT (`arma2oaserver.RPT`) only — this probe is server-side
(`if !(isServer) exitWith {};`), so do **not** look for `BOMBPROBE` lines in an HC RPT.

---

## 2. Arming it on the secondary test box

The secondary/throwaway dedicated instance is **not** the live 4-HC box — use a disposable
`-world=Chernarus` instance you can throw away afterward (per-owner: the miksuu Hetzner test server or
an ad-hoc local dedicated process; never the live production box or its Takistan/Zargabad mirrors,
since this file only exists under the Chernarus source mission tree).

1. Deploy this branch's `Missions/[55-2hc]warfarev2_073v48co.chernarus` to the test box (or point the
   test dedicated server's `-mod`/mission path at a checkout of this branch directly — either way,
   never at the live box's mission folder).
2. Arm the flag with a **one-line constant override**, appended after the existing
   `Common/Init/Init_CommonConstants.sqf` TEST HARNESS block loads (either edit the constant's default
   in place for this throwaway checkout, or — cleaner, avoids touching the tracked default — add a
   `missionNamespace setVariable ["WFBE_C_BOMB_PROBE", 1];` line to the test box's own
   `Rsc/Parameters.hpp`-independent local override point, e.g. a one-line addition at the very end of
   `Common/Init/Init_CommonConstants.sqf` on the throwaway checkout only — **never commit that
   override**):
   ```sqf
   WFBE_C_BOMB_PROBE = 1;
   ```
3. **Baseline run (bomb-release OFF-config control):** leave `WFBE_C_AICOM_AIR_BOMBS` at its tracked
   default (`0`). This exercises exactly what ships today: `Su34`/`Su25_TK_EP1` already carry FAB-250
   in their kit rows unconditionally; `Mi24_P`/`A10`/`AV8B2` will show the kit **stripping** their
   stock bomb capability (per the 2026-07-24 audit finding) — expect `bombFired=false` for those three
   in this run, and treat that as confirming the current kit table's documented behavior, not as new
   evidence about AI release ability.
4. **Bomb-release run (the actual Stage A question):** also set
   `WFBE_C_AICOM_AIR_BOMBS = 1;` (same one-line override point) so `Mi24_P`/`A10`/`AV8B2` regain a
   bomb-bearing kit row too. Run this pass separately from the baseline run (restart the mission
   between the two so the flags take effect cleanly — both are read once at kit-apply time, not
   live-reactive).
5. Start the mission. The probe self-guards with `waitUntil {commonInitComplete}` + a 10 s settle, so
   it fires automatically once the mission is up — no manual trigger needed. The whole run (spawn →
   baseline → kit → 5-minute fire window → verdict → teardown) takes roughly 6 minutes wall-clock.
6. Confirm completion: `BOMBPROBE|v1|END|` in the server RPT. If it never appears, check for an
   `Error` in the same window first — a script fault (e.g. a bad classname on your test box's asset
   config) aborts the thread silently at that statement.

---

## 3. Collecting the evidence

Use the `rpt-triage` skill's windowed reader — RPT files never truncate, so an ungapped grep can match
a stale prior mission's lines:

```powershell
. Tools\Monitor\Get-WindowedRpt.ps1
$lines = Get-WindowedRpt -RptPath <path-to-arma2oaserver.RPT> -WindowMarker 'MISSINIT'
$lines | Where-Object { $_ -match 'BOMBPROBE\|v1\|' } | Out-File bombprobe-evidence.txt
```

Or, if reading the file directly, window to the **last** `MISSINIT` before grepping for `BOMBPROBE|v1|`
— never trust a whole-file match. Expect, per airframe, the sequence:
`spawn` → `baseline` (hull + `turret:[-1]` + one line per real config turret path) → `kitapplied` →
`post-kit` (same scopes) → zero or more `fired` lines → one `verdict` line.

---

## 4. Decision table

Read the `baseline` vs `post-kit` lines for `Mi24_P` and `Su34` first — they answer question 2
directly, independent of the fire-order outcome:

| Observation | Meaning | Action |
|---|---|---|
| `post-kit` **hull** `weapons`/`mags` for `Mi24_P`/`Su34` show the kit's new launcher/magazines, AND no real turret path (or `turret:[-1]`) shows them | The armament genuinely lives on the hull slot; today's `addWeapon`/`removeWeapon` is correct | **(iii) Accept native behaviour** for the hull-vs-turret question. Move directly to reading the `fired` verdict for the bomb-release question. |
| `post-kit` hull weapons/mags are **unchanged from baseline** (kit appears to have no effect at the hull level) BUT a real config turret path's **static `cfgWeapons`/`cfgMags`** already lists the same launcher/magazine classnames that the kit tried to add | The armament lives on a `Turrets` subclass; the current hull-only apply is silently missing it | **(i) Fix the turret rows**: change `Mi24_P`/`Su34`'s `kTur` flag to `true` in `Common_RunCommanderTeam.sqf`'s `_easaKits` table (and this probe's copy) so the apply loop uses `addWeaponTurret`/`addMagazineTurret [x, <real path>]` instead of `[-1]` (confirm the exact path from the `post-kit` `turret:<path>` log line, not `[-1]` — `[-1]` is a distinct pseudo-slot, not necessarily the real `MainTurret` index). |
| `post-kit` shows the kit weapons/mags present on `turret:[-1]` even though `kTur=false` was used (i.e. the hull commands happened to reach that slot anyway) | `[-1]` and the hull commands may alias for this airframe | No fix needed for question 2 on this airframe; note the aliasing in the PR/commit so the next kit-table edit doesn't assume otherwise. |

Then read every airframe's `verdict` line for the bomb-release question:

| Observation | Meaning | Action |
|---|---|---|
| `bombFired=true` for an airframe in the **bomb-release run** (§2 step 4), with a `fired` line showing `weapon=` one of the bomb-role launchers | OA 1.64 AI *can* select and release that airframe's bomb without scripting | **(iii) Accept native behaviour** for that airframe. If the live default is currently stripping its bomb (per the baseline run), that is a product decision for the owner (arm `WFBE_C_AICOM_AIR_BOMBS`), not a code defect. |
| `bombFired=false` for an airframe that the `post-kit` log confirms **does** carry the bomb launcher+magazine (hull or the fixed turret path from decision 1) and the `fired` log shows the AI firing its *other* weapons (AT/cannon/AA) at the target throughout the 5-minute window | AI is engaged and armed, but never selects the bomb muzzle on its own | **(ii) Scripted release via `fireAtTarget`** is the only remaining lever (never `forceWeaponFire` — A3-only, does not exist on OA 1.64). Scope this as a **new, separate, owner-approved** change — it is new combat logic, explicitly out of the Stage A/harness scope (see "Rejected shortcuts" in the 2026-07-24 plan doc) and needs its own flag + PR. |
| `bombFired=false` and the airframe never fired *any* weapon (`totalFired=0`) | The fire order itself did not take (target not revealed/hostile, hull not local, crew died, or the airframe never got in range/altitude to engage) | Not evidence either way — fix the harness's spawn geometry/target reveal before drawing any conclusion; rerun. |

---

## 5. Cleanup

The probe deletes every object it created on its own (`BOMBPROBE|v1|verdict|` immediately followed by
its teardown, then `BOMBPROBE|v1|END|`). No manual cleanup is required beyond restarting the throwaway
test-box mission between the baseline and bomb-release runs (§2 step 4) and, when done, discarding the
test-box checkout / setting `WFBE_C_BOMB_PROBE` back to `0` if it was ever set to `1` anywhere durable.

**Never** carry a `WFBE_C_BOMB_PROBE = 1` override, or a `WFBE_C_AICOM_AIR_BOMBS = 1` override made
only for this test, into any branch destined for the live server.
