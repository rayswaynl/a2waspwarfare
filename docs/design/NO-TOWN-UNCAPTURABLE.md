> **⚠️ SHELVED (2026-07-02) — superseded by [SPREAD-AND-HOLD.md](SPREAD-AND-HOLD.md).** Once live cmdcon40
> proved the AI *does* capture towns, the real problem is the OPPOSITE of this design: teams DOGPILE one town
> and don't HOLD captures. This escalation ladder *concentrates* up to 12 teams on one town → it would make the
> dogpile worse. DO NOT implement the escalation in the morning. Keep only its verdict "drain is linear → no
> server_town.sqf change needed" as reference. Re-scope narrowly (+1-2 teams for one flagged town) only if a
> town proves genuinely uncrackable after SPREAD+HOLD soak.

# Design: "No town is uncapturable" (morning patch)

## Lane 67 follow-through (2026-07-02)

Verdict: this remains a shelved historical design. Do not implement the
`WFBE_C_AICOM_ESCALATE_*` ladder on the live build84/cmdcon36 target unless a
new soak proves one named town is still genuinely uncrackable after
`SPREAD-AND-HOLD.md` is active.

Live source already ships the verified small rows that made the old
"uncapturable town" diagnosis actionable:

| Row | Live anchor | Lane 67 call |
| --- | --- | --- |
| No `server_town.sqf` drain tweak | `Server/FSM/server_town.sqf:214-223` still drains linearly by present force and clamps the per-tick rate to at least 1. | Keep as-is. |
| Infantry must physically enter camps and depot ring | `Common/Functions/Common_RunCommanderTeam.sqf:1657-1813` dismounts foot infantry, sweeps camps, plants them inside the camp range, and keeps live orders. | Shipped. |
| Camp-first cannot trap a team forever | `Common_RunCommanderTeam.sqf:1728-1837` tracks no-progress camp passes and only disables that bail for capture mode 2, where camps are a real gate. | Shipped. |
| Depot-center drain wait | `Common_RunCommanderTeam.sqf:1869-1952` holds until the town flips or the bounded hold expires; it no longer leaves on the first empty resistance scan. | Shipped. |
| Captured towns get a short hold | `Common_RunCommanderTeam.sqf:1954-1984` emits `HOLD-CLAIM`; `Server/AI/Commander/AI_Commander_AssignTowns.sqf:246-267` preserves that holder until expiry. | Shipped by SPREAD+HOLD. |
| Repeated empty no-flip is bounded | `Common_RunCommanderTeam.sqf:2001-2032` retries live holds, then releases via `RELEASED uncapturable depot` after `WFBE_C_AICOM_CAPTURE_MAXPASSES`. | Shipped; soak signal, not an escalation trigger by itself. |
| AssignTowns abandon consequences | `AI_Commander_AssignTowns.sqf:326-479` still uses per-team and side blacklists, plus recycle tallies, for genuine stuck or unflippable targets. | Leave as-is; replacing this with concentration would fight SPREAD+HOLD. |

No remaining default-off code row was small or isolated enough for this lane.
The leftover proposal rows all require changing AssignTowns selection,
blacklist/abandon behavior, or the commander-team capture phase. Those areas are
already active in adjacent PRs and are also the exact concentration mechanics
that caused the dogpile concern. Known adjacent PRs on this pass included #222,
#238, #252, and AICOM follow-ups #285-#287, so lane 67 intentionally leaves code
untouched. Keep the only open action as soak evidence: watch for repeated
`TARGET_ABANDON`, `SIDE_BLACKLIST`, `camp-first NO-PROGRESS`,
`camp-first window expired`, `capture pass at`, `RELEASED uncapturable depot`,
`CAPTURED`, and `HOLD-CLAIM` for the same named town.

**Ray directive (2026-07-02):** the AI must never permanently give up on a town — it should
**escalate force** (more/heavier teams, concentrate) until the town falls.

Produced by fleet design run `wj1le31cr` (2 read-only Explore analyses + Opus synthesis), validated
against real code. Builds on tonight's live cmdcon39 capture fixes (drain-wait + arrival-gate +
stall-advance). **Design only — implement in the morning on Ray's word.**

## Core principle — the ESCALATION LADDER
Every current abandon path either (a) **blacklists** the town (no team sent for a cooldown) or
(b) **releases** a team to a *nearest-reachable* pick that silently drifts it OFF the hard town.
Replace both consequences with a per-side ladder `wfbe_aicom_escalate` = list of `[town, tier, expiry]`.
A stubborn town gets its **priority raised** and **more teams concentrated**; blacklisting becomes a
*rebalance flag*, never *removal from the pool*. Every abandon **detector** stays (good stall signal);
only its **consequence** changes.

## Flags — `Common/Init/Init_CommonConstants.sqf` (~L750, beside WFBE_C_AICOM_STUCK_ABANDON)
```
if (isNil "WFBE_C_AICOM_ESCALATE_MODE")     then {WFBE_C_AICOM_ESCALATE_MODE = 1};     //--- 1=escalate, 0=legacy blacklist/abandon (master rollback)
if (isNil "WFBE_C_AICOM_ESCALATE_STEP")     then {WFBE_C_AICOM_ESCALATE_STEP = 2};     //--- +N team quota per tier
if (isNil "WFBE_C_AICOM_ESCALATE_MAXTIER")  then {WFBE_C_AICOM_ESCALATE_MAXTIER = 3};  //--- cap tiers (=> +6 teams over base)
if (isNil "WFBE_C_AICOM_ESCALATE_TTL")      then {WFBE_C_AICOM_ESCALATE_TTL = 900};    //--- ladder entry lifetime (re-armed each stall)
if (isNil "WFBE_C_AICOM_ESCALATE_MAXCONC")  then {WFBE_C_AICOM_ESCALATE_MAXCONC = 12}; //--- absolute per-town team ceiling (guard §2.1)
if (isNil "WFBE_C_AICOM_ESCALATE_MAXTOWNS") then {WFBE_C_AICOM_ESCALATE_MAXTOWNS = 2}; //--- max simultaneously-escalated towns/side (guard §2.2)
```
Optional: surface `WFBE_C_AICOM_ESCALATE_MODE` as a 0/1 lobby toggle in `Rsc/Parameters.hpp` (near L446).

## Changes (all `if (mode>0){new} else {old}` wrappers → instant rollback)

**A — AssignTowns abandon blocks → escalate** (`Server/AI/Commander/AI_Commander_AssignTowns.sqf`)
- Position-stuck ABANDON (~L241-273) and uncapturable-parked ABANDON (~L332-362): in the escalate branch,
  do NOT blacklist, do NOT `_needs=true` (leave the team on-target as the anchor); instead bump the side
  ladder for `_goto` (raise tier `min MAXTIER`, refresh `expiry=time+TTL`; same list-walk idiom as the
  existing `_newSba`/`_sba` at 258-261). Log `TARGET_ESCALATE|team=..|town=..|tier=N` (renamed from ABANDON).
- **Stall-advance (~L319-331):** make it a REBALANCE not a give-up — keep `_needs=false` (team holds the
  target), bump the ladder for `_goto` (pull an *additional* team next pass), reset `wfbe_aicom_goto_since=time`.

**B — Selector reads the ladder to BOOST** (`AI_Commander_AssignTowns.sqf` selector ~L431-492)
1. Kill the exclusion (~L447-453): `if (mode>0) {_uncapturedF=_uncaptured} else {<existing blTowns subtraction>}` — escalated town never leaves the pool.
2. Boost quota (~L476-489): after the garrison-tier `_perTown` switch, `_perTown = _perTown + (tier*STEP)` for a ladder town, then `_perTown = _perTown min MAXCONC`.
3. Priority: two-pass rebuild `_spearOrdered` = escalated members of `_spear` first, then the rest (no A3 sort-with-code).

**C — "clear defenders, don't walk away" → heavier assault** (`Common/Functions/Common_RunCommanderTeam.sqf` ~L1187-1255)
- The `res-near==0` non-flip MAXPASSES release (~L1243-1255): in escalate mode, replace the release with
  keep-holding — reset `wfbe_aicom_cappasses=0`, do NOT null `wfbe_teamgoto`, do NOT set `_captureDone`
  (the anchor team must not vacate the ring or the drain never starts).
- **Locality:** `_logik` (side commander) is NOT in scope here (runs per-team, maybe on an HC). Do NOT write
  the ladder here. Set a **team-local broadcast** flag `_team setVariable ["wfbe_aicom_wantescalate", true, true]`
  and have Strategy/AssignTowns (which have `_logik`) fold it into the side ladder each cycle.

**D — No change:** relief-release (`Strategy.sqf` ~L389-417) + wedge-watchdog (~L512-551) already push teams
TOWARD offense; last-stand (~L88-118) is a legitimate self-preservation floor. Keep all three.

## Deadlock / whole-army guards (all A2-safe, flag-tunable)
1. **Per-town ceiling** `MAXCONC=12` — the `_perTown` clamp; enforced against `_assigned` (pre-seeds en-route teams) so it holds across ticks.
2. **Max escalated towns/side** `MAXTOWNS=2` — before appending a NEW ladder town, count live entries; if `>=MAXTOWNS`, refresh the existing highest-tier entry instead.
3. **Global "all stuck → still rotate"** — if an escalated town already has `>=MAXCONC` teams assigned, the team falls through to the existing nearest-reachable pick on the FULL pool (~L497-512). Because B.1 no longer empties the pool, this always yields a real different town → army keeps expanding the front while ≤12 teams grind the hard town.
4. **TTL self-heal** `TTL=900` — ladder entries expire + prune on read each cycle (same `>time` walk as the blacklist prune). Town flips / situation changes → escalation decays, mass redistributes.

**Master rollback:** `WFBE_C_AICOM_ESCALATE_MODE=0` restores every legacy path verbatim.

## True mechanical dead-end? — Verdict: NO server_town.sqf change needed
Drain scales **linearly** with attacker count (`server_town.sqf:212`, `_supply - (_res+_east+_west)*_rate`),
so piling teams on directly increases the drain numerator → the town falls. Both "appears uncapturable"
cases yield to mass: split camps (Mode-2 `_skip`) cleared by seizing all camps with more bodies; high
supply vs small force = slow-but-linear drain, shortened proportionally by more attackers.
**One caveat (flag, not blocker):** the dominion gate (`server_town.sqf:164-166,218-222`) lets the owner
RECOVER supply while numerically superior in the ring — attackers need **local numeric dominance in the
40m capture ring**, not just presence. `MAXCONC=12` (~96-144 units) overwhelms any normal garrison, so
covered in practice. If live RPT after this patch still shows a `TARGET_ESCALATE` town stuck at max tier,
THEN revisit a server_town.sqf recovery-rate tweak.

## Verification (morning)
Deploy behind `WFBE_C_AICOM_ESCALATE_MODE=1`; boot-smoke (0 errors, A2-safe). Soak: confirm
`TARGET_ESCALATE` replaces `TARGET_ABANDON`, stubborn towns accumulate teams + eventually flip, and the
front still expands (guard §2.3 fires) — no whole-army pile-up on one town.
