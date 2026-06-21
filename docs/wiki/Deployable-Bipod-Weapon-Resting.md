# Deployable Bipod / Weapon Resting

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

A client-side, player-facing "deploy bipod" / weapon-resting mechanic. While carrying one of a fixed whitelist of machine guns and sniper rifles, a player who presses TAB in a valid stance (prone, or crouched directly behind a short solid object) has their weapon recoil zeroed and gets an audible/visual confirmation. The entire feature lives in a single function, `Common\Functions\Common_Bipod.sqf` (header credits `// -WASP-` and `// 3JIbIDEHb aka Smirnoff_ICE`, `Common_Bipod.sqf:1-2`), is `execVM`'d once at client init, and is invisible to the server — it only adjusts the local player's recoil coefficient.

## Wiring and lifecycle

The function is launched once per client during client init, after the local `HandleDamage` rearmor handler is attached:

| Step | Where | Detail |
|---|---|---|
| Launch | `Client\Init\Init_Client.sqf:66` | `[] execVM "Common\Functions\Common_Bipod.sqf";` — fire-and-forget, no return value used, no global handle stored. |
| Wait for UI | `Common_Bipod.sqf:5` | `waituntil {!isnull (finddisplay 46)};` — blocks until the main mission display (IDD 46) exists, so the KeyDown handler attaches to a live display. |
| Attach key hook | `Common_Bipod.sqf:5` | `(findDisplay 46) displayAddEventHandler ["KeyDown","_this select 1 call Bipod_ON; false"];` — the handler passes the DIK key code (`_this select 1`) into `Bipod_ON` and returns `false`, so the keypress is **not** consumed (TAB still performs its normal in-game function). |
| Define handler | `Common_Bipod.sqf:7-65` | `Bipod_ON = { switch (_this) do { ... } };` — a global code value invoked on every key-down event. |

Because `Bipod_ON` is a global and the KeyDown handler is bound to display 46, the function runs on each player's machine only. There is no server call, no `publicVariable`, and no `setVehicleInit` — nothing about bipod state propagates off the local client.

## The TAB case and stance gate

`Bipod_ON` is called for *every* key-down on display 46 but only acts on one key:

| Element | Path:line | Behavior |
|---|---|---|
| Switch on key code | `Common_Bipod.sqf:8` | `switch (_this) do` where `_this` is the raw DIK code from the KeyDown event. |
| TAB case | `Common_Bipod.sqf:11` | `case 15:` — DIK code 15 is TAB (the inline comment at `Common_Bipod.sqf:10` reads "For using bipod hit TAB"). All other keys fall through with no effect. |
| Current weapon | `Common_Bipod.sqf:12` | `_weapon = currentWeapon player;` — captured for the whitelist test below. |
| Target object | `Common_Bipod.sqf:48` | `_behind = cursorTarget;` — the object the player is currently looking at, used as the "rest" surface. |
| Object size | `Common_Bipod.sqf:49` | `_size = sizeOf (typeOf _behind);` — the configured bounding size of that object's class. |
| Proximity/size test | `Common_Bipod.sqf:50` | `Stands_behind = ((player distance _behind < _size/2.2) && (_size < 16.2));` — true when the player is close to a *small* object (the `_size < 16.2` cap rejects large structures). |
| Prone path | `Common_Bipod.sqf:51` | `Lying_stand = ((animationState player == "amovppnemstpsraswrfldnon") && (_weapon in _affected));` — prone rifle-down idle animation **and** a whitelisted weapon. |
| Crouch path | `Common_Bipod.sqf:52` | `Crouch_stand = ((Stands_behind) && (_weapon in _affected) && (!(typeof _behind isKindOf "Man")) && (!(typeof _behind isKindOf "Air")));` — close to a small object, whitelisted weapon, and the rested object is neither a man nor an aircraft. |
| Apply | `Common_Bipod.sqf:53-55` | `if (Lying_stand or Crouch_stand) then { ... };` — only one of the two gates needs to pass. |

So there are exactly two ways to "deploy": be **prone** with a supported weapon (no object required), or be **near a small solid prop** (vehicle/structure under the size cap, not a person or aircraft) with a supported weapon.

## Effect when the gate passes

| Action | Path:line | Effect |
|---|---|---|
| On-screen text | `Common_Bipod.sqf:54` | `SetBipodOn = HintSilent (localize "str_bipod");` — a silent hint. Note: the `str_bipod` key is **commented out** in `stringtable.xml:62-73` (the `<!--<Key ID="str_bipod">` block, original text "Bipod deployed"), so `localize "str_bipod"` returns the literal string `"str_bipod"` at runtime rather than the intended "Bipod deployed". The hint result is stored in the global `SetBipodOn`, which is never read anywhere else. |
| Zero recoil | `Common_Bipod.sqf:54` | `player setUnitRecoilCoefficient 0;` — the actual rest effect: removes weapon recoil for the local player. |
| Confirm sound | `Common_Bipod.sqf:54` | `player say "Bipod_ON";` — plays the mission sound `Bipod_ON`, defined at `Sounds/description.ext:66-69` (`name = "Bipod_ON"; sound[] = {"\Sounds\Bipod_ON-10.ogg", 10, 1};`). |
| Reset recoil | `Common_Bipod.sqf:64` | `player setUnitRecoilCoefficient 1;` — sits **outside all case labels** in the switch body (after the closing `};` of case 15 at line 62, before the switch's own `};` at line 65) and runs unconditionally on every key-down event — not just TAB presses. Because every key-down both potentially sets recoil to `0` (inside the TAB case `if` gate) and then unconditionally restores it to `1` here, the zeroed-recoil state is momentary unless re-asserted; a player effectively pulses recoil off by holding/tapping TAB. |

The `private` declaration at `Common_Bipod.sqf:3` (`private ["_unit","_weapon","_affected","_behind","_size"]`) lists `_unit`, which is never assigned or used inside the function. The globals `Stands_behind`, `Lying_stand`, `Crouch_stand`, and `SetBipodOn` are created without `private` and leak into mission namespace, but none are read outside this file (verified by grep across `*.sqf`).

## Supported-weapon whitelist

`_affected` (`Common_Bipod.sqf:13-47`) is a hard-coded array of weapon class names; only `currentWeapon player` matching one of these enables the rest. The list mixes BAF/PMC DLC weapons, OA base sniper rifles, and squad automatic weapons:

| Category | Classes (verbatim from `Common_Bipod.sqf:13-47`) |
|---|---|
| Heavy/anti-materiel sniper | `ksvk`, `m107`, `m107_TWS_EP1`, `BAF_AS50_scoped`, `BAF_AS50_TWS`, `BAF_LRR_scoped`, `BAF_LRR_scoped_W`, `PMC_AS50_scoped`, `PMC_AS50_TWS` |
| Marksman / sniper rifles | `BAF_L86A2_ACOG`, `M110_NVG_EP1`, `M110_TWS_EP1`, `M24`, `M24_des_EP1`, `M40A3`, `m8_sharpshooter`, `SCAR_H_LNG_Sniper`, `SCAR_H_LNG_Sniper_SD` |
| GPMG / MMG | `BAF_L7A2_GPMG`, `M240`, `m240_scoped_EP1`, `M60A4_EP1`, `Mk_48`, `Mk_48_DES_EP1`, `Pecheneg`, `PK` |
| SAW / LMG | `BAF_L110A1_Aim`, `M249`, `M249_EP1`, `M249_m145_EP1`, `M249_TWS_EP1`, `m8_SAW`, `MG36`, `MG36_camo`, `RPK_74` |

Any weapon not on this exact list (including newer/modded MGs and snipers) gets no rest effect even in a valid stance. The list is a literal, so adding support means editing `Common_Bipod.sqf` directly.

## Dead/debug code in the same case

Below the TAB block, a `case 57:` ("Hit SPACE", `Common_Bipod.sqf:57`) and a closing debug `hint` line (`Common_Bipod.sqf:61`) are fully commented out, along with a trailing `HintSilent "";` (`Common_Bipod.sqf:63`). They were a development bounding-box probe and are inert. The only live key is TAB.

## Continue Reading

- [Engine Stealth & Fuel Toggle Reference](Engine-Stealth-Fuel-Toggle-Reference) — a sibling client-side key/action toggle of similar shape.
- [Earplugs Audio Toggle Reference](Earplugs-Audio-Toggle-Reference) — another local, player-only quality-of-life toggle.
- [Client UI HUD And Menus](Client-UI-HUD-And-Menus) — where display 46 KeyDown hooks and client HUD wiring are catalogued.
- [Mission Entrypoints And Lifecycle](Mission-Entrypoints-And-Lifecycle) — the `Init_Client.sqf` client-init chain that `execVM`s this function.
- [Faction Unit And Vehicle Roster Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — context for the weapon classes in the whitelist.
