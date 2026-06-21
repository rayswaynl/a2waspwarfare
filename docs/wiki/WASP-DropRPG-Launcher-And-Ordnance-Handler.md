# WASP DropRPG Launcher and Ordnance Handler

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`WASP/rpg_dropping/DropRPG.sqf` is a per-player client handler contributed by DeraKOren (header dated 25.01.2012, `DropRPG.sqf:1-6`). One `addAction` plus one `Fired` event handler ride on the player and carry three independent mechanics: a single-use AT-launcher fire-then-drop weapon swap with a reload-on-switch scroll action, a friendly-base PipeBomb teamkill guard, and `[object, time]` mine tracking that feeds the server mine cleaner. The whole file is `call Compile preprocessFileLineNumbers`-ed against the player at client init and re-applied on respawn, so the handlers always sit on the live player object.

This page owns the producer side (the launcher swap, the `_addMag` action, the PipeBomb guard, the mine append). The consumer side of the mine queue — the server FSM that ages out tracked pairs — lives in [Marker-Cleanup-Restoration-Systems-Atlas](Marker-Cleanup-Restoration-Systems-Atlas), which this page links to rather than re-deriving.

---

## Wiring and Lifecycle

The handler is bound to the player object, not compiled into a global function. It must be re-bound every time the player object is replaced (respawn), which is why it appears in both the client init path and the pre-respawn handler.

| Wire point | Source | What it does |
|---|---|---|
| Client init | `Client/Init/Init_Client.sqf:31` | `player call Compile preprocessFileLineNumbers "WASP\rpg_dropping\DropRPG.sqf";` — runs the file with `player` as `_this`, installing the action + EH on the spawned player. |
| Respawn re-bind | `Client/Functions/Client_PreRespawnHandler.sqf:12` | `player call Compile preprocessFileLineNumbers "WASP\rpg_dropping\DropRPG.sqf";` — re-installs the same action + EH on the new player object after death. |

Because the file is bound with `call` (not `spawn`/`execVM`), `_this` inside the file body is the player object. At `DropRPG.sqf:9` it seeds a per-player variable `OldWeapon` to the sentinel string `"some weapon"` (broadcast flag `false`, so the variable is local) before any swap tracking begins.

> Note: the `WASP-Overlay` subtree map and `WASP-Overlay` wire table currently cite `Init_Client.sqf:15` for this wiring; in master `0139a346` the live wire is at `Init_Client.sqf:31`. Line 15 in current master is the deadspawn-invulnerability block, unrelated to DropRPG.

---

## The `_addMag` reload-on-switch action

`_addMag` (`DropRPG.sqf:11-40`) is an inline code block bound as a scroll action at `DropRPG.sqf:41`:

```
_this addAction ["","","",6,true,true,"",format ["Call %1", _addMag]];
```

In the Arma 2 OA extended array form `addAction [title, script, arguments, priority, showWindow, hideOnUse, shortcut, condition]`, the 2nd argument (the activation script) is the empty string `""`, so selecting the action does nothing. The launcher logic instead rides in the 8th argument (the condition, evaluated continuously while the action menu is shown): `format ["Call %1", _addMag]`. That expression resolves to the string `Call <code>`, and it is this condition-slot string that runs `_addMag` repeatedly — once per frame the menu is up — so the reload-on-switch check is driven by the condition poll, not by the player activating the action. This is the classic "call code from the addAction condition" polling idiom. The title is empty and the priority is `6`. Each time the block runs it compares the player's `currentWeapon` against the stored `OldWeapon`:

| Transition | Source | Effect |
|---|---|---|
| Switched **to** a tracked launcher (`M136`, `RPG18`, `BAF_NLAW_Launcher`) | `DropRPG.sqf:19-27` | `_sol addMagazine _magaz` grants one matching round. The magazine class is resolved by a `switch`: `M136`→`"M136"`, `RPG18`→`"RPG18"`, `BAF_NLAW_Launcher`→`"NLAW"` (`DropRPG.sqf:20-24`). `OldWeapon` is advanced to the current weapon. |
| Switched **away from** a tracked launcher | `DropRPG.sqf:28-36` | `_sol removeMagazines _magaz` strips the launcher's rounds so they cannot be carried on a non-launcher weapon. Same `switch` mapping. `OldWeapon` is advanced. |
| No change, or change between non-tracked weapons | `DropRPG.sqf:18,37-38` | When `_curwep != _oldwep`, `OldWeapon` is updated to the current weapon so the next switch is measured from the right baseline. |

The block returns `_result` (`DropRPG.sqf:39`), which is initialized `false` and never set true; the return value is unused. The three tracked launcher classes here are the single-use launchers — they are exactly the set that the `Fired` handler drops on use (below).

---

## The `Fired` event handler

`DropRPG.sqf:42-92` is one `addeventhandler ["Fired", { ... }]`. The handler binds the standard `Fired` array: `_weapon = _this select 1`, `_ammo = _this select 4`, `_bomb = _this select 6` (`DropRPG.sqf:45-47`). It branches three independent ways on the ammo/weapon that was just fired.

### (a) PipeBomb friendly-base TK prevention

| Step | Source | Detail |
|---|---|---|
| Gate on ammo | `DropRPG.sqf:52` | Only runs when `_ammo == "PipeBomb"`. |
| Scan for friendly base structures | `DropRPG.sqf:55` | `nearestObjects [_sol, ["Warfare_HQ_base_unfolded","WarfareBBaseStructure","BTR90_HQ","LAV25_HQ"], 30]` — any of these four base/HQ classes within 30 m of the firer. |
| Side check | `DropRPG.sqf:57-61` | Loops the scan results; if any matched structure shares the firer's `side`, sets `_teamkillbase = true`. |
| Delete the charge | `DropRPG.sqf:62` | If `_teamkillbase`, `deleteVehicle _bomb` removes the satchel before it can detonate, blocking base teamkilling. |

The four-class friendly-base list — `Warfare_HQ_base_unfolded`, `WarfareBBaseStructure`, `BTR90_HQ`, `LAV25_HQ` — is the literal classlist used for this guard. Note the scan loop runs `for "_i" from 0 to (count _list)` (`DropRPG.sqf:57`), which iterates one index past the end of `_list`; in practice the `side` comparison against the out-of-range element evaluates harmlessly because the guard only ever sets the flag true on a real match.

### (b) Mine `[object, time]` tracking

| Step | Source | Detail |
|---|---|---|
| Gate on ammo | `DropRPG.sqf:65` | Runs when `_ammo == "Mine"` or `_ammo == "MineE"`. |
| Build the pair | `DropRPG.sqf:66` | `_mines_arr = [_bomb, time]` — the placed mine object paired with the mission `time` it was laid. |
| Append to the global queue | `DropRPG.sqf:67` | `mines set [count mines, _mines_arr]` pushes the pair onto the global `mines` array. |

`mines` is the shared global queue owned by the server mine cleaner, which initializes it to `[]` and ages out pairs once `time - createdAt >= WFBE_C_MINEFIELDS_CLEANER_TIME_PERIOD` (`Server/FSM/cleaners/mines_cleaner.sqf:3,14-17`). DropRPG is one of two producers; the other is minefield construction, which pushes the same `[mine, time]` shape at `Server/Construction/Construction_StationaryDefense.sqf:54,66,77`. The cleaner's removal step (`mines = mines - _x`) is the wrong shape for nested pairs — that defect is tracked on the consumer page, not here.

### (c) Single-use launcher: removeWeapon + WeaponHolder drop + 30s delete

| Step | Source | Detail |
|---|---|---|
| Gate on weapon | `DropRPG.sqf:71` | Runs when the fired `_weapon` is `M136`, `RPG18`, or `BAF_NLAW_Launcher` (the same three tracked launchers). |
| Capture position/heading | `DropRPG.sqf:72-76` | `_pos = getPosATL _sol`, `_dir = direction _sol + 90`, drop offset `_d = 0.7` m to the player's side. |
| Strip the launcher | `DropRPG.sqf:78` | `_sol removeWeapon _weapon` — the launcher is removed from the player on fire, making it single-use. |
| Spawn the dropped weapon | `DropRPG.sqf:79-82` | `"WeaponHolder" createVehicle [...]` beside the player, `setPosATL` + `setDir`, then `addWeaponCargoGlobal [_weapon, 1]` so the empty launcher physically lies on the ground. |
| Mark as spent | `DropRPG.sqf:83` | `_wep setDammage 1` — the dropped holder is set to full damage (a comment notes this keeps the visual launcher from being re-picked-up as usable). |
| Self-delete | `DropRPG.sqf:85-90` | `[_wep] spawn { ... sleep 30; deleteVehicle _wep; }` removes the dropped holder 30 seconds after the shot. |

This is the launcher-half of the contract the `_addMag` action sets up: the action grants exactly one round when the player selects a tracked launcher, and the `Fired` handler removes the launcher and drops it the moment that round is fired — so each `M136`/`RPG18`/`NLAW` is a genuine one-shot disposable.

---

## Relationship to other ordnance handlers

DropRPG is an **infantry, player-bound** `Fired` handler installed by `call Compile` directly on the player object. It is distinct from the vehicle-mounted missile family: `Client_PreRespawnHandler.sqf:13` separately attaches `["Fired",{_this Spawn HandleAT}]` to `vehicle player`, and the broader `HandleAT`/`HandleAAMissiles`/`HandleShootBombs` family is documented in [Missile-And-Ordnance-Fired-EH-Reference](Missile-And-Ordnance-Fired-EH-Reference). DropRPG does not touch those handlers and they do not touch the launcher swap, the PipeBomb guard, or the mine queue.

---

## Continue Reading

- [WASP-Overlay](WASP-Overlay) — the WASP/ overlay subtree map and per-file wire table this handler belongs to.
- [Marker-Cleanup-Restoration-Systems-Atlas](Marker-Cleanup-Restoration-Systems-Atlas) — the consumer side: the server mine cleaner that ages out the `[mine, time]` pairs DropRPG appends, plus the pair-removal defect.
- [Missile-And-Ordnance-Fired-EH-Reference](Missile-And-Ordnance-Fired-EH-Reference) — the vehicle-mounted `HandleAT`/`HandleAAMissiles` Fired-EH family, distinct from this infantry launcher handler.
- [Player-Skill-Abilities-Reference](Player-Skill-Abilities-Reference) — other per-player WASP scroll actions and ability handlers added on top of stock WFBE.
