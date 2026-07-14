# Server-side engine-patch catalog (A2 OA 1.64 EOL — RV engine binary)

Research/ideas deliverable (2026-07-14). **Nothing here is implemented.** No engine binary was modified,
no mission edits, no box writes. This is a scoping catalog for a *separate binary-patch project* — it is
**off the mission tree** and does NOT go through the LoadoutManager / lint / mirror / flag-gate workflow that
governs `.sqf` mission changes. Different game entirely.

Scope is A2 OA **1.64 EOL only**. Every A3 command and every post-1.64 engine feature (1.68 dynamic airports,
1.80 `flyInHeight`-for-planes, `flyInHeightASL`) is a **NOT-A-FLAG-FLIP** wall — see "Non-starters."

---

## Premise (what makes this viable for us specifically)

- **All three nodes are ours** — dedicated server + 2 HCs. We control every executable that runs AI.
- **Constraint reduces to one line: change nothing on a client/player's game.** Everything inside
  `arma2oaserver.exe` and the two HC `ArmA2OA.exe` processes is fair game. The server verifies *PBO*
  signatures on connecting clients — it never checksums the server/HC executables — so a patched server/HC
  binary connecting to our own server passes as long as PBOs are untouched.
- **AI is HC-local.** AICOM combat teams live on the HC that founded them (`Common_RunCommanderTeam.sqf:178-181`),
  so the highest-value binary to patch for AI work is the **HC's `ArmA2OA.exe`**, not just the server exe. HC
  architecture is explicitly in-scope for us.
- **Frozen EOL binary = ideal patch target.** No updates ever ship, so a patch is stable forever; the target
  never shifts under us. This is a genuine advantage over patching a live-service game.
- **Load is shared** across server + 2 HC at ~300–400 AI in big battles. The bottleneck is the **single-threaded
  RV simulation** on whichever node owns the groups — AI cost (pathfinding + perception + FSM), not a hotspot
  you can script around.

The engine walls this project targets are already enumerated in
`docs/design/AI-MODS-AND-PATHFINDING.md` Part B §3 ("Engine facts — what CANNOT be fixed in 1.64"). A binary
patch is the *only* tool that reaches them. The entire `STUCK-RECOVERY-V2-REFERENCE.md` apparatus is a
mission-side workaround for engine pathfinding we currently can't reach.

---

## Hard prerequisites (before ANY patch below)

1. **Engine-side profiler / timing tap (item #7).** Items #4 and #5 are un-targetable and un-verifiable
   without real subsystem timing. Build this first. Until then, VTune / AMD uProf sampling the HC process under
   a synthetic 300–400 AI load is the interim way to find hot addresses to anchor in Binary Ninja.
2. **A test instance.** A bad sim/path patch = crash or silent state corruption mid-battle. Never validate on
   the live game; drive a mirror under synthetic AI load and measure vs. a pre-change baseline.
3. **Owner clearance on two items** — see "Open questions."

---

## The catalog

Feasibility: ★★★ tractable / ★★ hard / ★ very hard. Risk is engine-crash/behavior-corruption risk.

| # | Patch | Maps to (our pain) | Feasibility | Risk | Origin |
|---|---|---|---|---|---|
| 1 | **Fixed-wing altitude floor** — clamp plane AI to a terrain-relative min altitude in the flight update loop | §3.2 "flyInHeight = helis only on 1.64." AICOM jets fly with NO altitude floor (`AI_Commander_Teams.sqf`) | ★★ | Low-med | Ray |
| 2 | **Aircraft terrain/obstacle look-ahead** — extend hardcoded CFIT-avoidance clearance/lookahead | §3.2/§3.3 "won't evade trees/obstacles; no terrain-aware route planner." Retires `server_heli_terrain_guard` band-aid | ★★ | Med | Ray |
| 3 | **Inter-aircraft separation constant** — widen so grouped air stops bunching on the leader | §3.4 "grouped aircraft bunch → chain crashes." Currently mitigated with 1-hull teams + heading fan | ★★★ | Low | Ray |
| 4 | **Ground pathfinding cost function / search depth** — road bias, obstacle inflation, chokepoint funnel | The reason recovery-V2 exists: bridge-funnel, chokepoint wedges. Fixing at source can **retire large chunks of unstuck SQF** | ★ | High | Ray |
| 5 | **Per-AI cost throttles** — pathfinding recalc interval, perception/LOS scan frequency, FSM tick rate (hardcoded budgets) | 300–400 AI single-thread wall. Makes each AI **cheaper without cutting GUER count** | ★★★ | Med | Ray |
| 6 | **New engine-exported script commands** — real `flyInHeightASL`, pathfinding-cost override, etc. | Force multiplier: adds primitives our existing SQF workflow can drive | ★ | Med | Ray |
| 7 | **Engine-side profiler tap** — export per-frame subsystem timing (path ms, LOS ms, sim ms, group count) via `callExtension` / namespace var | Our "no profiler" gap. Read-only. **Keystone — enables + verifies everything else** | ★★★ | Very low | Claude |
| 8 | **Path cache / memoization at hot nodes** — cache path segments through chokepoints instead of recomputing per unit | Double-duty: perf win (no N recomputes) **and** behavior win (consistent routing, fewer wedges) at bridges | ★★ | Med | Claude |
| 9 | **Cooperative AI time-slicing** — round-robin/budget-cap AI updates per frame to smooth frame spikes | The single-thread wall, framed as *smoothing* (trade update latency for steady frametime) rather than throttling | ★★ | Med | Claude |

### Recommended sequencing

1. **#7 profiler tap** — lowest risk, keystone, fixes the measurement gap. Proves the patch workflow
   (find routine → patch → test-instance verify → measure) on a read-only target.
2. **#1 plane altitude floor** — smallest high-confidence behavior patch, hits Ray's stated #1 interest
   ("aircraft don't crash"), visually verifiable in one soak.
3. **#3 aircraft separation** + **#5 per-AI throttles** — clean constant tweaks once #7 makes them measurable.
4. **#8 path cache** / **#4 path cost** — the real performance + behavior money, highest risk, only after
   #7 profiling has confirmed pathfinding is the dominant cost and given a baseline to measure against.
5. **#6 new script commands** — advanced; do once the patch toolchain is mature.

---

## Non-starters (honest — don't burn effort here)

- **Backporting 1.68/1.80 features** (plane `flyInHeight`, dynamic-airport landing without an `AirportBase`,
  `flyInHeightASL`). These are *new code not present in the 1.64 binary*, not disabled flags. You'd re-implement
  them from scratch. Keep the scripted **fly-off-map + refund** for jets — it's the correct pragmatic answer.
- **Multithreading the sim.** Architecturally impossible via patch; the data structures aren't thread-safe.
  Item #5/#9 (throttle / time-slice per-AI cost) is the only engine-side FPS path.
- **AI perception/skill tuning via patch.** Redundant — **ASR AI already does this** via `CfgAISkill`/danger.fsm
  config (`asr_ai_settings.hpp`). Don't patch what a config mod we already ship covers.
- **Heli autorotation, plane weave-fix** (§3.3/§3.5) — deep flight-model rewrites, tiny payoff.

---

## Open questions (owner clearance)

1. **Item #5/#9 vs. the rejected sim-gating.** The owner killed *script-side* sim gating
   (`WFBE_C_SIM_GATING` — "never wire it"). An engine-side per-AI throttle / time-slice is a *different
   mechanism* but the same smell (trade AI fidelity for FPS). Clear before building — it may be a non-starter
   on principle, or acceptable precisely because it never reduces GUER volume.
2. **GUER volume invariant.** All perf items must make each AI *cheaper*, never *fewer* — "GUER volume is the
   point; no caps or nerfs." Time-slicing/throttling must preserve count and only touch per-unit update cost.

---

## Tooling note

Candidate workflow tool: `banteg/bn` (`bn-cli`) — a CLI bridge for Binary Ninja aimed at coding agents
(query disassembly/decompiled code, xrefs, types; reversible mutations with preview/verify; structured JSON
output). Useful for driving the RE side of this project without a headless license. Evaluated 2026-07-14; not
yet adopted.

## Source anchors

- Engine walls: `docs/design/AI-MODS-AND-PATHFINDING.md` Part B §3.
- HC-locality of AICOM teams: `Common/Functions/Common_RunCommanderTeam.sqf:178-181`.
- Fixed-wing air-start with no altitude floor: `Server/AI/Commander/AI_Commander_Teams.sqf:1039-1079`.
- Heli terrain guard (server-local band-aid, HC copy owed): `Server/server_heli_terrain_guard.sqf`.
- Stuck-recovery apparatus this project could retire at the root: `docs/design/STUCK-RECOVERY-V2-REFERENCE.md`.
