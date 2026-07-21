# COMMAND V2 — Player + AICOM Nudge System (design)
<!-- GUIDE-REV: GR-2026-07-08a -->

Status: **BUILT** — the runtime implementation landed 2026-07-19; see the AS-BUILT addendum in
section 13, which also closes every open decision in section 12. Sections 0-12 are preserved as
reviewed and were not rewritten.

Originally: *design-only, review-gated. No mission SQF, mirror, packaging, or live-server change is
made by this note.* It is the P4 design deliverable of the approved 4-phase WF-menu overhaul; the
runtime build is a separate PR that must not start until this design is reviewed and approved.

Owner ask (2026-07-17): players **and** the AI commander can *nudge* AI teams —
(a) **town nudges** (suggest/prioritize a target town for a team or the side, feeding AICOM target
weighting, **not** hard orders — the AI commander stays the commander); (b) **doctrine nudges**
(per-team or side posture: aggressive push / defensive hold / garrison); (c) **request-as-support**
(a player requests an AI team attached to them as support — **helicopters first** (transport / CAS
escort responding to the requesting player's position), jets later; design the request type now,
implement heli only).

Source anchors below are line numbers on `origin/master` @ `80c690257f` (Chernarus is the reference
path). If a later PR moves code, update the anchors together with the wording.

---

## 0. TL;DR — this is an extension, not a greenfield build

**A player+AICOM nudge system already ships on `master`** behind `WFBE_C_CMD_MENU_V2` (default `1`,
`Init_CommonConstants.sqf:1109`). Most of the owner's three pillars exist in some form today. The P4
work is a **targeted refinement of the town pillar, an extension of the doctrine pillar, and one
genuinely new build (heli support-as-escort)** — all layered on the existing `RequestSpecial` bus and
the AICOM v2 allocator, each behind a new default-`0` flag.

| Owner pillar | What exists today | P4 delta |
|---|---|---|
| (a) Town nudge | `aicom-focus` **hard** override + `aicom-defend` relief (commander-gated), `Server_HandleSpecial.sqf:434,473`; consumed as fist-primary in `AI_Commander_Allocate.sqf:146-154` | Add a **soft, weighted** town-suggestion (any player / team-scoped or side-scoped) that biases the scorer instead of overriding it |
| (b) Doctrine nudge | Side posture `aicom-posture` PUSH/HOLD (engage-gate bias) + `aicom-fieldorder` SPLIT/MASS/HARASS/FALLBACK, `Server_HandleSpecial.sqf:571,612`; per-team `wfbe_teammode "defense"`; AI-rolled temperament/doctrine (default off) | Add a **garrison** stance and a **per-team doctrine** nudge on top of the existing posture stamps |
| (c) Request as support | `aicom-support` / `CMD_NUDGE` moves the nearest idle **ground** team to the player one-shot, then releases it, `Server_HandleSpecial.sqf:912-971` | Add an **air** support request type (**heli only** now, jets later) with a real grant → attach → follow/CAS → release/timeout/recall **lifecycle** |

The single most important design constraint follows directly from the owner rule *"the AI commander
stays the commander"*: **nudges are weighted, TTL'd, cooldowned advisory inputs — they never
manual-pin a team or hard-steal it from the allocator** (unless issued by a seated human commander,
who already has hard verbs today). The existing `aicom-posture` code states this intent verbatim:
*"applies a SMALL bias only — it never hard-overrides the stance machine"* (`Server_HandleSpecial.sqf:574`).

---

## 1. Dependency & coordination

- **Depends on `wasp-command-menu-crash-fix-20260717` landing first.** That fix touches the command
  menu / `GUI_Menu_Command.sqf` surface this design also edits. The runtime PR **stacks on the
  crash-fix's merged HEAD** (or, if still in flight, bases on its branch HEAD and declares
  "stacked on #NNN" per the repo claim protocol). Do **not** fork or duplicate its queue.
- The nudge master flag `WFBE_C_CMD_MENU_V2` is already `1`; **new P4 mechanics get their own
  default-`0` flags** so this design ships inert and the crash-fix's stability work is never gated
  behind unfinished nudge features.

---

## 2. The existing plumbing this design builds on

### 2.1 Client → server transport (the `RequestSpecial` bus)

All command-console verbs are sent with one idiom (`GUI_Menu_Command.sqf:289` is the canonical example):

```sqf
["RequestSpecial", ["aicom-support", sideJoined, player, getPos player]] Call WFBE_CO_FNC_SendToServer;
```

`WFBE_CO_FNC_SendToServer` (`Common/Init/Init_Common.sqf:182` → `Common_SendToServer.sqf` /
`Common_SendToServerOptimized.sqf`) rewrites `_this select 0` to `"SRVFNCRequestSpecial"`, stuffs the
array into `WFBE_PVF_RequestSpecial`, and `publicVariable`s it (or spawns `WFBE_SE_FNC_HandlePVF`
directly if the caller is the hosted server).

**PVF allowlist (the "HC PVF allowlist" the claim rules warn about).** The accepted top-level PV
names are the `_serverCommandPV` list in `Common/Init/Init_PublicVariables.sqf:9-35` (includes
`"RequestSpecial"` at `:23`), compiled into `WFBE_SE_PVF_ALLOWED` and registered as PVEHs at
`:85-89`. The gate is `Server/Functions/Server_HandlePVF.sqf:14-16`:

```sqf
if (isNil "WFBE_SE_PVF_ALLOWED" || {!(_script in WFBE_SE_PVF_ALLOWED)}) exitWith {
    ["WARNING", Format ["Server_HandlePVF.sqf: rejected unregistered PVF handler [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};
```

This list is shared by the dedicated server **and** the headless client (both run
`Init_PublicVariables.sqf`), so the same gate applies on the HC.

> **PVF-discipline ruling for this design:** every new nudge verb (`aicom-town-nudge`,
> `aicom-team-doctrine`, `aicom-support-air`) is a **sub-verb of the already-allowlisted
> `RequestSpecial` bus** — a new `case` in the `Server_HandleSpecial.sqf` switch, **not** a new
> top-level PV name. So **no `_serverCommandPV` / `WFBE_SE_PVF_ALLOWED` edit is required.** The
> completeness audit the memory demands is therefore *"does each new `case` re-validate side, issuer
> identity, seated-commander state, per-UID cooldown, and payload shape exactly like the existing
> cases?"* — see the validation checklist in §7. A new verb that skips any of those is the exact
> "dead guard / unenforced request" failure the memory flags.

`Server/PVFunctions/RequestSpecial.sqf:19` validates payload shape then `Spawn HandleSpecial`, landing
in the giant `switch` in `Server/Functions/Server_HandleSpecial.sqf` keyed on `_args select 0`
(e.g. `case "aicom-focus":` `:434`, `case "aicom-support":` `:912`).

### 2.2 The nudge data model that already exists (generalize, don't reinvent)

Every current nudge is a **stamped tuple with a timestamp, consumed under a TTL, gated by a per-UID
cooldown**. This *is* the data model; P4 unifies it rather than inventing a new one.

| Stamp (side logic object) | Shape | Set by | Consumed by | TTL / cooldown |
|---|---|---|---|---|
| `wfbe_aicom_player_posture` | `[ "PUSH"\|"HOLD", t0 ]` | `Server_HandleSpecial.sqf:571-611` | `Allocate.sqf:87-95` (±`POSTURE_ENGAGE_DELTA` on `_engageMin`) | `WFBE_C_AICOM_POSTURE_TTL`=300 / `CMD_VERB_COOLDOWN`=60 |
| `wfbe_aicom_player_fieldorder` | `[ "SPLIT"\|"MASS"\|"HARASS"\|"FALLBACK", t0 ]` | `:612-653` | `Allocate.sqf:99-107,250-253,308-327` (reshapes `_fistMax`/`_expandN`/`_harassN`/`_concentrate`) | 300 / 60 |
| `wfbe_aicom_focus` | town object (hard) | `:434-472` | `Allocate.sqf:146-154` (overrides fist primary) | `TEAM_FOCUS_COOLDOWN`=120 |
| `wfbe_aicom_manualpin` (per team) | `time` | console orders | `AssignTowns.sqf:200-201` (skip auto-retask) | `MANUALPIN_TTL`=600 |

**Proposed unified nudge record** (a superset, so the three P4 verbs share one shape and one
expiry/cooldown code path):

```
wfbe_aicom_nudge = [type, scope, target, issuerUID, priority, t0]
    type      : "town" | "doctrine" | "support"
    scope     : "side" | team-group | player-object
    target    : town-object (town nudge) | stance-string (doctrine) | position (support)
    issuerUID : getPlayerUID player   (cooldown + anti-abuse key)
    priority  : 0..1 weight (commander-issued = 1.0 hard; player-issued = soft)
    t0        : time stamp; record is live while (time - t0) < TTL
```

Nudges live in a small per-side ring (bounded array, oldest-evicted) so multiple players' town
suggestions can be **aggregated** (vote-weighted) rather than last-writer-wins.

### 2.3 How the AI commander turns targets into team orders

- **Two town scorers** write `wfbe_aicom_targets`; the **v2 "fist" scorer is authoritative** when
  `WFBE_C_AICOM2_ALLOCATE_ENABLE > 0` (runs after Strategy, its write wins). Fist score,
  `AI_Commander_Allocate.sqf:208-248`:

  ```sqf
  _sc = (_tt getVariable ["supplyValue", 0]) - (_dNear / _distDiv);
  if (_garPen  > 0) then {_sc = _sc - (_garTier * _garPen)};
  if (_dNear   > _frontRad) then {_sc = _sc - _farPen};
  if (_nearBand> 0 && {_dNear < _nearBandDist}) then {_sc = _sc + _nearBandBonus};
  if (_supportOn) then {_sc = _sc - ((_tt distance _supportCen) / _supDiv)};
  if (_grudgeBonus > 0 && {_tt in _grudgeTowns}) then {_sc = _sc + _grudgeBonus};
  ```

  The fist precedence chain (`:142-259`): `wfbe_aicom_focus` (hard) → `_supportOn` (pull toward the
  centroid of players on the side) → AUTO scorer picking `WFBE_C_AICOM2_FIST_TOWNS` (default 1).
  Expansion-first gate (`:77,111-131`): below `WFBE_C_AICOM_ENGAGE_MIN_TOWNS` (default 10) owned
  towns, only neutral/soft towns are candidates.

- **Team tasking:** `AssignTowns.sqf` reads each team's `wfbe_aicom_alloc_target` (v2 fist assignment,
  `Allocate.sqf:534`) and issues orders through the three broadcast setters —
  `Common_SetTeamMoveMode.sqf:8` (`wfbe_teammode`), `Common_SetTeamMovePos.sqf:8` (`wfbe_teamgoto`),
  `Common_SetTeamAutonomous.sqf:8` (`wfbe_autonomous`). `AI_Commander_Execute.sqf:29-120` turns those
  vars into real waypoints each tick (server-local `AIMoveTo` / road-node chains, or the HC order
  tuple `wfbe_aicom_order = [seq, mode, pos]` at `:96`, consumed by
  `Common_RunCommanderTeam.sqf`).

- **Per-team mode vocabulary** (`wfbe_teammode`): `"towns"` (auto-offense) / `"move"` / `"patrol"` /
  `"defense"` / `""`, mapped to waypoint MOVE/SAD/HOLD in `Execute.sqf:102-104`.

### 2.4 Airmobile substrate for heli support (already live)

- Air teams gated by held **Aircraft Factory** heli-waive (`AI_Commander_Teams.sqf:300-346`); jet vs
  generic-air detection + airfield relocation `:1220-1250`.
- Retained transports fly later legs (`Common_RunCommanderTeam.sqf:657-681`, `AIR_RETAIN`); airmobile
  legs / hot-LZ paradrop / vehicle sling in `Common_AICOMAirLeg.sqf`; retained transport returns to a
  live HQ / owned-town fallback and clears its airborne exemption in `Common_AICOMAirReturn.sqf`.
- **Gap:** there is **no player-attach / sustained-escort** mechanism today. `aicom-support` is a
  one-shot move-to-position; `doFollow` is used only for internal AI-to-AI cohesion
  (`Common_SML*.sqf`, `Common_RunCommanderTeam.sqf:1264,1296`) and the stuck-teammate watchdog
  (`Client_RecoverPlayerAI.sqf:885`). The heli support-escort loop in §5 is the new build.

---

## 3. Pillar (a) — Town nudge (soft, weighted)

**Goal:** any player can *suggest* a target town for the side, or a team leader can bias a specific
team, and the AI commander folds that suggestion into its scoring **without being overridden**.
Contrast the existing commander-only `aicom-focus`, which hard-forces the fist primary.

**New verb `aicom-town-nudge`** (a `case` in `Server_HandleSpecial.sqf`):

- Payload `[ "aicom-town-nudge", side, townObject, player, scopeString ]` where `scope ∈ {"side","team"}`.
- Server validates: sender is a live player on `side`; town is a real registered town and enemy/neutral
  (you cannot "nudge" a town you already own into the offensive fist); per-UID cooldown
  `WFBE_C_CMD_TOWN_NUDGE_COOLDOWN`; caps in §6.
- Effect: appends/refreshes a unified nudge record (§2.2) into `wfbe_aicom_town_nudges`
  (bounded ring). It does **not** touch `wfbe_aicom_focus`.

**Consumption** — one added term in the fist scorer (`Allocate.sqf:208-248`), gated by the new flag:

```sqf
// pseudo-delta, default-0 gated
if (WFBE_C_CMD_TOWN_NUDGE > 0) then {
    _nb = _tt Call WFBE_CO_FNC_TownNudgeWeight;   // aggregated, TTL-decayed vote weight for this town
    _sc = _sc + (_nb * WFBE_C_CMD_TOWN_NUDGE_WEIGHT);
};
```

- **Aggregation / vote-decay:** `WFBE_CO_FNC_TownNudgeWeight` sums the live (non-expired) nudge records
  for the town, but with **diminishing returns** (e.g. `sqrt(n)` or a hard `WFBE_C_CMD_TOWN_NUDGE_CAP`)
  so five players spamming one town cannot dwarf the supply/distance terms. Weight decays linearly to
  0 across `WFBE_C_CMD_TOWN_NUDGE_TTL`. This keeps the nudge a *thumb on the scale*, not a command.
- **Side scope** biases the whole fist scorer as above. **Team scope** additionally biases only the
  matching team's `wfbe_aicom_alloc_target` pick (a smaller, team-local bonus), so a squad's request
  can pull *their* attached AI team without redirecting the entire side.
- **Sizing guidance (owner-tunable):** `WFBE_C_CMD_TOWN_NUDGE_WEIGHT` should be smaller than
  `WFBE_C_AICOM_GRUDGE_BONUS` (400) and comparable to a one-tier `supplyValue` swing, so a nudge can
  break a near-tie between two candidate towns but cannot force a strategically bad target. Final value
  is an owner tuning decision after a soak.

**Legacy note:** the legacy scorer has a dead hook `wfbe_aicom_town_weight` (always 0,
`Strategy.sqf:229`). Do **not** revive it — the v2 fist scorer is authoritative and overwrites
`wfbe_aicom_targets`; wire the nudge into `Allocate.sqf` only.

---

## 4. Pillar (b) — Doctrine nudge (per-team + garrison)

**Goal:** aggressive push / defensive hold / **garrison**, at side or per-team scope. Push/Hold already
exist at side scope (`aicom-posture`). P4 adds the **garrison** stance and a **per-team** doctrine
nudge.

### 4.1 Side scope — add GARRISON to the existing posture verb

Extend `aicom-posture` (`Server_HandleSpecial.sqf:571-611`) to accept a third value `"GARRISON"`
alongside `PUSH`/`HOLD`. Consumption:

- `PUSH` / `HOLD` keep their current engage-gate bias (`Allocate.sqf:87-95`).
- `GARRISON` = HOLD's engage-gate bias **plus** enabling the town-garrison sortie loop for the side
  (reuse the already-designed `WFBE_C_GARRISON_SORTIE` family from
  `docs/design/GARRISON-SORTIE-PATROL-DESIGN.md`: short-lived 4-man patrols around owned active towns,
  player-range gated, hard active-cap). Garrison is a *posture flavour*, not a new team engine.

### 4.2 Per-team scope — new verb `aicom-team-doctrine`

- Payload `[ "aicom-team-doctrine", side, teamIndex, stanceString, player ]`,
  `stance ∈ {"aggressive","defensive","garrison"}`.
- Who: a **human commander** for any team (hard, may manual-pin); a **team leader / any player** as a
  *soft, TTL'd* nudge for a nearby AI team only (§6 rules) — never manual-pinned, so the allocator can
  still retask it.
- Stamp `wfbe_aicom_team_doctrine = [stance, t0]` on the team group, consumed in
  `AssignTowns.sqf` / `Execute.sqf`:
  - `aggressive` → prefer the offensive `"towns"` mode and a forward `wfbe_aicom_alloc_target`
    (small per-team bias, like §3 team scope).
  - `defensive` → `wfbe_teammode "defense"` on the nearest owned town center.
  - `garrison` → `defense` + tie the team to the town-garrison patrol loop (§4.1).
- Under a soft (non-commander) nudge the stamp is advisory: if the allocator has a higher-priority
  need (relief, last-stand, HQ-strike commit) it still wins — again *the AI stays the commander*.

**Precedent reused:** the AI already has side strategic mode `wfbe_aicom_strat_mode`
(`"spearhead"`/`"laststand"`, `Strategy.sqf:87-91`) and per-team `wfbe_teammode`. Doctrine nudges feed
those existing machines rather than adding a parallel state machine.

---

## 5. Pillar (c) — Request AI team as support (heli first; request type designed for jets)

**Goal:** a player requests an AI team **attached to them as support** — helicopters first (transport
insertion / CAS escort that responds to the *requesting player's position*), jets later. **Design the
request type now; implement heli only.**

Today's `aicom-support` (`Server_HandleSpecial.sqf:912-971`) only moves the nearest idle **ground** team
to the player once and releases it. P4 adds a **typed, lifecycle-managed air support request**.

### 5.1 Request type (forward-compatible for jets)

**New verb `aicom-support-air`**, payload
`[ "aicom-support-air", side, player, getPos player, kindString ]`:

- `kind ∈ {"transport","cas-heli"}` implemented now.
- `kind ∈ {"cas-jet","transport-jet"}` **defined but rejected** behind
  `WFBE_C_CMD_SUPPORT_JET` (default `0`) — the request type ships now, the jet grant path is a later
  build. Rejection emits a clear `CMD_SUPPORT|REJECT|jet-disabled` telemetry line so the UI can grey
  the option rather than silently drop it.

### 5.2 Lifecycle (the new state machine)

```
REQUESTED ──grant?──► GRANTED ──► ACTIVE (follow / CAS loop)
    │ no heli avail        │            │
    └──► NONE              │            ├── player RELEASE ─► RETURN
 (cooldown starts,         │            ├── TTL TIMEOUT ────► RETURN
  optional fee refund)     │            └── AICOM RECALL ───► RETURN
                           └── validate: air tier / Aircraft Factory / cap
```

1. **REQUESTED → GRANTED / NONE.** Server searches side AI air teams eligible for the `kind`
   (transport heli, or armed heli for `cas-heli`), gated by held Aircraft Factory / air-tier
   (`Teams.sqf:300-346`) and the concurrency caps in §6. If none available → `NONE` (telemetry
   `CMD_SUPPORT|NONE`), start the per-UID cooldown, refund any requisition fee (§6). If found → mark
   the team `wfbe_aicom_support_holder = [playerObject, kind, t0]` and enter GRANTED.
2. **GRANTED → ACTIVE.** The granted heli team flies to the player using the existing airmobile move
   primitives; on arrival it enters the escort loop.
3. **ACTIVE — sustained escort (the new behavior).** A bounded server/HC loop re-issues the team's
   goto to **track the player's current position** every `WFBE_C_CMD_SUPPORT_FOLLOW_INT` (e.g. 20 s),
   using `SetTeamMovePos` + `SetTeamMoveMode` — for `transport` a standoff orbit / LZ near the player;
   for `cas-heli` a SAD/attack behavior against threats near the player. The team is **left autonomous
   between re-issues** and is **not manual-pinned**, so if it is destroyed or the loop ends the
   allocator reclaims it cleanly. This is deliberately a *periodic re-issue* rather than engine
   `doFollow` on a player object (safer on A2 OA — no per-frame attach, survives player disconnect).
4. **RETURN.** On RELEASE (player button), TIMEOUT (`WFBE_C_CMD_SUPPORT_TTL`), or RECALL (AICOM needs
   the airframe for a higher-priority sortie — e.g. last-stand), clear `wfbe_aicom_support_holder`,
   stop the loop, and hand the team back to autonomy via the existing
   `Common_AICOMAirReturn.sqf` return-to-HQ path. Emit `CMD_SUPPORT|RELEASE|<reason>`.

### 5.3 Refund question (owner decision)

Two defensible models — **recommend model A**, owner picks:

- **A. Free nudge (recommended, matches existing `aicom-support`).** No player funds spent; the AI
  commander "lends" an already-owned airframe. Anti-abuse is purely cooldown + concurrency caps (§6).
  No refund concept needed. Simplest, and consistent with the fact that the existing ground
  `aicom-support` is free.
- **B. Small requisition fee** from the *side/AI* budget (not the player's personal funds) charged on
  GRANT, **refunded on NONE / immediate RECALL** so a request the AI can't honour costs nothing. Adds
  an economy sink that discourages frivolous requests but couples support to AICOM funds and needs its
  own refund audit (cf. the heli-refund-authority work in flight, PR #1090). Heavier; only if the
  owner wants support to feel "paid for."

Owner ruling requested. The design assumes **A** unless told otherwise; switching to B is a localized
change (charge on GRANT, refund on the NONE/RECALL branches).

---

## 6. Who may issue what (proposed — owner rules)

| Verb | Any live player | Player team leader | Human commander | Notes |
|---|---|---|---|---|
| `aicom-town-nudge` (soft) | ✅ side-scope suggest | ✅ team-scope for a nearby AI team | ✅ (or uses hard `aicom-focus`) | soft/weighted, never pins |
| `aicom-posture` incl. GARRISON | ✅ side posture | ✅ | ✅ | existing PUSH/HOLD + new GARRISON |
| `aicom-team-doctrine` | ✅ soft, nearby AI team only | ✅ soft | ✅ hard (may pin) | per-team stance |
| `aicom-support-air` (heli) | ✅ to self | ✅ | ✅ | lifecycle-managed |
| `aicom-focus` / `aicom-defend` (hard) | ❌ | ❌ | ✅ existing | unchanged, commander-only |
| Direct move/defend/patrol/rally/refit/hold | ❌ | ❌ | ✅ existing STATE B | unchanged |

Guiding rule: **non-commanders only ever get soft, TTL'd, cooldowned, capped nudges; hard team control
stays with the seated human commander (or, absent one, the AI).** "Nearby AI team only" = within
`WFBE_C_CMD_NUDGE_RANGE` (1500 m), reusing the existing support-range gate.

---

## 7. Anti-abuse, caps, and the validation checklist

**Anti-abuse (reuse the existing per-UID cooldown pattern, `Server_HandleSpecial.sqf:921,930,935`):**

- Per-UID cooldown per verb: `WFBE_C_CMD_TOWN_NUDGE_COOLDOWN`, `WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN`,
  `WFBE_C_CMD_SUPPORT_AIR_COOLDOWN` (default to the existing 60–180 s band).
- Concurrency caps: `WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE` (side-wide granted heli teams, small — protects
  the AICOM fist/economy) and one active support team per player UID.
- Town-nudge vote-decay + `WFBE_C_CMD_TOWN_NUDGE_CAP` so a town's aggregated bonus is bounded.
- TTL auto-expiry on every stamp; no nudge persists past its window.

**Per-`case` completeness audit (the memory's "dead guard" rule) — every new verb MUST:**

1. Confirm the sender is a live player on the claimed `side` (`isPlayer` + `side` check).
2. Key its cooldown and caps on `getPlayerUID player`, not on the object.
3. Respect the seated-commander split: a soft nudge must **not** manual-pin or override a
   commander/allocator hard order.
4. Validate payload shape/type before use (town is a town, team index in range, position is a
   position) — mirror `RequestSpecial.sqf:19` and the existing cases.
5. Emit an accept **and** a reject/none telemetry line (see §8) — no silent drops.
6. Be gated by its default-`0` flag so the whole verb is inert until enabled.

---

## 8. Telemetry (extends the existing `AICOM2|v1|ORDER|…` trail)

Reuse the command-console intake prefix used by `aicom-focus`/`CMD_NUDGE`
(`Allocate.sqf`, `Server_HandleSpecial.sqf:466,962`). New tokens:

- `AICOM2|v1|ORDER|TOWN_NUDGE|<accept|reject|cooldown>` (+ town, scope, aggregated weight).
- `AICOM2|v1|ORDER|TEAM_DOCTRINE|<stance>|<accept|reject>` (+ team idx).
- `AICOM2|v1|ORDER|CMD_SUPPORT|<REQUEST|GRANT|NONE|RELEASE|RECALL|REJECT>` (+ kind, holder UID, reason).

Per the repo's log-content rule: one always-on `INFORMATION`/`WARNING` line per state transition
(request granted / released / rejected) so the path is provable in the HC RPT; gate verbose
per-tick escort-loop value dumps behind `WF_LOG_CONTENT`.

---

## 9. UI surface (Command dialog, MenuAction bus)

Reworks **STATE A (non-commander advisory)** of `GUI_Menu_Command.sqf` (idd 14000). STATE A uses the
`MenuAction` namespace (**not** `WFBE_MenuAction` — do not conflate; existing STATE A ints are
750/760-767, STATE B are 710-746). New controls slot into free ints:

| New control | State | Proposed MenuAction | Send |
|---|---|---|---|
| "SUGGEST TOWN (side)" — arm, then map-click nearest town (reuse idc 14002 `posScreenToWorld`) | A | 768 | `aicom-town-nudge … "side"` |
| "SUGGEST TOWN (my team)" | A | 769 | `aicom-town-nudge … "team"` |
| Posture: add GARRISON button next to PUSH/HOLD | A | 762-was-free-range | `aicom-posture … "GARRISON"` |
| "REQUEST HELI SUPPORT" (transport / CAS toggle) | A | 770/771 | `aicom-support-air … kind` |
| Per-team doctrine picker (aggressive/defensive/garrison) on the roster row | A/B | 772-774 | `aicom-team-doctrine …` |

- Exact free ints are picked against the **crash-fix's** final `GUI_Menu_Command.sqf` (this stacks on
  it) to avoid collisions — the runtime PR re-reads the file before assigning.
- Follow the existing map-click arm pattern (`_armed` + `mouseX/mouseY` seeded to 0.5,
  `GUI_Menu_Command.sqf:38-44,263`) for the "suggest town" click.
- Show request/nudge feedback with the existing hint/`CMD_NUDGE` client-side confirmation idiom;
  greyed jet option until `WFBE_C_CMD_SUPPORT_JET`.
- Keep the MenuAction 0.1 s poll loop; no new namespace, no event-handler migration (that is the
  separate remake concern in the UI index, out of scope here).

---

## 10. Flag plan (all new mechanics default `0`, truthful comments)

Append to `Common/Init/Init_CommonConstants.sqf` **only** (never change existing defaults), following
the `if (isNil …) then {…}; //---` format and the existing nudge block at `:1109-1113`. Reads use
`missionNamespace getVariable ["WFBE_C_…", <same default>]` so an undefined flag degrades to the inert
default rather than throwing.

```sqf
// --- COMMAND V2 nudge extensions (P4). All default 0 = byte-identical to HEAD when off. ---
if (isNil "WFBE_C_CMD_TOWN_NUDGE")            then {WFBE_C_CMD_TOWN_NUDGE = 0};             //--- soft weighted town suggestion (any player). 0 = verb rejected, scorer untouched.
if (isNil "WFBE_C_CMD_TOWN_NUDGE_WEIGHT")     then {WFBE_C_CMD_TOWN_NUDGE_WEIGHT = 120};   //--- scorer bonus per aggregated nudge unit; owner-tuned < GRUDGE_BONUS(400). Inert while _TOWN_NUDGE=0.
if (isNil "WFBE_C_CMD_TOWN_NUDGE_CAP")        then {WFBE_C_CMD_TOWN_NUDGE_CAP = 3};        //--- max aggregated nudge units counted per town (vote-decay bound).
if (isNil "WFBE_C_CMD_TOWN_NUDGE_TTL")        then {WFBE_C_CMD_TOWN_NUDGE_TTL = 240};      //--- s a town nudge stays live before it decays to 0.
if (isNil "WFBE_C_CMD_TOWN_NUDGE_COOLDOWN")   then {WFBE_C_CMD_TOWN_NUDGE_COOLDOWN = 90};  //--- s per-UID cooldown between town nudges.
if (isNil "WFBE_C_CMD_TEAM_DOCTRINE")         then {WFBE_C_CMD_TEAM_DOCTRINE = 0};         //--- per-team aggressive/defensive/garrison nudge. 0 = verb rejected.
if (isNil "WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN")then {WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN = 90}; //--- s per-UID cooldown for team-doctrine nudges.
if (isNil "WFBE_C_CMD_SUPPORT_AIR")           then {WFBE_C_CMD_SUPPORT_AIR = 0};           //--- heli support request (transport/cas-heli) + escort lifecycle. 0 = verb rejected.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_TTL")       then {WFBE_C_CMD_SUPPORT_AIR_TTL = 300};     //--- s max escort duration before auto-return.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_RANGE")     then {WFBE_C_CMD_SUPPORT_AIR_RANGE = 1500};  //--- m follow/standoff band around the requesting player.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_FOLLOW_INT")then {WFBE_C_CMD_SUPPORT_AIR_FOLLOW_INT = 20}; //--- s escort re-issue interval (track player position).
if (isNil "WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE")then {WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE = 1}; //--- side-wide cap on concurrently granted heli support teams.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_COOLDOWN")  then {WFBE_C_CMD_SUPPORT_AIR_COOLDOWN = 180}; //--- s per-UID cooldown between heli support requests.
if (isNil "WFBE_C_CMD_SUPPORT_JET")           then {WFBE_C_CMD_SUPPORT_JET = 0};           //--- reserved: jet CAS/transport support. 0 = jet kinds rejected (heli-only build).
```

Garrison stance reuses the `WFBE_C_GARRISON_SORTIE*` family from
`docs/design/GARRISON-SORTIE-PATROL-DESIGN.md` (also default `0`) rather than defining a parallel
garrison engine.

> Truthful-comment note (the flag-debt card culture, PR #1130): each comment states exactly what the
> flag gates and that `0` is genuinely inert. There is **no** hidden coupling to `WFBE_C_CMD_MENU_V2`
> — the new buttons render only when both `CMD_MENU_V2>0` **and** the specific feature flag is on.

---

## 11. Build sequencing (after design review approval)

The runtime work splits into independently flag-gated, independently reviewable PRs so no single PR is
huge and each ships inert:

1. **PR-1 Town nudge** — `aicom-town-nudge` case + `WFBE_CO_FNC_TownNudgeWeight` + one scorer term +
   STATE A buttons. Flag `WFBE_C_CMD_TOWN_NUDGE`.
2. **PR-2 Doctrine nudge** — GARRISON on `aicom-posture` + `aicom-team-doctrine` case + consumers +
   UI. Flags `WFBE_C_CMD_TEAM_DOCTRINE` (+ reuse `WFBE_C_GARRISON_SORTIE`).
3. **PR-3 Heli support** — `aicom-support-air` case + grant/escort/return lifecycle + UI. Flag
   `WFBE_C_CMD_SUPPORT_AIR`. Largest; carries the new escort loop and the return-to-HQ integration.

Each PR: stacks on the crash-fix HEAD, `default 0`, byte-identical flag-off, mirrors regenerated,
lint + bracket gates, per-`case` validation checklist (§7), draft PR only. Jets are a **later** PR
behind `WFBE_C_CMD_SUPPORT_JET`, out of P4 scope.

---

## 12. Open owner decisions

1. **Support economy:** free nudge (model A, recommended) vs requisition fee refunded on NONE
   (model B). §5.3.
2. **Town-nudge weight** (`WFBE_C_CMD_TOWN_NUDGE_WEIGHT`) final value + whether aggregation is
   `sqrt(n)` or hard-capped. §3.
3. **Who may per-team-doctrine-nudge:** any nearby player, or team leaders only? §6.
4. **CAS heli rules of engagement:** does `cas-heli` actively hunt threats near the player, or only
   escort/orbit and fire if fired upon? (Affects how aggressive the airframe is and its survivability.)
5. **Recall priority:** may the AI recall a granted support heli for last-stand/HQ-strike, or is a
   granted request inviolable for its TTL? §5.2 assumes recall is allowed.

---

## 13. AS-BUILT addendum (implementation, 2026-07-19)

This section is appended by the **runtime build**. Sections 0-12 above are the original
design as reviewed; nothing in them was edited except the status line, so the review
history stays honest. Where the build deviates from the design, it is recorded here.

### 13.1 Owner decision packet, 2026-07-18 — section 12 is now CLOSED

All five open decisions were ruled on by the owner (recorded on the Fleet card
`wasp-command-v2-nudge-system-20260717`, note dated 2026-07-18T12:46:52Z):

| # | Section 12 question | Owner ruling | Where it is implemented |
|---|---|---|---|
| 1 | Support economy: free vs requisition fee | **FREE.** Loan an already-owned AICOM airframe; no fee, no refund path. Keep cooldown/caps/telemetry. | `Server_HandleSpecial.sqf` `aicom-support-air`; no funds call exists anywhere in the path (test-locked). |
| 2 | Town-nudge weight + `sqrt(n)` vs hard cap | **BOTH.** `sqrt(n)` diminishing returns **and** a hard safety ceiling. Start ~120 and soak-tune. | `Common_TownNudgeWeight.sqf`: clamp to `WFBE_C_CMD_TOWN_NUDGE_CAP` **then** `sqrt`. |
| 3 | Who may per-team-doctrine-nudge | **NO leader-only gate.** Any *eligible nearby* player, with anti-spam/cooldown and receipts. | `aicom-team-doctrine`: eligibility is proximity (`WFBE_C_CMD_NUDGE_RANGE`) + per-UID cooldown + a `cmdv2-receipt` on every outcome. |
| 4 | CAS heli rules of engagement | **Fleet safe default:** escort/orbit + direct-threat response. Widen only from telemetry. | `Server_CmdSupportAir.sqf`: default mode is orbit-on-holder; SAD only when a hostile is inside `WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE` **of the holder**. |
| 5 | May AICOM recall a granted heli | **YES** for last-stand / HQ emergency, with reason telemetry and **hysteresis**. | `Server_CmdSupportAir.sqf`: continuous-dwell `_emergSince` gate + a post-recall re-grant block on the side logic. |

### 13.2 Deltas from the design

1. **`WFBE_C_CMD_SUPPORT_AIR_RANGE` re-scoped and retuned 1500 -> 6000.** Section 10 described
   it as both a request-time search radius and an escort band. Reusing the ground
   `WFBE_C_CMD_NUDGE_RANGE` value of 1500 m for an *air* asset would have made a grant almost
   impossible (helis stage at base). It is now purely a **max ferry distance**, and the actual
   ferry distance of every grant is logged so a tighter cap can be chosen from soak data.
2. **GARRISON ships as a posture *flavour* only.** Section 4.1 planned to reuse the
   `WFBE_C_GARRISON_SORTIE*` family from `GARRISON-SORTIE-PATROL-DESIGN.md`. That family **does
   not exist anywhere in this tree** (verified: zero matches). GARRISON therefore applies the
   HOLD engage-gate bias and nothing more, behind its own `WFBE_C_CMD_POSTURE_GARRISON` flag,
   and the code comment says so explicitly. Wiring the sortie loop remains a separate card.
3. **A fourth verb, `aicom-support-air-release`, was added.** Section 5.2 lists RELEASE as a
   lifecycle transition but never named the client -> server verb that triggers it. It only
   stamps a flag; the escort worker remains the single teardown site, so there is no race and
   no duplicated return path.
4. **Two flags not in section 10 were added**: `WFBE_C_CMD_TOWN_NUDGE_RING` (bounds the per-side
   nudge ring) and `WFBE_C_CMD_TEAM_DOCTRINE_TTL` (the design specified a TTL for the doctrine
   stamp but gave it no flag). Plus `WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE`, `_RECALL`, `_RECALL_HYST`
   and `_MIN_ALT`, which rulings 4 and 5 require.
5. **UI is partial and deliberately so.** Section 9 proposed seven STATE-A controls. STATE A had
   no vertical room left, so four went onto the bottom row (`y = 0.953825`), which is otherwise
   occupied only by the STATE-B disband pair and is therefore free whenever STATE A is shown:
   SUGGEST TOWN (side scope), CAS HELI, RELEASE HELI, TEAM DOCTRINE (nearest team, label toggles
   between ATTACK and DEFEND). **Not yet surfaced, though the backend is complete and callable:**
   team-scope town nudge, the `transport` heli kind, the GARRISON posture button, and the
   `garrison` doctrine stance. Those need the STATE-A layout rework tracked by
   `docs/design/v2/COMMAND-MENU-REBUILD-SPEC-2026-07-08.md`.
6. **MenuAction ints are 780-783, not the proposed 768-774.** 770-772 were historically SCUD/TEL
   and are only *recently* freed; 780+ has never been used by any dialog, so it cannot collide
   with the in-flight command-menu work in RC #1149. New idcs are 14631-14634 (inside the
   documented 14600-14699 band, in the gap the source itself marks free).

### 13.3 Consumption map (as built)

| Verb | Written to | Read by |
|---|---|---|
| `aicom-town-nudge` | `wfbe_aicom_town_nudges` ring on the side logic (server-local, no PV) | `AI_Commander_Allocate.sqf` — side scope adds one scorer term; team scope redirects that one team's `wfbe_aicom_alloc_target` |
| `aicom-team-doctrine` | `wfbe_aicom_team_doctrine = [stance, t0, uid]` on the group (broadcast) | stamped and telemetried this PR; the AssignTowns stance consumer is **not** wired yet — see 13.4 |
| `aicom-posture` GARRISON | `wfbe_aicom_player_posture` (existing stamp) | `AI_Commander_Allocate.sqf` engage-gate bias |
| `aicom-support-air` | `wfbe_aicom_support_holder` on the group + `wfbe_cmd_support_active` on the side logic | `WFBE_SE_FNC_CmdSupportAir` escort worker |
| `aicom-support-air-release` | `wfbe_aicom_support_release` on the group | the same escort worker, on its next interval |

### 13.4 Known gaps, stated plainly

- **The team-doctrine stamp is written but not yet consumed.** Section 4.2 specifies
  `aggressive` -> forward target bias, `defensive` -> `wfbe_teammode "defense"` on the nearest
  owned town, `garrison` -> defense plus the (non-existent) sortie loop. Wiring that into
  `AI_Commander_AssignTowns.sqf` touches the team-tasking hot path and deserves its own
  reviewed card rather than being tacked onto this one. Until then the verb validates, stamps,
  logs and receipts correctly, and the stance has no gameplay effect. The flag stays 0.
- **No runtime evidence.** Everything above is static validation only. See the soak packet at
  `docs/testing/COMMAND-V2-NUDGE-SOAK-PACKET.md` for the runtime plan that has **not** been run.
