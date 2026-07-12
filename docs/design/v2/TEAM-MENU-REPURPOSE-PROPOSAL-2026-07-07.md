# Team Menu Clean-Slate Repurpose — PROPOSAL

**V2 pack ref:** §8.3
**Status:** PROPOSAL ONLY — no implementation, no PR from this doc. Owner sign-off required before any build lane opens.
**Recon base:** `origin/claude/build84-cmdcon36` (`rayswaynl/a2waspwarfare`), read-only `git show`/`git grep`.
**Mission root (source of truth):** `Missions/[55-2hc]warfarev2_073v48co.chernarus/` (Takistan/Zargabad/modded mirrors are LoadoutManager-generated copies — not inspected further; see `loadout-manager-edit-generator-not-gamefiles` memory).

---

## 1. Executive summary

The Team Menu (WF-menu button → `MenuAction 3`) is **already mid-migration**, not untouched legacy. A prior effort (`TP-21`, see comment at `Rsc/Dialogs.hpp:1613-1618`) shipped **`RscMenu_TeamV2`** (`idd 13050`) as the default-on replacement for the old `RscMenu_Team` (V1), and TP-21 already **deleted** the view-distance slider, terrain-grid slider, and inline money-transfer controls from V2 — it did not relocate them, it cut them outright (money transfer has no replacement anywhere in the mission today; terrain grid has no replacement anywhere). View distance *does* have a real new home: `WFBE_SettingsMenu` (`idd 29000`).

What's left in the live V2 dialog is a **grab-bag of four unrelated feature groups**: personal gear-loadout presets, basic AI-squadmate management (disband/eject/repair), three leftover per-player display prefs, and an AI-unit-template designer for equipping bought infantry. None of it is genuine *team/squad coordination* — it's all single-player bookkeeping wearing a "Team" label.

Separately, and this is the load-bearing finding for this proposal: **two of the five candidate ideas the owner listed already exist, live, in a different menu.** `GUI_Menu_Command.sqf` (Command war-room, WF-menu `MenuAction 5`) already ships a rate-limited, intel-safe "nudge the AI" channel — Posture push/hold, Field-order split/mass/harass/fallback, and **AI Focus Town** (map-click → `aicom-focus`, exactly a "request-take-town" primitive) — open to *any* WEST/EAST player, not just the elected commander, whenever the commander seat is empty or locked. GUER has no equivalent (no HQ/commander architecture) but has its own paid town-investment channel, the Commissar Panel (`GUI_Menu_GuerCommissar.sqf`, idd 31000). Building a second "AI field-command hint" system into Team Menu would duplicate `GUI_Menu_Command.sqf`, not repurpose Team Menu into something new.

The genuinely empty gap — the thing nothing in the codebase does today — is **human-to-human coordination inside a squad/side**: no structured way to say "I'm playing medic," "I need ammo here," or "form up on me" that isn't either raw side-chat or a free-draw map marker. That gap, not AI-steering, is where Team Menu's real estate is best spent.

---

## 2. Current-contents inventory (verified, file:line)

### 2.1 Which dialog is actually live

`Client/GUI/GUI_Menu.sqf:110-117` (Team Menu button handler):
```
if (MenuAction == 3) exitWith {
    MenuAction = -1;
    closeDialog 0;
    if ((missionNamespace getVariable ["WFBE_C_TEAM_MENU_V2", 0]) > 0) then {
        createDialog "RscMenu_TeamV2";
    } else {
        createDialog "RscMenu_Team";
    };
};
```
`Common/Init/Init_CommonConstants.sqf:2246`: `if (isNil "WFBE_C_TEAM_MENU_V2") then {WFBE_C_TEAM_MENU_V2 = 1};` — **default ON**. `RscMenu_TeamV2` is what players see today; `RscMenu_Team` (V1) is a flag-gated fallback only.

The Team Menu button itself carries **no `ctrlEnable` gate** in `GUI_Menu.sqf`'s init or loop blocks (unlike Buy Units/Gear/Command/Upgrade/Economy, which are range- or role-gated) — it is unconditionally reachable by every player, every side, at all times. High-frequency real estate.

### 2.2 `RscMenu_TeamV2` (idd 13050) — live dialog, `Rsc/Dialogs.hpp:1619-2112`

| Section | Controls (IDC) | Backing logic |
|---|---|---|
| Header | Title, income readout `13010` | `GUI_Menu_TeamV2.sqf:11` |
| **Gear Presets** (4 slots) | Badge/Save/Apply/Rebuy per slot, `13051-13066` | `GUI_Menu_TeamV2.sqf` `MenuAction 1001-1004` (save), `1011-1014` (apply), `1021-1024` (rebuy-on-death) — personal loadout bookkeeping, reads/writes `WFBE_TM2_Presets` (profileNamespace-backed, per-player) |
| **Squad Actions** | Unit combo `13071`; Disband `13072`; Eject `13073`; Get Out & Repair `13074` | `GUI_Menu_TeamV2.sqf:466` (`MenuAction 3`, guarded `if !(isPlayer _x)` so it's a no-op on human squadmates), `:511` (`MenuAction 2001` Eject — **not** player-guarded, can eject a human teammate from a seat), `:532` (`MenuAction 2002` Get Out & Repair, intentionally free) |
| **Preferences** (carried over from V1) | FX/graphic-filter combo `13018`; High-climbing-default toggle `13020`; Vote-popup toggle `13019` | `MenuAction 6/14/13` respectively — pure per-player display prefs, no team scope |
| **Unit Designer** (flag-gated, default on) | Tab buttons `13080/13081`; 4 template slots `13100-13117` (name/save/activate/delete) | `WFBE_C_UNIT_DESIGNER` default 1 (`Init_CommonConstants.sqf:2430`); saves a loadout template auto-applied to *future AI infantry buys* — squad-leader tooling, not coordination |
| Footer | Back `8`, Exit (native close) | — |

Squad-selector combo (`GUI_Menu_TeamV2.sqf:39`, `_units = ((units group player) Call GetLiveUnits) - [player]`) lists **every** live group member except self — human squadmates included, not just AI, even though only AI-relevant actions (Disband) bother to guard against being pointed at a player.

### 2.3 What TP-21 already removed from V1 → V2 (per `Rsc/Dialogs.hpp:1613-1618` comment + verification below)

| Feature | V1 location | Verified fate |
|---|---|---|
| View-distance slider | `CA_VD_Label`/`CA_VD_Slider`, `Rsc/Dialogs.hpp:1423-1435` | **Actually relocated.** Live in `WFBE_SettingsMenu` (idd 29000, `Rsc/Dialogs.hpp:4386-4404`), opened from the WF-menu gear button, `MenuAction 24` (comment at `Rsc/Dialogs.hpp:1317-1322`, B748). |
| Terrain-grid slider | `CA_TG_Label`/`CA_TG_Slider`, `Rsc/Dialogs.hpp:1436-1448` | **Not relocated — simply deleted.** No `TerrainGrid`/`setTerrainGrid`/`_TG_` hits anywhere else in the Chernarus mission; only dead `stringtable.xml:2104-2105` keys remain. |
| Inline money transfer (slider/combo/button + "Transfer (Adv)") | `CA_TM_*`/`CA_TA_Button`, `Rsc/Dialogs.hpp:1450-1492` | **Not relocated — simply deleted.** `GUI_Menu_TeamV2.sqf` has no `MenuAction 1` or `101` handler (confirmed: only `3, 2001, 2002, 6, 13, 14, 1100, 1200, 8` are handled, `GUI_Menu_TeamV2.sqf:466-763`). `RscMenu_Economy` (idd 23000, `GUI_Menu_Economy.sqf`) has **no transfer control** either — grepped for `transfer`/`donate`/`fund` across the Economy dialog and script, zero hits. Only dead `stringtable.xml:2096-2100` keys remain (`STR_WF_TEAM_MoneyTransferLabel`, `STR_WF_TEAM_MoneyTransfer`). |

**Correction to the framing in the ask:** money transfer was *cut*, not *moved to Economy* — Economy never received it. If side-to-side/player-to-player fund transfer is still wanted, it needs a real home; this proposal does not assume it silently landed anywhere. Flagging this as a decision point for the owner, not assuming it's out of scope.

### 2.4 Overlooked residual duplication

The three "kept from V1" preference toggles (FX filter `13018`, high-climbing default `13020`, vote-popup `13019`) are exactly the same *category* of thing as the VD slider that TP-21 already agreed belongs in `WFBE_SettingsMenu` — per-player display/behavior prefs, no team scope, no per-session urgency. They were kept in V2 seemingly by inertia rather than deliberate design. Worth folding into the Settings-menu migration as part of any repurpose, tightening Team Menu to squad-relevant content only.

---

## 3. Design constraint: "no hidden-intel leak"

Grounded in what the codebase already treats as sensitive, so proposals below stay inside the existing envelope rather than inventing a new bar:

- **Side isolation is already enforced structurally.** `GUI_Menu_TeamV2.sqf:20`: `if (side group player != sideJoined) exitWith {closeDialog 0};` — any new controls must inherit this pattern; a coordination feature must never let a side-swap/JIP race expose a stale display for the wrong side.
- **The existing AI-steering channel already treats commander internals as private.** `GUI_Menu_Command.sqf`'s Posture/Field-order/Focus controls (`:194-260`) only ever show the *player's own sent nudge* back to them (`_lastIntent` readout) — never the AI's actual target list (`wfbe_aicom_targets`, `Server/AI/Commander/AI_Commander_AssignTowns.sqf` internals `_uncaptured`/`_target`), enemy composition, or scoring internals. Any Team Menu addition that touches the AI commander must follow the same one-way, opaque-nudge pattern — never surface raw commander state to players.
- **Practical reading of "no leak" for this proposal:** peer-coordination features (role tags, support pings, rally markers) are inherently side-local broadcasts of *intent the player already chose to share* — that's not a leak, it's the feature. The leak risk is specifically: (a) exposing AI/server-authoritative planning data, (b) any global (cross-side) broadcast, (c) automatic disclosure of something the player didn't explicitly opt to share (e.g., auto-broadcasting map position).

---

## 4. What already exists that a repurpose must not re-build

| Candidate idea from the ask | Existing coverage | Evidence |
|---|---|---|
| AI field-command hints | **Already shipped.** Posture (PUSH/HOLD) + Field-order (SPLIT/MASS/HARASS/FALLBACK), `MenuAction 760-765` | `GUI_Menu_Command.sqf:205-224`, server handlers `aicom-posture`/`aicom-fieldorder` via `RequestSpecial`, same-cooldown gated |
| Request-take-town | **Already shipped** as "AI Focus Town": arm with `MenuAction 766`, map-click resolves nearest town, sends `aicom-focus`, server rate-limited 120s (`WFBE_C_TEAM_FOCUS_COOLDOWN`, `Init_CommonConstants.sqf:1006`) | `GUI_Menu_Command.sqf:227-260` |
| — access scope | Open to **any** WEST/EAST player when commander seat empty/locked (not commander-exclusive); GUER excluded (no commander architecture) but covered separately by the paid Commissar Panel town-investment flow | `GUI_Menu.sqf:53` (`ctrlEnable [11005,true]` unconditional WEST/EAST), `GUI_Menu_GuerCommissar.sqf:1-30` |
| Squad intent / role declaration | **Not covered.** No classname/role tag broadcast anywhere in the Chernarus mission (`RoleDeclare`/`SquadIntent` grep: zero hits) | — |
| Quick support request | **Not covered.** No structured ammo/medic/transport request channel; only native free-draw map markers exist (`Client_onEventHandler_MARKER_CREATION.sqf`) and raw `sideChat` | grep for `SupportRequest`/`support_request`: zero hits |
| Player coordination/nudge | **Not covered** as a structured feature. Native marker placement and side-chat are the only tools today | same as above |

**Implication:** any new "AI field-command hint" or "request-take-town" surface belongs in Team Menu only as a *convenience shortcut into the existing Command-menu mechanism* (e.g., a read-only status line + a button that opens `RscMenu_Command` pre-armed), never a second implementation. Building genuinely new logic there would fork behavior TP-13/TP-20/cmdcon27 already hardened (per-player rate limits, STATE-A gating, cooldown UX).

---

## 5. Candidate proposals (ranked)

### Proposal A — "Squad Board" (peer coordination tab) — **recommended**

Fills the one real gap (§4) with the lowest technical/design risk. New tab or section replacing the Gear-Presets-and-prefs sprawl:

- **Role/intent declaration**: player picks a short tag (Rifleman/AT/Medic/Driver/Pilot/Support) from a combo; broadcast side-locally (same side-isolation pattern as `GUI_Menu_TeamV2.sqf:20`) as a lightweight per-unit variable, rendered as a small icon/tag on squad UI (not on the 3D world map globally — scope to squad/side HUD only, matching existing squad-marker precedent in `Client/FSM/updateteamsmarkers.sqf`).
- **Quick support request**: 3-4 canned pings (Need Ammo / Need Medic / Need Transport / Rally Here) fired from the player's current position, side-locally broadcast with a short TTL and per-player cooldown (mirrors the existing cooldown pattern at `GUI_Menu_Command.sqf`'s `_cool`/`_lastSend`), rendered as a temporary map/HUD marker to squad or side.
- **Nudge**: a single "form up on me" ping, functionally a canned variant of the support-request mechanism above, not a separate system.

Buildability: reuses established patterns already proven in this codebase (side-scoped broadcast + cooldown + JIP-safe display gate) — no new server-authoritative state, no AI-commander coupling, no intel exposure surface (everything broadcast is something the player explicitly chose to share). Lowest risk of the three.

### Proposal B — "Commander Signal Relay" (Team Menu → Command Menu bridge)

Addresses the "request-take-town"/"AI field-command hints" asks *without duplicating* `GUI_Menu_Command.sqf`, by giving Team Menu a read-only status line ("Side posture: HOLD" / "AI focus: <town name>, set 43s ago") sourced from the same variables Command Menu already writes, plus a single button that closes Team Menu and opens Command Menu pre-scrolled to the nudge controls. For GUER, the equivalent shortcut opens the Commissar Panel instead.

Buildability: pure UI convenience wiring, zero new game logic, zero new intel surface (it displays exactly what a player could already see by opening Command Menu themselves). Medium value (saves a menu hop for a rarely-time-critical action), very low risk.

### Proposal C — "Clean Squad Menu" (rename + declutter, no new coordination features)

Minimum-effort option: rename to "Squad Menu" to match what it actually does (gear presets + AI-squadmate management + unit templates), migrate the three leftover prefs (FX/high-climb/vote-popup) into `WFBE_SettingsMenu` to finish the TP-21 migration properly, and stop there. No new player-facing coordination capability — just finishes the cleanup TP-21 started and removes the last "duplicates Settings" complaint the owner raised.

Buildability: trivial, but does not answer the owner's actual ask for *gameplay-useful* repurposing — it's a floor, not a target.

---

## 6. Recommended MVP

**Proposal A (Squad Board), scoped down to two pings + one role tag, shipped as a new section replacing the three leftover Preferences controls** (which move to `WFBE_SettingsMenu` per Proposal C, closing that loop in the same pass):

1. Role/intent tag (combo, 5-6 canned values, side-local broadcast, squad-UI icon only).
2. Two canned support pings (Need Ammo, Need Medic) — the two with the clearest immediate payoff and lowest griefing surface (a fake "rally here" ping is more disruptive to misuse than a fake ammo/medic call, which mostly just wastes a squadmate's trip).
3. Leave Gear Presets, Squad Actions (disband/eject/repair), and Unit Designer exactly as-is — they are working, in-use squad-leader tooling; no reason to touch them in this pass.
4. Fold Proposal B's status-line/shortcut in as a stretch add-on once the Squad Board ships and the owner confirms it's worth the extra menu real estate — not required for MVP.

Explicitly **not** in MVP: rebuilding money-transfer (needs its own owner decision per §2.3 — Economy, a dedicated dialog, or intentionally dead), terrain-grid setting (same — confirm intentionally dropped or needs a home), and any new AI-commander-facing logic (§4 — already exists elsewhere).

---

## 7. Open questions for owner

1. Is money transfer intentionally dead (TP-21 cut it with no replacement), or does it need a real home before this repurpose ships? Currently it exists nowhere in the mission.
2. Same question for terrain-grid — intentionally dropped, or a gap?
3. Should the Eject squad-action (`MenuAction 2001`, `GUI_Menu_TeamV2.sqf:511`) get a player-guard to match Disband's, given it can currently eject a human teammate from a vehicle seat? (Pre-existing behavior, not caused by this proposal — flagged as a Discovered Issue, not blocking.)
4. Scope check on "Squad Board" broadcast radius: side-wide vs. group-only? Side-wide gives more coordination value on populated servers; group-only is a smaller/safer first cut given `units group player` is the only membership concept the current Team Menu already uses.

---

## 8. Evidence index

- `Client/GUI/GUI_Menu.sqf:53, 110-117` — button gating, Team Menu dispatch
- `Client/GUI/GUI_Menu_TeamV2.sqf:1-772` (full file) — live V2 logic, `MenuAction` handlers at `:466, 511, 532, 612, 618, 629, 653, 658, 763`
- `Client/GUI/GUI_Menu_Team.sqf` — V1 fallback (flag-gated off by default)
- `Rsc/Dialogs.hpp:1408-1610` (`RscMenu_Team`, V1), `:1613-2112` (`RscMenu_TeamV2`, live), `:4331-4413` (`WFBE_SettingsMenu`), `:3812-4329` (`RscMenu_Economy`)
- `Common/Init/Init_CommonConstants.sqf:2246` (`WFBE_C_TEAM_MENU_V2` default 1), `:2430` (`WFBE_C_UNIT_DESIGNER` default 1), `:1006` (`WFBE_C_TEAM_FOCUS_COOLDOWN` default 120)
- `Client/GUI/GUI_Menu_Command.sqf:190-260` — existing AI-steering (Posture/Field-order/Focus)
- `Client/GUI/GUI_Menu_GuerCommissar.sqf:1-40` — GUER's separate paid town-investment channel
- `Server/AI/Commander/AI_Commander_AssignTowns.sqf:1-60` — AI commander town-priority internals (must stay opaque to players)
- `Client/Functions/Client_onEventHandler_MARKER_CREATION.sqf` — existing native marker baseline
- `stringtable.xml:2096-2105` — dead keys for money transfer / terrain grid (evidence of the cut, not a relocation)

*No implementation performed. This document is a proposal for owner review per V2 §8.3.*
