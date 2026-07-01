# Design: "No town is uncapturable" (morning patch)

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
