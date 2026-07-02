# AI-enhancement mods + pathfinding evaluation (A2 OA 1.64, WASP Warfare, dedicated + 2 HC)

Read-only recon deliverable (2026-07-02). **Nothing here is implemented.** No mission edits, no box writes, no
repo pushes were made producing this doc. Scope is A2 OA **1.64 EOL only** — every A3 command and every
post-1.64 engine feature (1.68 dynamic airports, 1.80 `flyInHeight`-for-planes, 2.20 heli-land-anywhere) is
flagged as **NOT APPLICABLE** and must not be relied on.

Ray's ask: *"very interested in improving pathfinding for AI units of all kinds; e.g. airplane leading/landing so
they don't crash."* Evaluate server/HC-side AI **mods** AND **mission-side** options.

House rules honored: A2 OA 1.64 only; **no sim/distance-gating** proposals; **HCs are sacred** (every mod trial
plan includes HC install); **no ACR** content.

---

## TL;DR (read this first)

1. **The flagship AI mod is ALREADY LIVE.** ASR AI (Robalo, A2 build **1.16.x**) is bundled inside `@adwasp`
   and runs on the box today, userconfig-tunable at `server-config/userconfig/ASR_AI/asr_ai_settings.hpp`
   (per `docs/design/OPTIONAL-CLIENT-MODS.md:306`). So "should we add ASR AI" is moot — the real questions are
   **(a) is `@adwasp` on the HC launch line** (if not, ASR AI is NOT touching the AICOM teams, which are
   HC-local), and **(b) it explicitly does nothing for aircraft**.
   - ⚠️ **Version-label discrepancy to resolve:** `OPTIONAL-CLIENT-MODS.md:306` labels the bundled build
     **"ASR AI 3" (`@ASR_AI3` / `asr_ai3_*`) v1.16.0.40**. But `asr_ai3` is Robalo's **Arma 3** line — the A2/OA
     line ends at **1.16.2** (`asr_ai_*`, bIdentify 4170). Either that doc loosely labels the true A2 build, or
     `@adwasp` ships an A3-derived variant. Only the A2 `asr_ai` build is valid config on OA 1.64. **Confirm which
     PBOs `@adwasp` actually contains** (`asr_ai_*.pbo` vs `asr_ai3_*.pbo`) during Action 0.
2. **ONE verification gates everything: does `C:\WASP\hc_launch.cmd` carry `-mod=...;@CBA_CO;@adwasp;@admkswf`?**
   The HCs launch `ArmA2OA.exe -client -connect=127.0.0.1` (scheduled tasks `MiksuuHC`/`MiksuuHC2`,
   `docs/HC-SLOT-MAGNET-HANDOFF.md:51`). **AI TEAMS ARE LOCAL TO THE HC** (`Common_RunCommanderTeam.sqf:178-181`),
   so a server-only AI mod does **not** touch them. If the HC `-mod` line lacks `@adwasp`, every AICOM team is
   currently running **vanilla** danger.fsm/skills. This single fact reframes the whole recommendation.
3. **No A2 mod fixes fixed-wing landing.** That is terrain-config (`class AirportBase` / ILS), not an addon.
   The engine cannot land a plane without a map-configured airfield. Blunt limits in Part B/§3.
4. **The biggest aircraft win we already own is turned off for the HCs.** `server_heli_terrain_guard.sqf`
   (look-ahead climb) runs **server-local only** and its own header says *"HC-local AICOM helis would need an
   HC-side copy of this loop — left as a follow-up."* That follow-up is mission-side rec #1 in Part C.
5. **Mods to REJECT for the warfare mission:** GL4, UPSMON, DAC, WW AICover — all inject waypoints / re-task
   groups / seek-and-withdraw, and will **fight the commander-team driver**. Full SLX/COSLX harms aircraft.

---

## PART 0 — Ground truth: what our mission already does to AI (the conflict baseline)

Read from the live worktree `Missions/[55-2hc]warfarev2_073v48co.chernarus`. This is the "decisive column" —
any mod that re-tasks or re-stances our groups collides with this.

### The per-team driver — `Common/Functions/Common_RunCommanderTeam.sqf` (2085 lines)
Each AICOM combat team's **entire lifecycle runs on the HC that founded it** (comment `:178-181`: *"The created
group is local to the HC for its entire lifetime, so waypoints, doMove, assignAsCargo, and orderGetIn all execute
with correct locality here."*). What it stamps, continuously, per order seq and per ~20s tick:

- **Founding posture** (`:97`): `_team setCombatMode "RED"; setBehaviour "AWARE"; setSpeedMode "FULL"`.
- **Road-march transit** (`:1017-1035`): re-lays a **road-node MOVE chain** (`wfbe_aicom_route`) with per-waypoint
  props `["AWARE",_marchCM,"","FULL"]` (YELLOW when `WFBE_C_AICOM_MARCH_YELLOW`, else RED), `setFormation "COLUMN"`,
  wide completion radius (`WFBE_C_AICOM_ROUTE_COMPLETION` 70). Foot squads get the same road chain (`:1063-1079`).
- **Arrival latch** (`:1160-1195`): flips to `COMBAT/RED/WEDGE` SAD (or `AWARE/YELLOW` remnant caution < 3 units).
- **Careful-gear governor** (`:1095-1157`): downshifts `setSpeedMode "LIMITED"` on steep slope (debounced) or an
  active stuck-strike, snaps back to `FULL` — fires **once per state transition**, hysteresis-guarded.
- **3-tier + Recovery-V2 unstuck** (`:822-972`): reverse-velocity pulse + lane-flip, dead-driver crew swap, slope-
  aware foot road-snap, water guard, TIER3 teleport to nearest road node (only when no player within 100-300m).
  **This is the "recovery v2" Ray said NOT to re-propose** (unflip/reverse/slope-snap/water-guard).
- **Rally / bounding withdrawal** (`:1082-1092`, `:1196+`).

The driver **owns the group's tasking and stance from cradle to grave and re-asserts it every cycle.** Anything
that also issues `doMove` / waypoints / `setBehaviour` to the *same* groups will tug-of-war with it.

### Posture stamps elsewhere (same idiom)
`AI_Commander_Execute.sqf:113` (`setBehaviour/CombatMode/Formation/SpeedMode` on human-ordered move/patrol/defense),
`AI_Commander_MHQReloc.sqf:260-323` (MHQ driver CARELESS/BLUE/FULL), `Server/AI/Orders/AI_Patrol.sqf` (side patrols
YELLOW/AWARE/COLUMN, road-biased via `WFBE_CO_FNC_BuildRoadRoute`), `server_town_ai.sqf` (town garrison FSMs).
`UpdateTeam` / `CanUpdateTeam` (`Server_UpdateTeam.sqf`, `Server_CanUpdateTeam.sqf`) gate re-tasking of WEST/EAST
teams — a **posture guard** that a reactive mod does not know about and would bypass.

### Aircraft handling we ship TODAY (grounds Part B)
- **Helis, transport/insert** (`Common_RunCommanderTeam.sqf:472-566`): `doMove` + `flyInHeight 60` run-in →
  `land "GET OUT"` + `flyInHeight 0` at a flat LZ (`isFlatEmpty [12,0,2,12,0,false]`), else **para-drop**
  fallback (`flyInHeight 120 + random`); then heli fly-off to nearest map edge + refund (`:568-624`).
- **Heli gun-run nudge** (`:188-279`): drops attack helis to `WFBE_C_AICOM_HELI_GUN_ALT` (35 m) to force cannon
  onto revealed targets; **HC-local**; + a base-reap of idle attack helis.
- **Fixed-wing** (`AI_Commander_Teams.sqf:1039-1066`, dispatch `:1079`; `Common_CreateTeam.sqf:131-141`): founded
  **PLANES air-start** ("FLY" + runway heading) at a captured airfield (`WFBE_C_AICOM_PLANE_AIRSTART` default 1,
  `WFBE_C_AICOM_PLANE_STACK_DEG` 25 fan). **Then they fly via the plain MOVE/SAD waypoints with NO cruise-altitude
  floor** — `isKindOf "Air"` is only used to keep them OUT of the ground-vehicle `doMove` list (`:309-315`). There
  is **no `flyInHeight` on AICOM fixed-wing in the order loop at all.** (This is a real gap — see Part B/§1.)
- **Server-local air** uses explicit heights: paradrop 300, supply 200, GUER air-def `WFBE_C_GUER_AIRDEF_HEIGHT`
  120, ScudStrike 350, W13 gunship 200, W22 Top-Gun plane 600 loiter via `AIPatrol` (self-despawn 180s).
- **`server_heli_terrain_guard.sqf`**: look-ahead terrain probe raises `flyInHeight` when ground rises into the
  path. Const `WFBE_C_AIHELI_TERRAIN_GUARD` = **1** (`Init_CommonConstants.sqf:1235`) and it's `ExecVM`'d
  (`Init_Server.sqf:958`) — **but the file is `if (!isServer) exitWith {}` and its header states scope is
  "SERVER-LOCAL AI helis only … HC-local AICOM helis would need an HC-side copy of this loop — left as a
  follow-up."** So on a live 2-HC box it does **nothing** for the AICOM helis that matter. (Minor doc nit: the
  file's inline default reads `,0` but the real constant is `1`; behavior is ON for server-local helis regardless.)

**Design invariant this creates:** the useful "AI flight help" surface for our real (HC-local) AICOM aircraft is
almost entirely **mission-side on the HC** — because that's where those units live.

---

## PART A — Era mod catalog (A2 OA 1.62–1.64, final versions)

**Sourcing note (honesty).** Armaholic is dead (`armaholic.com` is a parked GoDaddy domain); BI-forums and
community.bistudio.com hard-**403** automated fetch; ModDB and web.archive.org block bots. So the BI-forum
first-posts / readmes below were recovered via search-result extraction + ModDB/OFPEC mirrors, and every download
fact is anchored to the **bIdentify archive** (`bidentify.jerryhopper.com`), which parses cleanly per-folder and
per `/file/<id>`. Where a claim rests on one source it's flagged.

### bIdentify enumeration (PRIMARY source — pull these without re-hunting)

bIdentify uses two id schemes: **numeric** ids (older imports) and **UUID** ids (newer). Detail page =
`/file/<id>`. Folder listings that parse: `arma2/addons/misc` (numeric ~1815-2005), `arma2oa/addons/misc`
(4152-4266), `arma2/addons/units`, `arma2oa/addons/units` (no AI mods — cosmetic only, confirmed). The
`arma2oa/modules` folder returns "no files listed" via markdown conversion (table stripped) — **unenumerable**
this pass; probe nearby `/file/<id>` ranges if a module addon is ever needed.

| Mod | bIdentify id | Filename | Size (bytes) | Author | Date | SHA-256 | Status |
|---|---|---|---|---|---|---|---|
| **ASR AI** (A2 final) | **4170** | `ASR-AI-Addons-v1162.7z` | 59,004 | Robalo_AS | 2013-07-29 | `300e7a495ece54237b1fac105304ad8f6cca3d338d9fc70edc79864bd174b954` | live-mirror (dl→dead Armaholic) |
| ASR AI (early) | 4193 | `asr-1.1.zip` | — | Robalo_AS | — | — | listed |
| ASR camo-faces (dep-adjacent) | 1896 / 4181 | `asr_camofaces-1.0.zip` / `asr_config_camofaces_oa-1.0.zip` | 6,992 / 9,967 | Robalo | — | — | listed |
| ASR air-rearming | 1840 | `asr_airearming-0.96.zip` | 31,523 | Robalo | — | — | listed |
| **Zeus AI Combat Skills** | **1955** | `zeu_AI_v0.02d1.7z` | 123,032 | Protegimus | 2010-08-14 | `7fb1fc4eb46e5b0d28d0432920e42cf80b49c01dbbf084be42e0d48c2eaf2222` | listed |
| Zeus AI (ACE variant) | 1971 | `ZeusAI_ACE.7z` | 103,924 | — | — | — | listed |
| **Group Link 4 SFX Ed.** | **1974** | `GL4_SFXE_v-1-1-87.rar` | 45,983,989 | SNKMAN | 2010-03-14 | `20af92abc49931d0b7545b292d91105bd99ecfedb9de33f38fcc1ddcc0d56ca3` | listed |
| GLT Dynamic AI (GL-lineage) | 1966 | `glt_dynamic_ai_1.4.rar` | 190,054 | GLT | — | — | listed |
| **TPWCAS (suppression)** | **4212** | `tpwcas5.51.zip` | — | ollem | 2013-12-07 | — | **MIA** (dl dead) |
| TPW AI LOS (sibling) | 4214 | `TPW_AI_LOS_104.zip` | — | TPW | — | — | listed |
| **DAC 3** (A2 final) | **1826** | `DAC_V3_c.rar` | 33,837,454 | Silola | 2010-10-19 | `2c2cb9460e192a917e2c7c3b10dcc1debdb2aa56a2f9087ade6b28633ce0833d` | listed |
| **SLX / COSLX** patch #2 | UUID `d44655a4-9538-4429-abe0-12be799e04bd` | `COSLX_Patch_v2.6.zip` | — | Gunter Severloh | 2013-09-19 | — | listed (needs COSLX base + patch#1) |
| SLX ragdoll (component) | 1937 | `3-slx_ragdoll_v2.7z` | 4,042 | Solus | — | — | listed |
| **AI Heli Control** | **4198** | `Ai-Heli-Control-version-1.3.7z` | — | Fredkatz | 2013-01-21 | — | **MIA** (dl dead) |
| NEM AI fix | 1948 | `NEM_AIfix.7z` | 15,728 | — | — | — | listed |
| ai_dispersion | 1899 | `ai_dispersion.rar` | 377 | — | — | — | listed |
| RMM AI Range | 1965 | `RMM_AI_Range.7z` | 657 | — | — | — | listed |
| Iranian Forces AI Config | 4186 | `@Iranian_Forces_AI_Config.rar` | 2,707,922 | — | — | — | listed |
| Khe Sanh ILS fix (map) | 1817 | `_USSKheSahnILS.7z` | 1,896 | — | — | — | listed (airfield config) |
| Chernarus ILS corrected (map) | 1949 | `ChernarusILScorrected.7z` | 1,218 | — | — | — | listed (airfield config) |
| CBA_CO (dependency) | 1905 | `@CBA_CO_v1.0.1pre2.7z` | 304,987 | — | — | — | live (already server-side) |

**UPSMON** is a **script**, not an addon — no bIdentify addon entry; it lives in the editing/scripts area
(dev-heaven origin). **WW AICover** A2 origin did not surface as a discrete misc-folder archive (mostly the A3
port is indexed) — treat as script/thread-distributed.

### Per-mod evaluation

Legend for the decisive **CONFLICT** column, against our commander-team driver (re-lays waypoints + stamps
behaviour/combatMode/formation/speedMode continuously on HC-local groups):
- **LOW** = pure skill/accuracy/dispersion/suppression config; no group tasking → layers cleanly.
- **MEDIUM** = danger.fsm / reaction micro-behavior; can perturb immediate movement/stance under fire.
- **HIGH** = injects waypoints / re-tasks / seek-and-withdraw → directly fights the driver.

---

#### 1. ASR AI (Robalo) — **A2 final 1.16.2** (bIdentify 4170) — *ALREADY LIVE in `@adwasp`*
> See TL;DR ⚠️: `@adwasp` is labeled `asr_ai3` v1.16.0.40 in `OPTIONAL-CLIENT-MODS.md` — reconcile A2 (`asr_ai`,
> 1.16.2) vs A3 (`asr_ai3`) during Action 0. Below describes the A2 `asr_ai` build (the only one valid on 1.64).
- **(1) What it changes:** config + FSM mod. Redefines **CfgAISkill** interpolation and assigns every AI unit
  **randomized per-unit sub-skills** (aimingAccuracy, aimingShake, aimingSpeed, spotDistance, spotTime, courage)
  by unit class; changes **CfgAmmo dispersion**; modifies **danger.fsm** reaction functions incl. a suppression
  response (crouch on ~10 m near-miss, prone if >5 rounds/5 s); gear-based camo; optional `sys_airearming`
  auto-rearm. Separable PBOs (`asr_ai_main`, `asr_ai_sys_aiskill`, `asr_ai_sys_airearming`). Tunable via
  `userconfig\asr_ai\asr_ai_settings.hpp`.
- **(2) Install surface / LOCALITY:** author's own words — *"configures only the AI **local to the machine** where
  it is installed."* ⇒ **HC-REQUIRED** to affect our AICOM teams (they're HC-local). Server-only touches only
  server-local AI. **This is the crux:** ASR AI is bundled in `@adwasp`, which the **server** loads — but unless
  the **HC** `-mod` line also loads `@adwasp`, ASR AI is **not** touching the commander teams at all. *(Verify —
  see Part C action 0.)*
- **(3) Signatures/keys:** **signed** — ships `asr_ai.bikey` + per-PBO `.bisign`. (Notably, `@adwasp`/`@admkswf`
  already ship `.bisign` for an `asr_ai` key per `OPTIONAL-CLIENT-MODS.md:42`.) Box is `verifySignatures=0` so
  moot today; relevant if v2 is ever enabled.
- **(4) Conflict:** **LOW-to-MEDIUM.** Skill/dispersion/camo half = LOW (pure config, layers cleanly under our
  stamps). The **danger.fsm** half = MEDIUM (documented user reports of "reluctant to move to waypoint" and
  "waypoint skipping" with ASR on — under fire it can break units off, which our per-cycle re-stamp then fights).
  Since it's already live, any such interaction is *already in our soak data* — but it has never been checked
  **on the HC** because we don't know if the HC even loads it.
- **(5) Aircraft:** **none.** Pilots/gunners inherit generic skill/spotting only; **no flight, landing, or
  flyInHeight logic.** "ASR fixes my pilots" = skill side-effect at most.

#### 2. Zeus AI Combat Skills (Protegimus/tcp) — 1.0x/1.02.x modular
- **(1) What it changes:** config modules (`zeu_cfg_core_ai_engagement/sensors/skills/spotting`). Extends spotting
  to ~500 m+, faster acquisition, **suppressive-fire response**, **cover-seeking + bounding CQB**, grenade use,
  reduced hearing, gunner reactivity. Does **not** change dispersion. The cover/bounding behavior implies
  danger-FSM-level changes (not confirmed as a literal danger.fsm swap).
- **(2) Locality:** author recommends **server + clients**; behaves as a **local-AI** mod ⇒ **HC-REQUIRED** for
  our teams. Server-only insufficient.
- **(3) Signatures:** **signed** — per-PBO `.bisign` on each module.
- **(4) Conflict:** **MEDIUM-to-HIGH.** More behavior-heavy than ASR AI — the **cover-seeking/CQB actively moves
  units**, overlapping more with a controller that owns movement/stance. Higher risk of tug-of-war than ASR AI.
- **(5) Aircraft:** **none** (air crews get generic spotting/engagement tuning only).
- **Verdict:** redundant with the ASR AI we already run and a worse conflict fit. **Reject** for the warfare mission.

#### 3. Group Link 4 — SFX Edition (SNKMAN) — `v1.1.87`
- **(1) What it changes:** a **reactive AI system** — detected-enemy **reinforcement calls, flanking, artillery
  calls, garrison/patrol spawning**, High-Command tooling (per-class request ranges, Air = 30,000 m), 3D HC
  markers, "Force Move" dialog, some **helicopter-HC bug fixes**, plus SFX. It **injects waypoints and re-tasks
  groups**.
- **(2) Locality:** must run where groups are local ⇒ HC + server; heavy.
- **(3) Signatures:** requires **CBA**; distributed with keys per era norms.
- **(4) Conflict:** **HIGH — reject.** GL4's entire purpose (re-task groups to flank/reinforce) is exactly what
  our driver already owns. It would fight the road-march/arrival/recovery state machine and the `UpdateTeam`
  posture guard directly. This is the textbook "mod that injects waypoints" case.
- **(5) Aircraft:** improves *directing* aircraft (HC air-support) and fixes some heli-HC bugs, but **no flight-
  model / landing / terrain-avoidance** change.

#### 4. TPWCAS / TPWC AI Suppression System (TPW, -Coulum-, fabrizio_T, ollem) — **final 4.x/5.51**
- **(1) What it changes:** **suppression in place.** On effective incoming fire a unit crouches/kneels (near-miss
  ~10 m), drops/crawls if sustained (>10 rounds/5 s), temporarily loses accuracy, **auto-returns to prior stance
  after ~10 s (self-clearing)**. It reads fire events and applies stance/skill debuffs — it does **not** re-lay
  the group's waypoints or re-task it.
- **(2) Locality:** ships **both** a script and an addon (one download); **requires CBA**; has **explicit,
  automatic Headless-Client detection/support** — directly relevant to our HC architecture. ⇒ works HC-side by
  design (addon on HC, or script executed with HC locality).
- **(3) Signatures:** addon version ships keys per era norms (script needs none).
- **(4) Conflict:** **LOW-to-MEDIUM.** It's a stance/accuracy debuff, not tasking. The one caution: it forces
  prone/crawl, which momentarily overrides our `setFormation`/`setSpeedMode` on a unit under heavy fire — but it
  self-clears and does not touch waypoints, so the driver re-asserts on the next tick. This is the **least-
  conflicting behavior mod** in the catalog and the only one with first-class HC support baked in.
- **(5) Aircraft:** **none** (infantry suppression only).
- **Note:** its value (visible suppression) partially overlaps ASR AI's danger.fsm suppression, which we already
  run. Only worth trialing if we want *stronger/more visible* suppression than ASR gives — and only after the
  Part C ASR-on-HC verification, to avoid double-suppressing.

#### 5. SLX (Solus) / COSLX (Gunter Severloh recompile) — AI subset
- **(1) What it changes:** large suite. Relevant subset: **`SLX_AI_Steering`** — per the WarMod index, *"makes AI
  drive/pilot cars/helicopters/planes better with much less crashing. It has no dependencies"* (standalone PBO).
  Other SLX AI PBOs add wounds/first-aid, group link (GL3-style reinforcement — **re-tasking**), ragdoll, and
  **aircraft crash FX**.
- **(2) Locality:** local-AI ⇒ HC + server for the steering to affect HC-local hulls.
- **(3) Signatures:** era keys; COSLX distributed via Google Drive + patches (`COSLX_Patch_v2.6.zip`).
- **(4) Conflict:** **mixed.** `SLX_AI_Steering` **in isolation** = LOW/MEDIUM (vehicle/aircraft driving behavior,
  no waypoint injection). The **full SLX/COSLX bundle** = HIGH (its group-link component re-tasks groups) **and is
  widely reported to HARM aircraft** — COSLX "makes helicopters crash the game," "breaks the UAV (drunken bird)."
- **(5) Aircraft:** `SLX_AI_Steering` is the **only component in the entire catalog with a direct "less air
  crashing" claim** — but it's the author's own claim with no controlled before/after proof, and it's wrapped in a
  bundle that otherwise damages air. **Trial only the isolated steering PBO**, never the bundle. See Part C.

#### 6. UPSMON (Monsada, fork of Kronzky UPS) — **script, final 5.0.7**
- **(1) What it does:** urban-patrol scripting — assigns **patrol routes, garrisoning, flanking, taxi, reinforce**
  to groups you hand it. It **creates/tasks group waypoints**.
- **(2) Locality:** a script → must **execute on the machine where the group is local** (the HC) to control HC-
  local groups; a documented user report says it **does not work with HC-created units**.
- **(3) Signatures:** n/a (script).
- **(4) Conflict:** **HIGH if applied to our commander teams** (it owns their waypoints → direct fight). **LOW
  only** if used for *separate* ambient/garrison groups that the commander driver never touches — but we already
  have `server_town_ai` + side patrols for that. **Reject** for the AICOM teams.
- **(5) Aircraft:** none of note.

#### 7. DAC 3 (Silola) — **script (+ optional addon), A2 final V3.0c** — *already used in Ray's last-stand repo*
- **(1) What it does:** zone-based **spawning** of its OWN groups with its OWN waypoint/behavior manager
  (patrols, camps, reactions). It **creates and fully tasks** the groups it spawns.
- **(2) Locality:** script → runs where invoked; groups are local to that machine.
- **(3) Signatures:** addon form exists (a `dac_sounds` `.bisign` was flagged missing historically → partial
  signing); script form needs none.
- **(4) Conflict:** **HIGH if pointed at AICOM groups; N/A-to-LOW if used only for its own ambient groups.** DAC's
  model is "DAC owns everything it spawns" — layering it *over* the commander economy would mean two spawners and
  two taskers competing for the AI budget/pop-cap (`TOTAL_AI_MAX`) and the same map. It's a great fit for a
  **scripted last-stand** (which is why Ray uses it there), and a poor fit for **CTI warfare** where the commander
  brain is the spawner/tasker. **Reject** for the main warfare mission.
- **(5) Aircraft:** DAC can spawn air patrols but with the same fly-to-waypoint engine limits; no flight fix.

#### 8. WW AICover (William Wallace)
- **(1) What it does:** AI seek-cover micro-behavior on nearby fire; on mortar/area threats it **withdraws the
  group away from the threat source**.
- **(2) Locality:** local-AI/script ⇒ HC-side to affect HC-local groups.
- **(3) Signatures:** thread/script-distributed (A2 origin faint; mostly A3 port indexed).
- **(4) Conflict:** **HIGH — reject.** The **withdraw-from-threat** behavior directly re-tasks group movement,
  which contradicts a commander team ordered to ASSAULT an objective (our arrival latch sets COMBAT/RED). It would
  pull attacking teams off objectives.
- **(5) Aircraft:** none.

#### 9. Honorable mentions on bIdentify (small, aircraft/AI-adjacent)
- **AI Heli Control 1.3** (id 4198, Fredkatz, MIA) — a **script/addon that feeds the engine a helipad/`landAt`
  target** so AI helis land reliably. **Workaround, not an engine fix** — and we already implement its core idea
  (`land "GET OUT"` + flat-LZ / para fallback in `Common_RunCommanderTeam.sqf`). No need.
- **NEM_AIfix** (id 1948), **ai_dispersion** (id 1899), **RMM_AI_Range** (id 1965) — tiny accuracy/range config
  tweaks; wholly **redundant** with ASR AI's CfgAISkill/dispersion. Ignore.
- **Chernarus ILS corrected** (id 1949), **`_USSKheSahnILS`** (id 1817) — **map/airfield ILS config** fixes, not
  AI mods. Relevant only to the *fixed-wing landing* problem (Part B/§2) and only if we deploy a matching serverMod
  — not recommended (client-desync surface).

---

## PART B — Aircraft specifically

### §1. Mission-side (OUR code) — what we set today and concrete improvements

**What we set (file:line):**
- Helis: `flyInHeight 60` run-in, `0` land, `35` gun-run (`WFBE_C_AICOM_HELI_GUN_ALT`), `120+` para
  (`Common_RunCommanderTeam.sqf:539,549,216,555`); fly-off `90+random` (`:603`).
- Server-local air explicit heights: 300/200/120/350/200/600 (paradrop/supply/GUER/Scud/W13/W22 — see Part 0).
- Terrain guard: `server_heli_terrain_guard.sqf` look-ahead climb — **server-local only** (`if (!isServer)
  exitWith`), header admits HC copy owed.
- **Fixed-wing AICOM: NO `flyInHeight` in the order loop** — planes fly the plain MOVE/SAD waypoints at engine-
  chosen altitude (`:309-315` only excludes air from the ground `doMove` list).

**Concrete mission-side improvements (ranked in Part C):**
1. **Port `server_heli_terrain_guard` to the HC.** It's the single highest-value existing lever and it explicitly
   excludes the HC-local AICOM helis that actually matter. A `Headless/` copy of the same look-ahead loop
   (`local _h` filter, same probe idiom) would give the AICOM gunships the terrain-climb they currently never get.
   *(File to add: `Headless/headless_heli_terrain_guard.sqf`, executed from the HC init; gate on the SAME
   `WFBE_C_AIHELI_TERRAIN_GUARD`.)*
2. **Give AICOM fixed-wing a cruise-altitude floor + strike/loiter discipline.** In the order loop, for a
   `_isPlaneTeam` (flag already exists at `:38-53`), on each fresh order set a safe `flyInHeight` (see numbers
   below), and — critically — do **not** hand jets a ground SAD at the objective: give them a **CYCLE/loiter over
   the target with a large radius** and `limitSpeed`/`setSpeedMode "LIMITED"` only for a strafing pass, mirroring
   the W22 Top-Gun pattern (`AI_Commander_Wildcard.sqf:1388-1419`) which already flies a plane cleanly at 600.
   Honest caveat: on **1.64 `flyInHeight` reliably steers HELICOPTERS; plane support is a 1.80 feature** — so the
   floor helps helis strongly and planes only weakly. The **big** fixed-wing win is loiter-radius + not-a-ground-
   SAD, not the height command.
3. **Terrain-aware `flyInHeight` floors by map.** Chernarus is gentle; Takistan/Zargabad are steep — a fixed 60 m
   heli run-in porpoises into Takistan ridgelines. Branch the heli run-in / loiter floor off `worldName` (the
   mission already branches worldSize this way at `:579-584`): e.g. heli transit floor ~50 (CH) / ~80-100 (TK/ZA).
4. **Loiter-radius floors + `limitSpeed` on approach for ALL AI air we control.** Small loiter radius over terrain
   = bank-into-hillside crash (Part B/§3-iii). Enforce a minimum loiter radius and slow the final approach leg.
5. **LAND waypoints ONLY at real airfield configs.** Our heli code already gates on `isFlatEmpty` and falls back
   to para — good. For any *plane* return-to-base, only ever `landAt` a **map-config airfield ID** (CH: `landAt 0`
   = Grishno); never issue a plane `land` where no `AirportBase` exists, or it crash-lands / circles. Prefer to
   just **fly jets off-map + refund** (we already do this for transport helis) instead of landing them.

(Note: the new EASA-on-AI kits — `Common_RunCommanderTeam.sqf:334-407` — change air *loadout/survivability*, not
flight; out of scope for pathfinding but relevant to "aircraft last longer to reach the fight.")

### §2. Mod-side — does any era mod fix AI flight?
**No mod fixes the core problems.** The only component with a *direct* flight claim is **`SLX_AI_Steering`**
("much less crashing," author claim, no controlled proof; standalone PBO; but the surrounding SLX bundle harms
air). Everything else (ASR AI, Zeus, GL4, TPWCAS, DAC) does **nothing** for flight — at most pilot *skill* as a
side-effect. **AI Heli Control** and the various "make AI land a heli in MP" solutions are **workarounds** that
feed the engine a helipad/`landAt` target — which our mission already does.

### §3. Engine facts — what CANNOT be fixed in 1.64 (blunt)
1. **Fixed-wing AI cannot land without a map-config-defined airfield** (`class AirportBase` with `ilsPosition[]`,
   `ilsDirection[]`, `ilsTaxiIn[]`, `ilsTaxiOff[]`). Landing resolves to an airport by ID / nearest to a GET OUT
   waypoint. No airfield → **crash-land or circle forever.** Dynamic-airport fallback is **1.68+** — NOT in 1.64.
   Not fixable by mission scripting; only by using a properly-configured map.
2. **AI aircraft altitude is terrain-relative and engine-managed.** `flyInHeight` chases the ground contour and
   **won't dodge trees/masts** at low set heights (biki: *"avoid too low altitudes … won't evade trees and
   obstacles"*; default 100 m, min 20 m). There is **no ASL flight command in 1.64** (`flyInHeightASL` is A3), and
   `flyInHeight` reliably affects **helicopters only** in 1.64 (**planes added in 1.80**). Also: it "takes effect
   with the next move command" (OFPEC) — setting it mid-leg does nothing until the next waypoint.
3. **Aircraft "pathfinding" is minimal — near straight lines between waypoints, engine-chosen pitch/altitude,
   fixed bank.** No terrain-aware route planner; low legs + tight loiters → CFIT. Planes also weave/overshoot
   rather than tracking a straight line (long-standing complaint).
4. **Weak inter-aircraft separation** — grouped aircraft bunch on the leader in turns/approach → mid-air / runway
   chain crashes. Only mitigated by **single-vehicle groups + staggered waypoints**, never fixed. (We already fan
   plane headings at spawn, `WFBE_C_AICOM_PLANE_STACK_DEG` — extend the principle to keep air teams to 1 hull.)
5. **Helis have no AI autorotation and imperfect flare** — damaged/steep descent = hard landing/rollover; mitigate
   with an explicit helipad target (we do).

### Concrete numbers people recommend (A2/OA era)
- `flyInHeight`: engine default **100 m**, hard min **20 m**; older command-ref usable range **50–1000 m**.
- **Planes:** practical floor **~150 m**, **150–300 m over hills** (biki example `flyInHeight 150`) — but remember
  this mostly bites for helis on 1.64.
- **Helicopters:** transit band **~50 m → ~100 m** over terrain; land only to a **helipad within 500 m** (engine's
  GET-OUT search radius); below ~50 m over non-flat ground = gambling on obstacle strikes.
- **Loiter radius:** keep **large** (hundreds of metres) so bank stays shallow; small radius + terrain-relative
  loiter altitude = crash.
- **Approach:** `limitSpeed` + `setSpeedMode "LIMITED"` on the final leg markedly cuts crash-landings/overshoots
  (technique is consensus; exact km/h is mission-specific — people use ~100–200 for the final leg).

---

## PART C — Recommendation (ranked plan)

### Action 0 (BLOCKER — do this before anything else): verify the HC `-mod` line
**Read `C:\WASP\hc_launch.cmd` (read-only SSH).** Confirm whether it carries
`-mod="...;@CBA_CO;@adwasp;@admkswf"` like the server, or a bare `-mod` (or none).
- **If `@adwasp` IS on the HC line:** ASR AI is already affecting the AICOM teams — good; skip the "add ASR"
  step, go straight to the mission-side work.
- **If `@adwasp` is NOT on the HC line:** the AICOM teams are running **vanilla** AI (no ASR skills/danger.fsm)
  despite the server having ASR — the **highest-impact, lowest-risk single change** is to add the SAME
  `@CBA_CO;@adwasp;@admkswf` to `hc_launch.cmd` so the flagship AI mod we already ship finally reaches the units
  that matter. This is not "adding a mod" — it's making the mod we already run apply on the HCs. **Install =
  edit `hc_launch.cmd`, restart `MiksuuHC`/`MiksuuHC2`. Rollback = revert the file, restart the tasks.**
  (Box is `verifySignatures=0`, so no key work needed; CBA must load FIRST for XEH.)

### Which mod to trial on the box + HCs FIRST
**Trial candidate: `SLX_AI_Steering` (isolated PBO only) — as a bounded aircraft experiment.** It's the only
catalog item with a direct "less air crashing" claim, standalone, no CBA dep. But it's an **author claim**, so
treat it as an experiment, not a rollout.
- **Source:** SLX for A2 CO (Solus) — extract only `slx_ai_steering.pbo` (+ its `.bisign` if present). SLX is on
  bIdentify via the COSLX line (`COSLX_Patch_v2.6.zip`, UUID `d44655a4-9538-4429-abe0-12be799e04bd`, Gunter
  Severloh 2013-09-19) and ModDB `slx-mod-co`; **do NOT deploy the full bundle** (it harms aircraft — heli/UAV
  crashes).
- **Signed?** era `.bisign`; irrelevant at `verifySignatures=0`.
- **Install steps:** (1) new `@slx_steer\addons\slx_ai_steering.pbo`; (2) add `@slx_steer` to **both** the server
  `-serverMod=` (or `-mod=`) **and** `hc_launch.cmd` `-mod=` (HC-local hulls need it — locality!); (3) restart
  server + both HC tasks; (4) soak one full match AI-vs-AI, watch `AICOMSTAT` + RPT for heli/plane crash rate vs
  the pre-change baseline.
- **Rollback:** drop `@slx_steer` from both launch lines, restart. Isolated PBO ⇒ clean removal.
- **Honest expectation:** low confidence it helps planes (engine limits in §3), modest chance it steadies heli/
  vehicle handling. If no measured crash-rate drop in one soak → **remove.**

**Second, only if we want stronger visible suppression than ASR gives:** **TPWCAS 5.51** — it's the one behavior
mod with **native HC support** and LOW tasking conflict. But it overlaps ASR's suppression, so only trial it
*after* Action 0, and A/B against ASR-alone. (Download is MIA on bIdentify id 4212 → source from a live mirror /
the TPW GitHub before trialing; requires CBA — already present.)

### Which to REJECT and why (conflict)
- **GL4** — HIGH: injects reinforcement/flank **waypoints** + re-tasks groups → fights the commander driver and
  `UpdateTeam` guard. Rejected.
- **UPSMON** — HIGH on our teams (owns waypoints) + reported broken with HC-created units. Rejected.
- **DAC 3** — HIGH if pointed at AICOM groups (two spawners/taskers competing for pop-cap). Great for the
  last-stand repo, wrong tool for CTI warfare. Rejected for the main mission.
- **WW AICover** — HIGH: **withdraw-from-threat** pulls attacking teams off objectives. Rejected.
- **Zeus AI** — MEDIUM-HIGH conflict (active cover/CQB movement) + **redundant** with the ASR AI we already run.
  Rejected.
- **Full SLX/COSLX bundle** — HIGH conflict (group-link re-tasking) + **actively harms aircraft**. Rejected
  (steering PBO in isolation only, as above).
- **AI Heli Control / NEM_AIfix / ai_dispersion / RMM_AI_Range / ILS map fixes** — redundant with what we already
  do, or map-config (client-desync) surface. Skipped.

### TOP-5 mission-side pathfinding improvements we can do ourselves (ranked by impact)
*(Building on already-shipped work — road-snapped marches, recovery-V2 unflip/reverse/slope-snap/water-guard — and
NOT re-proposing those.)*

1. **Port the heli terrain-guard to the HC** *(aircraft, highest impact)* — add
   `Headless/headless_heli_terrain_guard.sqf` mirroring `server_heli_terrain_guard.sqf` with a `local _h` filter,
   executed from HC init, gated on `WFBE_C_AIHELI_TERRAIN_GUARD`. This is the exact "follow-up" the existing file's
   header defers, and it's the only thing that gives the **HC-local AICOM gunships** terrain-climb. Low risk
   (reactive, raises height only). **Impact: high** (directly attacks "helis crash into hills," on the units Ray
   sees).
2. **Fixed-wing loiter/strike discipline for AICOM plane teams** *(aircraft)* — in the order loop, for
   `_isPlaneTeam`, replace the ground-SAD-on-objective with a **large-radius CYCLE/loiter + `limitSpeed` strafing
   pass** (mirror the working W22 pattern), set a cruise `flyInHeight`, and **RTB = fly-off-map + refund** (reuse
   the transport-heli fly-off) rather than `land`. **Impact: high** (jets currently get a nonsensical ground SAD
   and no altitude discipline; this is the "planes don't crash / actually strafe then leave" fix).
3. **Map-aware air altitude floors** *(aircraft)* — branch heli run-in / loiter / gun-run floors off `worldName`
   (CH gentle vs TK/ZA steep), same idiom as the existing worldSize branch. Prevents the fixed 60 m run-in
   porpoising into Takistan ridgelines. **Impact: medium-high**, trivial + low-risk.
4. **Keep AI air teams to a single hull + stagger** *(aircraft, engine-limit mitigation)* — enforce 1 aircraft per
   AICOM air team (extend the existing plane-heading fan rationale) so wingmen don't bunch/chain-crash on approach
   (§3-iv). **Impact: medium**, removes a whole crash class.
5. **Ground: front-aware egress lane widening at chokepoints** *(ground, not recovery-V2)* — the road-march already
   snaps to nodes; the residual grind is **many teams funneling one bridge/pass**. Add a light per-team lateral
   lane spread on the *approach* to known chokepoints (bridges/mountain passes), distinct from the reactive lane-
   flip in recovery (that only fires post-wedge). Proactively spreading the column entering a chokepoint reduces
   the wedges that trigger recovery in the first place. **Impact: medium** (fewer stuck-strikes → smoother fronts).

---

## Appendix — key file references
- Driver / posture / recovery / aircraft: `Common/Functions/Common_RunCommanderTeam.sqf`
  (founding `:97`; heli insert `:472-566`; fly-off `:568-624`; gun-run `:188-279`; unstuck+RecoveryV2 `:822-972`;
  road-march `:1017-1080`; governor `:1095-1157`; arrival latch `:1160-1195`; plane-team flag `:38-53`).
- Air-start: `Server/AI/Commander/AI_Commander_Teams.sqf:1039-1079`; `Common/Functions/Common_CreateTeam.sqf:131-141`.
- Heli terrain guard (server-only; HC copy owed): `Server/server_heli_terrain_guard.sqf`; wired `Server/Init/Init_Server.sqf:958`;
  const `Common/Init/Init_CommonConstants.sqf:1235`.
- Loiter reference (works): `Server/Functions/AI_Commander_Wildcard.sqf:1388-1419` (W22), `:940-960` (W13).
- Posture guard: `Server/Functions/Server_UpdateTeam.sqf`, `Server_CanUpdateTeam.sqf`; patrols `Server/AI/Orders/AI_Patrol.sqf`.
- Live box + HC facts: `docs/design/OPTIONAL-CLIENT-MODS.md` (ASR-in-`@adwasp` `:301`; box mod line `:23`;
  `verifySignatures=0` `:33`; asr_ai bisign `:42`); `docs/HC-SLOT-MAGNET-HANDOFF.md:51` (HC launch line).
- Related aircraft design (separate scope): `docs/design/AICOM-AIRCRAFT.md` (airfield spawn + factory-research).

## Appendix — bIdentify pull list (verified this pass)
ASR AI **/file/4170** `ASR-AI-Addons-v1162.7z` (sha `300e7a49…b954`) · Zeus **/file/1955** `zeu_AI_v0.02d1.7z`
(sha `7fb1fc4e…2222`) · GL4 **/file/1974** `GL4_SFXE_v-1-1-87.rar` (sha `20af92ab…6ca3`) · TPWCAS **/file/4212**
`tpwcas5.51.zip` (MIA) · DAC **/file/1826** `DAC_V3_c.rar` (sha `2c2cb946…833d`) · COSLX patch
**/file/d44655a4-9538-4429-abe0-12be799e04bd** `COSLX_Patch_v2.6.zip` · AI-Heli-Control **/file/4198**
`Ai-Heli-Control-version-1.3.7z` (MIA) · CBA **/file/1905** `@CBA_CO_v1.0.1pre2.7z`. Folders that enumerate:
`/files/arma2/addons/misc`, `/files/arma2oa/addons/misc`; `/files/arma2oa/modules` does not (table stripped).
