# Armed MQ-9 UAV — 3 Munition Types (2026-08-04)

Owner task 2026-08-04 (UAV feature, item 1 of 3 — the other two, opening standard UAV
access to GUER and making the FPV strike drone GUER-only, are separately tracked and
**not designed here**). Base checked: `origin/update/wave-20260802`, repo read-only for
this pass — all citations are `git show origin/update/wave-20260802:<path>` or the
`rayswaynl/arma2-co-config-reference` CfgVehicles/CfgWeapons/CfgMagazines/CfgAmmo dumps,
never recollection, never A3 documentation. Mission source of truth is
`Missions/[55-2hc]warfarev2_073v48co.chernarus/` (`<CH>/` below); Takistan/Zargabad are
LoadoutManager mirrors and are not edited directly.

## 1. Feature summary

Today the Tactical-menu "UAV" support call spawns a bare-vanilla-config airframe
(`Server/Support/Support_UAV.sqf:19` `createVehicle [_class, ...]`, no weapon-stripping,
no override) at the side's nearest Command Center. For US/USMC/CDF that airframe is
`MQ9PredatorB` / `MQ9PredatorB_US_EP1`, which already carries one native combat munition
(AGM-114 Hellfire) on its single `MainTurret`. This feature adds two more munition types
to that same turret — GBU-12 (laser-guided bomb) and AGM-65 Maverick (IR-guided
missile) — behind a default-off flag, with **no change to spawn authority, cost, or
cooldown**, and **no change whatsoever to the RU/INS `Pchela1T` platform**, which
structurally has no gunner-fireable turret to arm (UAV Feature Map §7) and is
intentionally excluded by an explicit classname allowlist, not by side.

End state (flag on): a player-controlled MQ-9 spawns with all three munition types
mounted simultaneously on `MainTurret` — Hellfire (native, unchanged), GBU-12 (injected),
Maverick (injected) — and the player, who already remote-controls the turret occupant
via the existing `uav_interface(_oa).sqf` (`player remoteControl _rcUnit`,
`uav_interface_oa.sqf:19-25`), selects among them with the stock A2/OA turret weapon-select
action. No new dialog is created (see §5).

## 2. Flag plan

Master flag, registered once in `Common/Init/Init_CommonConstants.sqf`, appended near the
existing `WFBE_C_PLAYERS_UAV_COST` / `WFBE_C_PLAYERS_UAV_COOLDOWN` pair
(`Init_CommonConstants.sqf:1993-1994`), using the same `if (isNil "X") then {X = v};`
idiom the flag-system reference documents as the append convention
(`docs/design/FLAG-SYSTEM-QUICK-REFERENCE.md`, "Editing Rules"):

```sqf
if (isNil "WFBE_C_UAV_ARMED") then {WFBE_C_UAV_ARMED = 0}; //--- Master: inject GBU-12+Maverick onto MQ-9 MainTurret. 0 = current Hellfire-only behaviour, byte-identical.
if (isNil "WFBE_C_UAV_ARMED_GBU12_MAGS") then {WFBE_C_UAV_ARMED_GBU12_MAGS = 1}; //--- Count of 4Rnd_GBU12 magazines injected (balance knob, non-binding default).
if (isNil "WFBE_C_UAV_ARMED_MAVERICK_MAGS") then {WFBE_C_UAV_ARMED_MAVERICK_MAGS = 1}; //--- Count of 2Rnd_Maverick_A10 magazines injected (balance knob, non-binding default).
```

Plus a plain (non-flag) constant — a scope allowlist, deliberately **not** an
`isNil`-overridable tunable because it is a correctness boundary, not a balance knob:

```sqf
WFBE_C_UAV_ARMED_CLASSES = ["MQ9PredatorB","MQ9PredatorB_US_EP1"]; //--- Only these two hulls are ever armed. Pchela1T has no gunner turret (UAV Feature Map §7) - never add it here.
```

Consumer sites test `WFBE_C_UAV_ARMED > 0` (never bare truthy, never `==`/`!=` on the
flag — `BOOLCMP`/numeric-gate rule) and additionally gate on `typeOf _uav in
WFBE_C_UAV_ARMED_CLASSES` before touching the turret. **Flag off → zero new code
executes → mission byte-identical to HEAD**: no lobby param is added in v1 (this mirrors
`WFBE_C_FPV_FOB`, which also shipped constants-only — `docs/Proposals/FPV-DRONE-FOB-GAP-SPEC-2026-07-24.md`),
no `Rsc/Parameters.hpp` entry, no change to `Support_UAV.sqf`'s spawn authority path at
all in Phase A (see §8 PR-1).

`Tools\Lint\check_sqf.py`'s `FLAGGATE` rule requires a numeric guard (`> 0`/`!= 0`/`== 1`)
on the same or next line as any added `getVariable [..., 0]` read of a `WFBE_C_*` flag —
every new read in this feature satisfies that by construction (`WFBE_C_UAV_ARMED > 0` inline).

## 3. Classnames + config proof (carried from Config Truth research, re-cited here)

| Role | Classname | Proof |
|---|---|---|
| Airframe (unchanged) | `MQ9PredatorB` (CDF/USMC), `MQ9PredatorB_US_EP1` (US/US_Camo) | Already live: `Root_CDF.sqf:18`, `Root_USMC.sqf:18`, `Root_US.sqf:20`, `Root_US_Camo.sqf:21`; `MQ9PredatorB_US_EP1` inherits `MainTurret` from `MQ9PredatorB` unmodified (`CfgVehicles.txt:175853-175867` does not override `Turrets`) |
| Native munition (unchanged) | `HellfireLauncher` / `8Rnd_Hellfire` → `M_Hellfire_AT` | `MQ9PredatorB > Turrets > MainTurret`: `weapons[]={"Laserdesignator_mounted","HellfireLauncher"}`, `magazines[]={"Laserbatteries","8Rnd_Hellfire"}` (`CfgVehicles.txt:163793-163800`); `HellfireLauncher : MissileLauncher` (`CfgWeapons.txt:8449`); ammo `M_Hellfire_AT` (`CfgAmmo.txt:3423`, `irLock=1,laserLock=1`) |
| Injected #1 — GBU-12 | `BombLauncherA10` / `4Rnd_GBU12` → `Bo_GBU12_LGB` | Proven turret-real on vanilla A-10 (`CfgVehicles.txt:143002-143017`); `BombLauncherA10 : BombLauncher` (`CfgWeapons.txt:8532-8537`, `magazines[]={"4Rnd_GBU12"}`); magazine `4Rnd_GBU12` (`CfgMagazines.txt:1658-1661`) → ammo `Bo_GBU12_LGB : LaserBombCore` (`CfgAmmo.txt:3667`, base `216-233`: `irLock=0,laserLock=1` — pure laser, no IR fallback) |
| Injected #2 — Maverick | `MaverickLauncher` / `2Rnd_Maverick_A10` → `M_Maverick_AT` | Also proven on vanilla A-10, same `weapons[]` array as `BombLauncherA10`; `MaverickLauncher : MissileLauncher` (`CfgWeapons.txt:9043-9073`); magazine `2Rnd_Maverick_A10` (`CfgMagazines.txt:1748`) → ammo `M_Maverick_AT : MissileBase` (`CfgAmmo.txt:3484`, `irLock=1`, no `laserLock` field — IR/EO lock, does not contend for the laser) |
| Laser source (unchanged) | `Laserdesignator_mounted` / `Laserbatteries` | Already on `MainTurret` at the same `gunBeg/gunEnd` point (`CfgWeapons.txt:4009`, `Laser=1`); airframe root `laserScanner="true"` (`CfgVehicles.txt:163675`) — the vanilla MQ-9 already self-lases its own Hellfire shots today, unmodified; GBU-12 rides the same beam for free |
| Excluded | `MQ9PredatorB_campaign` | `scope=1, accuracy=0`, campaign-only, not referenced anywhere in the mission — not a candidate, do not use |
| Excluded (structural) | `Pchela1T` | No comparable gunner-armed `MainTurret`; RU/INS stay Hellfire-less/unarmed exactly as today regardless of flag state — enforced by `WFBE_C_UAV_ARMED_CLASSES`, not by side check |

Secondary in-repo precedent worth the implementer's awareness (not the chosen pairing,
just corroboration GBU-12 is a proven-workable magazine in this exact mission): the
existing Su-34 EASA loadout table already mounts `BombLauncherF35` + `2Rnd_GBU12` (a
different weapon/magazine pair, 2 bombs/mag instead of A-10's 4) —
`Client/Module/EASA/EASA_Init.sqf:15` (`git show origin/update/wave-20260802:"Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/EASA/EASA_Init.sqf"`).
Neither `HellfireLauncher` nor `MaverickLauncher` nor any MQ9/Predator/Pchela1T class
appears anywhere in `EASA_Init.sqf` today (`git grep` returns nothing) — confirms this is
genuinely new ground, not a collision with the existing EASA table.

**Turret path.** `MQ9PredatorB` has exactly one weapon station (`Turrets > MainTurret`,
`hasgunner=1`). A2 OA has no per-hardpoint pylon model; the vanilla A-10 already proves 6
distinct weapon classes coexisting in one `weapons[]` array with zero engine conflict.
All three munitions therefore mount on the **same** `MainTurret` via path **`[-1]`**
(hull/driver-index convention for a single-turret airframe — same idiom
`EASA_Equip.sqf:24-29` and `Server/Server_GuerAirDef.sqf:721-734` already use for
Wildcat/Ka-137), **stacking onto** the existing Hellfire loadout, never replacing it:

```sqf
{_uav addWeaponTurret [_x, [-1]]} forEach ["BombLauncherA10","MaverickLauncher"];
for "_i" from 1 to WFBE_C_UAV_ARMED_GBU12_MAGS do {_uav addMagazineTurret ["4Rnd_GBU12", [-1]]};
for "_i" from 1 to WFBE_C_UAV_ARMED_MAVERICK_MAGS do {_uav addMagazineTurret ["2Rnd_Maverick_A10", [-1]]};
```

## 4. UI — how the player selects among the three munitions

**The A2/OA dialog constraint that matters here isn't the Tactical-menu listbox — it's
that the player isn't actually flying the UAV from a custom camera dialog at all.**
`uav_interface_oa.sqf:19-25` already does `player remoteControl _rcUnit` (the gunner, or
driver if no gunner) with `_uav switchcamera "internal"`: the human player *possesses the
real turret occupant*, exactly like an AH-64 gunner. That means A2/OA's **stock,
engine-native turret weapon-select action** (the same scroll-wheel/action-menu "Select
Weapon: X" control every multi-weapon turret in the game already has, driven by the
config's own `RscUnitInfoUAV_gunner` HUD on `turretInfoType`) is available for free the
moment `weapons[]` on `MainTurret` has more than one entry — **zero new dialog, zero new
`.hpp`, zero new listbox needed.**

The interface script already contains the generalizing line that must be touched — one
line, both files (`uav_interface.sqf`, `uav_interface_oa.sqf`, same line number in both
per the UAV Feature Map's byte-identical-mirror finding):

```sqf
_weps = weapons _uav;
if (count _weps > 0) then {_uav selectweapon (_weps select 0)};
```

Today `_weps select 0` is whatever config array order gives (irrelevant with one weapon).
Once three weapons are mounted, array order is not something to depend on for "the
UAV opens on Hellfire by default" — so this needs one defensive rewrite:

```sqf
_weps = weapons _uav;
if ("HellfireLauncher" in _weps) then {_uav selectweapon "HellfireLauncher"} else {if (count _weps > 0) then {_uav selectweapon (_weps select 0)}};
```

Everything past that first frame — cycling to GBU-12 or Maverick mid-flight — is stock
engine behaviour tied to the config's own turret weapon list; no script owns it.

**Alternative (heavier, OWNER DECISION NEEDED, not built unless chosen):** a
pre-flight *preset* picker instead of in-flight cycling — add "UAV (GBU-12 preset)" /
"UAV (Maverick preset)" rows to the Tactical menu's Support list, the same idiom already
used for `UAV` / `UAV_Destroy` / `UAV_Remote_Control` being three rows for one platform
(`GUI_Menu_Tactical.sqf:128`, `:425-434`, `:568-582`). Each preset would request a single
fixed munition set (mirroring the EASA "pick one loadout at spawn" idiom) instead of
mounting all three simultaneously. Trade-offs:

| | In-flight cycle (recommended) | Pre-flight preset rows |
|---|---|---|
| New UI surface | None (native turret action) | 2 new Support-list rows + dispatch cases |
| Player capability | All 3 munitions on every UAV, chosen in the moment | 1 munition family per UAV life, chosen at spawn |
| Engineering cost | 1-line change × 2 interface files | New listbox rows, new client-side pending-selection var consumed in `uav.sqf`'s with-arg branch, no server payload change needed since it stays a purely client-local post-spawn decision |
| Risk | None beyond the injection itself | Duplicate "UAV" family clutters an already-3-row Support list; a 4th/5th row changes `_addToList*` array indices other code may not expect |

This spec's default recommendation is the in-flight cycle (§4, primary). If the owner
wants the preset-row alternative instead, that is PR-4 in §8 and is explicitly gated on
that decision landing first.

## 5. Server/client split and locality

**Server: unchanged.** `Support_UAV.sqf` keeps validating side/team, debiting
`WFBE_C_PLAYERS_UAV_COST`, enforcing `WFBE_C_PLAYERS_UAV_COOLDOWN`, resolving the spawn
point via `GetFactories`/`WFBE_CO_FNC_GetClosestEntity`, and `createVehicle`-ing the bare
airframe exactly as today. **No weapon/magazine logic is added server-side, ever, for
this feature** — for the same reason `EASA_Equip.sqf` and every turret-injection idiom
in this codebase already runs client-side: `addWeaponTurret`/`addMagazineTurret` only
take effect (and replicate) on the machine where the vehicle is **local**, and the
server-created `_uav` is server-local at `createVehicle` time, not client-local.

**Client: arming happens in `Client/Module/UAV/uav.sqf`'s with-arg branch**, after
`_driver moveInDriver _uav` (and, for `west`, `_gunner MoveInGunner _uav`) — the same
point where the script already assumes it owns the vehicle enough to disable AI targeting
(`uav.sqf:49`) and assign waypoints. Locality transfer from server-created-empty to
crew-local is standard OFP/A2 engine behaviour (not an A3-only nuance — this is the
core network-locality model shared across the family), but it is **not guaranteed
synchronous** with `moveInDriver` across a real network hop. The arming block must
therefore wait for confirmed locality before touching the turret, bounded so a stuck
transfer never hangs the script:

```sqf
if (WFBE_C_UAV_ARMED > 0 && {(typeOf _uav) in WFBE_C_UAV_ARMED_CLASSES}) then {
	waitUntil {local _uav || {diag_tickTime - _armWaitStart > 5}}; //--- _armWaitStart set to diag_tickTime just before this block
	if (local _uav) then {
		{_uav addWeaponTurret [_x, [-1]]} forEach ["BombLauncherA10","MaverickLauncher"];
		for "_i" from 1 to WFBE_C_UAV_ARMED_GBU12_MAGS do {_uav addMagazineTurret ["4Rnd_GBU12", [-1]]};
		for "_i" from 1 to WFBE_C_UAV_ARMED_MAVERICK_MAGS do {_uav addMagazineTurret ["2Rnd_Maverick_A10", [-1]]};
		["INFORMATION", Format ["uav.sqf: armed UAV [%1] with GBU-12 x%2, Maverick x%3.", typeOf _uav, WFBE_C_UAV_ARMED_GBU12_MAGS, WFBE_C_UAV_ARMED_MAVERICK_MAGS]] Call WFBE_CO_FNC_LogContent;
	} else {
		["WARNING", Format ["uav.sqf: UAV [%1] never went local for arming - shipped Hellfire-only.", typeOf _uav]] Call WFBE_CO_FNC_LogContent;
	};
};
```

This block sits after the existing `sleep 0.02` (the point the script already treats as
"crew is settled") and before the OA/vanilla interface `ExecVM` dispatch. It never uses a
bare `exitWith` (BAREEXIT trap) and never nests `exitWith` inside a `forEach`.

## 6. Upgrade-level gating (`WFBE_UP_UAV`)

Today `WFBE_UP_UAV` is a **binary** switch — `LEVELS=1` in every side's
`Upgrades_<SIDE>.sqf`, purely gating whether the Tactical "UAV" row is enabled at all
(`GUI_Menu_Tactical.sqf:426`). There is no existing multi-tier concept for this upgrade
to plug into.

**Recommended (Option 1): no new tier.** Armed mode rides on the same `WFBE_UP_UAV > 0`
gate that already exists — a side that has unlocked UAVs at all gets the armed variant
once `WFBE_C_UAV_ARMED > 0`, no separate research step. This is the minimal-risk option:
zero changes to `LEVELS`/`COSTS`/`LINKS`/`TIMES`/`AI_ORDER` across the six side files that
currently have a UAV classname (CDF/US/US_Camo/USMC/RU/INS), and no risk of the
index-parallel-array mismatch the upgrade system is explicitly fragile to
(`Upgrades_<SIDE>.sqf` arrays "must match all side upgrade arrays" per
`docs/design/FLAG-SYSTEM-QUICK-REFERENCE.md`'s "Upgrade ids" row).

**Alternative (Option 2, OWNER DECISION NEEDED, heavier): promote `WFBE_UP_UAV` to
`LEVELS=2`** (1 = current unarmed UAV, 2 = armed). This requires adding a second row to
`COSTS`/`TIMES`/`LINKS`/`AI_ORDER` in every side file that has a UAV today (CDF/US/
US_Camo/USMC/RU/INS — 6 files; RU/INS would need to end up NOT actually granting arming
since `Pchela1T` can't carry it, which means the enable predicate at
`GUI_Menu_Tactical.sqf:426` would also need a platform check, not just a level check, or
RU/INS players would research a level 2 that visibly does nothing). This raises real
cross-side consistency risk for a capability that, per §3, is scoped by classname anyway
— **not recommended unless the owner specifically wants armed UAVs to be a paid research
step separate from unlocking UAVs at all.**

This spec proceeds with Option 1 unless told otherwise.

## 7. Ammo / rearm rules

The UAV **never lands and never touches a rearm pad** in the current flow — it flies a
self-perpetuating racetrack until destroyed or the server watchdog tears it down
(`Support_UAV.sqf` tail, `WFBE_C_UNITS_EMPTY_TIMEOUT`, default 1800s). Consequently:

- No resupply/rearm mechanic is in scope for this feature. Each UAV life expends its
  fixed magazine counts once (8x Hellfire native, `WFBE_C_UAV_ARMED_GBU12_MAGS`×4 GBU-12,
  `WFBE_C_UAV_ARMED_MAVERICK_MAGS`×2 Maverick) and is destroyed/timed out exactly like
  today — no persistence concept to build.
- **Hard requirement: this feature must never route the UAV through
  `Common/Functions/Common_RearmVehicle.sqf`.** That function reads magazines straight
  from `configFile >> "CfgVehicles" >> typeOf _vehicle >> "Turrets" >> "MainTurret" >>
  "Magazines"` (`Common_RearmVehicle.sqf:9-11`) — since the injected GBU-12/Maverick
  magazines exist only at runtime (never in config), a rearm through this function would
  silently wipe them back to `8Rnd_Hellfire` only. `Common_RearmVehicleOA.sqf` instead
  does `setVehicleAmmo 1; reload _vehicle` (`Common_RearmVehicleOA.sqf:9-11`), which
  preserves whatever's currently bound — if a future feature ever needs to rearm a UAV,
  it must use that idiom or a UAV-specific one, never the plain `Common_RearmVehicle.sqf`
  path. Today neither function is called on the UAV, so this is a dormant trap to flag,
  not a live bug this feature introduces.
- `Common_RearmVehicle.sqf`'s SAM/`StaticATWeapon` special-case
  (`_sam = ['2S6M_Tunguska','M6_EP1']`) does not include either MQ9 class — irrelevant,
  confirms no accidental interaction exists today.

## 8. A2 OA traps that apply here

From `CLAUDE.md` / `sqf-edit-guard`, the ones this feature actually touches:

- **BAREEXIT**: any early-return inside the new arming block must be a proper
  `if (..) exitWith {}`, never a bare `exitWith` — a bare one parse-fails the *entire
  file* silently (this is the exact incident class that shipped an empty Factory Upgrade
  Menu on 2026-08-03). The design in §5 uses `if/else`, not `exitWith`, inside the arming
  block for this reason.
- **Turret index trap**: `[-1]` = hull/driver/single-turret path, `[0]` = a *second*
  distinct gunner turret. `MQ9PredatorB` has one `MainTurret` — `[-1]` is correct, proven
  by every existing single-turret precedent in this repo (`EASA_Equip.sqf`,
  `Server_GuerAirDef.sqf`, the Ka-137 flare block in `Client_BuildUnit.sqf:1224`, whose
  comment states outright: "hull addMagazine/addWeapon silently no-op on it").
  **Never use plain `addWeapon`/`addMagazine` on the MQ-9 — it will silently no-op.**
- **Locality**: `addWeaponTurret`/`addMagazineTurret` must run where `_uav` is local
  (§5). This is the one trap not enumerated in the CLAUDE.md checklist verbatim because
  it's core engine/network behaviour rather than an OA-specific command trap — flagged
  here because getting it wrong produces a *silent* no-op (script runs, no error, weapons
  just never appear), the worst kind of failure to debug blind.
- **Numeric-flag guard**: every new `WFBE_C_UAV_ARMED*` read uses `> 0`, never bare
  truthiness (`if (0)` is truthy on OA) and never `==`/`!=` on a flag value directly.
- **`isKindOf` ban on weapon/magazine classnames**: if any future code needs to check
  "does this UAV already carry Maverick," use `"MaverickLauncher" in (weapons _uav)`,
  never `isKindOf` (it walks `CfgVehicles`, wrong tree entirely for a weapon class).
- **`_x` capture**: the `forEach ["BombLauncherA10","MaverickLauncher"]` /
  magazine-count `for` loops in §5 don't nest another `forEach` inside them — if a future
  edit adds one (e.g. per-magazine logging), capture `_x` to a named local first.
- **New-classname index**: `HellfireLauncher`/`BombLauncherA10`/`MaverickLauncher` and
  their magazines are config-native (no new `CfgWeapons`/`CfgMagazines` entries needed)
  but are **new to this mission's script tree** — the PR body must carry the §3 config-proof
  citations for `Tools/Lint`'s classname-index gate, same as any new classname reference.
- **Mirror regen**: this is a Chernarus-source edit (`uav.sqf`, `uav_interface.sqf`,
  `uav_interface_oa.sqf`, `Init_CommonConstants.sqf`) — run
  `Tools\LoadoutManager` (`dotnet run -c RELEASE`) after editing and restore the TK/ZG
  `version.sqf.template` drift before staging, per `CLAUDE.md`'s standard mirror step.
- **HandleDamage**: not touched by this feature (no damage-model changes), noted only
  because it's on the CLAUDE.md trap list — confirming it's genuinely out of scope here
  rather than silently skipped.

## 9. Test plan

This repo has already had to unwind the "assert the exact literal source text, not the
behaviour" anti-pattern at least twice in its history (`d0fbaa36e6` "gate spawn-buddy
disband on first-join, not a tautological group check", `ab75919996` "extraWeaponsToRemove
tautology fix v2") — and the existing `test_uav_spawn_authority.py` itself is written in
exactly that style (`assertIn` on exact production-code strings, e.g. asserting the file
literally contains `_uav = createVehicle`). This spec deliberately does **not** propose
more of that for the new code; new tests below assert *shape/scope invariants*, not
call-site literals.

### Must be verified in-game (no static test can meaningfully assert these)

- Vehicle locality actually transfers from server-created to client-local before the
  bounded `waitUntil {local _uav}` times out, on a real dedicated-server hop (not
  editor preview, which hides locality timing entirely since editor preview runs
  everything on one machine).
- Once armed, the `RscUnitInfoUAV_gunner` HUD actually shows all three weapons and the
  stock "Select Weapon" action actually cycles between them while `player remoteControl
  _rcUnit` is active.
- Each munition actually fires and guides correctly: Hellfire and GBU-12 both self-lase
  off the UAV's own `Laserdesignator_mounted` and hit a lased point; Maverick IR/EO-locks
  without needing the laser at all.
- `Pchela1T` (RU/INS) spawns completely unaffected with the flag on — the allowlist
  check in §5 is a no-op for it, verify no error is logged and no weapons appear.
- Cost debit, cooldown, and command-center-proximity spawn logic are unchanged
  (regression pass on the existing behaviour, flag on and flag off).
- The existing locked driver-AI-restore fix (#1948,
  `Tools/Lint/test_uav_destroyed_driver_ai_restore.py`) still fires correctly once the
  new arming block sits in the middle of `uav.sqf` — confirm in-game that a destroyed
  armed UAV still restores its driver's AI on teardown.
- Mirrors (TK/ZG) behave identically to Chernarus in an actual live session, not just
  byte-for-byte on disk.
- Flag-off byte-identical claim holds under an actual mission diff/soak, not just by
  inspection.

### What a contract test can meaningfully assert (behavior/shape, not implementation literals)

- **Scope boundary, not call-site text**: `WFBE_C_UAV_ARMED_CLASSES` contains exactly
  `MQ9PredatorB` and `MQ9PredatorB_US_EP1` and does **not** contain `Pchela1T` or
  `MQ9PredatorB_campaign` — a regression guard against someone accidentally widening
  scope, written against the *array contents*, not against the surrounding code shape.
- **Flag registration idiom**: `WFBE_C_UAV_ARMED` is registered exactly once in
  `Init_CommonConstants.sqf` using the `if (isNil "X") then {X = 0};` fallback form (not
  a bare assignment) — guards against a duplicate/drifted registration, not a behaviour
  guarantee (explicitly weak, kept thin on purpose).
- **Turret-path discipline**: the new code touches `_uav` only via `addWeaponTurret`/
  `addMagazineTurret` with a `[-1]` path — never plain `addWeapon`/`addMagazine` on this
  vehicle (regex/structural check, not a pin on the exact surrounding `if` nesting).
- **Mirror parity** (proven-useful existing idiom, reused as-is): `uav.sqf`,
  `uav_interface.sqf`, `uav_interface_oa.sqf` are byte-identical across CH/TK/ZG after
  the LoadoutManager run — same technique `test_uav_spawn_authority.py`'s
  `test_generated_copies_match_source` already uses, and it's non-tautological because
  cross-file mirror consistency is a genuine external requirement, not a test of our own
  literal code.
- **`Common_RearmVehicle.sqf` never referenced from the new code paths**: a structural
  check that neither `uav.sqf` nor `Support_UAV.sqf` calls `Common_RearmVehicle.sqf` (the
  wipe-back trap in §7) — this is a real behavioral guarantee (absence of a dangerous
  call), not a tautology.

## 10. Work breakdown (PR-sized chunks)

All PRs: draft-only, `gh pr create --draft --base master`, GUIDE-REV `GR-2026-07-08a` in
the body, flag name + default + why-flag-off-is-inert + test plan + mirrors-confirmed
fields per `CLAUDE.md` PR mechanics. Claim-protocol check (`agent-status.json` / wiki
Agent-Worklog / open PRs) before starting each.

1. **PR-1 — Flag scaffolding only.** Register `WFBE_C_UAV_ARMED`,
   `WFBE_C_UAV_ARMED_GBU12_MAGS`, `WFBE_C_UAV_ARMED_MAVERICK_MAGS`, and the
   `WFBE_C_UAV_ARMED_CLASSES` constant in `Init_CommonConstants.sqf`. No consumer reads
   any of them yet — behavior is trivially unchanged. Smallest possible reviewable unit;
   unblocks PR-2/PR-3 to land independently.
2. **PR-2 — Client-side turret injection.** The §5 arming block in `uav.sqf`'s with-arg
   branch (allowlist check, bounded locality wait, `addWeaponTurret`/`addMagazineTurret`
   `[-1]` calls, log lines). Depends on PR-1. Includes the §9 scope-boundary and
   turret-path-discipline contract tests.
3. **PR-3 — Interface default-weapon fix.** The one-line `selectweapon` change in
   `uav_interface.sqf` + `uav_interface_oa.sqf` (§4) so the UAV interface always opens on
   Hellfire regardless of config array order once multiple weapons exist. Independent of
   PR-2's exact injection order; can land in either sequence but is inert without PR-2.
4. **PR-4 — Preset-row UI (contingent, OWNER DECISION NEEDED first).** Only started if
   the owner picks the §4 alternative over the recommended native-cycle default. Adds
   Tactical-menu Support rows + a client-local pending-munition variable consumed in
   `uav.sqf`. Not scoped further until that decision lands — building it speculatively
   risks conflicting with whichever `_addToList*` index layout PR-2/PR-3 settle into.
5. **PR-5 — Contract tests + mirror-parity check.** The remaining §9 static assertions
   (flag-registration idiom, `Common_RearmVehicle.sqf`-absence guard, mirror-parity for
   the three touched files). Can land alongside PR-2/PR-3 or immediately after.
6. **Verification gate (not a PR).** The full §9 in-game checklist on a live
   dedicated-server session (soak farm or owner-observed), before the master flag is ever
   considered for default-on. Flipping the default is an owner call, not an agent action,
   per the flag policy's "never change existing defaults" rule applied forward — this
   spec only proposes shipping it default-0.

## 11. Open owner decisions (summary)

- **UI mechanism** (§4): native in-flight turret weapon-cycle (recommended, zero new UI)
  vs. pre-flight preset rows (heavier, single munition family per UAV life). Note: the
  premise that only 2 of 3 munitions might be airframe-feasible did **not** hold — config
  proof (§3) confirms all three mount concurrently on the one `MainTurret`, same as the
  vanilla A-10's six-weapon precedent — so this decision is about *how the player reaches
  the third (and second) munition*, not which one to drop.
- **Upgrade gating** (§6): stay on the existing binary `WFBE_UP_UAV > 0` gate
  (recommended) vs. promote to a 2-level upgrade specifically for armed mode (heavier,
  cross-side array risk, and would need an extra platform check for RU/INS regardless).
- **Balance defaults**: `WFBE_C_UAV_ARMED_GBU12_MAGS` / `WFBE_C_UAV_ARMED_MAVERICK_MAGS`
  default to 1 magazine each (4x GBU-12, 2x Maverick) in this spec — non-binding,
  owner/economy-pass adjustable via the flag tunables without a code change.

## Note (out of scope, discovered in the course of this research)

The wiki page `CruiseMissile-Strike-Asset.md` claims `CruiseMissile2 : MQ9PredatorB`
"carries a `weapons[]` array" and behaves as "an armed strike drone." The actual config
(`CfgVehicles.txt:175501-175543`) shows the opposite — `CruiseMissile2` explicitly empties
everything (`weapons[]={}`, `magazines[]={}`, `class Turrets{}`), same as `CruiseMissile1`.
Flagging for a wiki fix; not designed off it here, and unrelated to this feature (`CruiseMissile2` is not `WFBE_%1UAV`-referenced anywhere in the mission).
