# Client Gear-Parsing and Cargo-Capacity Function Reference (descriptor consumers)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This is the runtime **consumer** side of the WASP gear-descriptor encoding: the client-side functions that read the per-item descriptor arrays the config generator stashes in `missionNamespace`, sort a flat weapon/magazine list into a structured loadout, and compute free cargo capacity against `CfgVehicles` `transportMax*` limits. These functions drive the buy-gear menu (`Client/GUI/GUI_BuyGearMenu.sqf`). For the **producer** side (how `[4]`/`[5]` get written), see `Common/Config/Config_Weapons.sqf` and `Common/Config/Config_Magazines.sqf` — documented in the Gear-Store catalogs, not here.

All seven functions are compiled into `WFBE_CL_FNC_*` aliases in `Client/Init/Init_Client.sqf`. Four of them (`GetBackpackContent`, `GetVehicleContent`, `GetUnitBackpack`, and indirectly `GetParsedGear`'s backpack fold) are stubbed to inert no-ops when `WF_A2_Vanilla` is true, because vanilla Arma 2 has no backpack/`unitBackpack` engine support.

## The gear-descriptor array (what these functions read)

Every purchasable item has a descriptor array stored in `missionNamespace` under its own classname (weapons/items) or under `Mag_<classname>` (magazines). The consumers care about two fixed indices: index **4** is the slot/category code, index **5** is the cargo size (weight). Producer proof: `Config_Weapons.sqf:38` writes `_set set [4, _belong]` and `Config_Weapons.sqf:39` writes `_set set [5, _size]`; `Config_Magazines.sqf:28` writes `_set set [4, _belong]` and `Config_Magazines.sqf:29` writes `_set set [5, _type/_div]`.

| Code `[4]` | Meaning | Source of the code |
|---|---|---|
| 0 | Primary weapon (`type` 1 or 5, size 10) | Config_Weapons.sqf:21,24,38 |
| 1 | Handgun / pistol (`type` 2, size 5) | Config_Weapons.sqf:22,38 |
| 2 | Secondary / launcher (`type` 4, size 10) | Config_Weapons.sqf:23,38 |
| 3 | (consumer-only) primary that also clears the secondary slot | Client_GetParsedGear.sqf:32 |
| 4 | Special / equipment (`type` 4096, size 1) | Config_Weapons.sqf:25,38 |
| 5 | Misc item (`type` 131072, size 1) | Config_Weapons.sqf:26,38 |
| 100 | Secondary (handgun) magazine | Config_Magazines.sqf:19,28 |
| 101 | Main (primary) magazine | Config_Magazines.sqf:20,28 |
| 200 / 201 | Backpack | Client_GetParsedGear.sqf:35-36 |

Note that code **3** is never produced by the config generator — only the parser emits it as a behavior (a primary that displaces the secondary slot). The magazine size at index 5 is `_type/_div` where `_div` is 16 for handgun mags and 256 for main mags (`Config_Magazines.sqf:19-20,29`).

## Function family at a glance

| Alias | File | Vanilla stub | Returns |
|---|---|---|---|
| `WFBE_CL_FNC_GetParsedGear` | Client_GetParsedGear.sqf | — | 9-element loadout tuple |
| `WFBE_CL_FNC_GetGearCargoSize` | Client_GetGearCargoSize.sqf | — | 7-element backpack-capacity tuple |
| `WFBE_CL_FNC_GetVehicleCargoSize` | Client_GetVehicleCargoSize.sqf | — | 6-element vehicle-capacity tuple |
| `WFBE_CL_FNC_GetMagazinesSize` | Client_GetMagazinesSize.sqf | — | scalar total magazine size |
| `WFBE_CL_FNC_GetBackpackContent` | Client_GetBackpackContent.sqf | `{[[],[]]}` | `[weaponCargo, magazineCargo]` |
| `WFBE_CL_FNC_GetVehicleContent` | Client_GetVehicleContent.sqf | `{[[],[],[]]}` | `[[weps,counts],[mags,counts],[bags,counts]]` |
| `WFBE_CL_FNC_GetUnitBackpack` | Client_GetUnitBackpack.sqf | `{""}` | backpack classname string |

Alias declarations: `Init_Client.sqf:117,128-133`. The conditional vanilla stubs are on `Init_Client.sqf:117` (`GetBackpackContent`), `132` (`GetVehicleContent`), `133` (`GetUnitBackpack`).

## WFBE_CL_FNC_GetParsedGear

Sorts a flat list of weapon classnames and a flat list of magazine classnames into a structured loadout. The entry point that seeds the buy-gear UI.

| Aspect | Detail | Cite |
|---|---|---|
| Params | `[_weapons, _magazines, (_unit)]`. `_unit` optional, defaults `objNull` | Client_GetParsedGear.sqf:10-12 |
| Weapon dispatch | `missionNamespace getVariable _x`, skip if `isNil`, then `switch (_get select 4)` | Client_GetParsedGear.sqf:25-28 |
| Case 0 | sets `_get_prim = _x` | Client_GetParsedGear.sqf:29 |
| Case 1 | sets `_get_hand = _x` | Client_GetParsedGear.sqf:30 |
| Case 2 | sets `_get_seco = _x` | Client_GetParsedGear.sqf:31 |
| Case 3 | sets `_get_prim = _x` **and clears** `_get_seco = ""` | Client_GetParsedGear.sqf:32 |
| Case 4 | appends to `_get_spec[]` | Client_GetParsedGear.sqf:33 |
| Case 5 | appends to `_get_misc[]` | Client_GetParsedGear.sqf:34 |
| Cases 200/201 | both set `_get_backpack = _x` | Client_GetParsedGear.sqf:35-36 |
| Magazine dispatch | `missionNamespace getVariable Format ["Mag_%1",_x]`, then `switch (_get select 4)` | Client_GetParsedGear.sqf:42-45 |
| Case 100 | appends to `_get_mag_seco[]` (handgun mags) | Client_GetParsedGear.sqf:46 |
| Case 101 | appends to `_get_mag_main[]` (primary mags) | Client_GetParsedGear.sqf:47 |
| Backpack fold | if `!isNull _unit && _get_backpack != ""`, `_get_backpack_content = _unit Call WFBE_CL_FNC_GetBackpackContent`; else stays `[[[],[]],[[],[]]]` | Client_GetParsedGear.sqf:52-53 |
| Return | 9-tuple `[prim, seco, hand, backpack, spec[], misc[], mag_main[], mag_seco[], backpack_content]` | Client_GetParsedGear.sqf:55 |

Call sites: `GUI_BuyGearMenu.sqf:84` (with `_target` for backpack fold), `:177` and `:308` (2-arg form, no backpack content).

## WFBE_CL_FNC_GetGearCargoSize

Computes the **backpack's** free capacity against the backpack's own `transportMax*` config, given an existing cargo loadout. Backpacks count weapon vs. magazine slots; equipment/misc (codes 4/5) are charged against the *magazine* budget.

| Aspect | Detail | Cite |
|---|---|---|
| Params | `[_unit, _existing_content]` (`_unit` = backpack classname) | Client_GetGearCargoSize.sqf:11-12 |
| Limits read | `transportMaxMagazines` → `_limit_mag`; `transportMaxWeapons` → `_limit_wep` (from `CfgVehicles >> _unit`) | Client_GetGearCargoSize.sqf:14-15 |
| Loop | `_i` 0..2 over the existing-content buckets; prefix `"Mag_"` only when `_i == 1` | Client_GetGearCargoSize.sqf:23-29 |
| PR8 guard | accumulates only if `!isNil _get && typeName _get == "ARRAY" && count _get > 5` (well-formed descriptor before `_get select 4/5`; the comment marks it as the HC gear-cargo RPT cascade source) | Client_GetGearCargoSize.sqf:30 |
| Size math | `_size += (_get select 5) * (_count select _j)` | Client_GetGearCargoSize.sqf:31 |
| Mag bucket | when `_i == 1`, add to `_m`/`_size_m` | Client_GetGearCargoSize.sqf:32-34 |
| Weapon bucket | when `_i != 1`, code in `[4,5]` charges `_m`/`_size_m`, otherwise `_w`/`_size_w` | Client_GetGearCargoSize.sqf:36 |
| Room flags | `_roomfor_mag = _m < _limit_mag`; `_roomfor_wep = _w < _limit_wep` | Client_GetGearCargoSize.sqf:43-44 |
| Return | `[_limit_mag - _size, _roomfor_mag, _roomfor_wep, _size_w, _size_m, _w, _m]` | Client_GetGearCargoSize.sqf:46 |

Note the free-size element (index 0) is `_limit_mag - _size`, i.e. the *magazine* limit minus the *total* accumulated size, not a per-category remainder. Consumers read index 0 (free size), index 1 (room-for-mag), index 2 (room-for-wep): `GUI_BuyGearMenu.sqf:265-266` gates an add on `_returned select 2 && (_returned select 0) >= (_get select 5)` for weapons (`_belong < 4`) and `_returned select 1` for mags/items (`_belong > 3`). Call sites: `GUI_BuyGearMenu.sqf:263,354,381`.

## WFBE_CL_FNC_GetVehicleCargoSize

Computes a **vehicle's** free capacity. Unlike the backpack getter, vehicles have three independent budgets (backpacks/magazines/weapons) and this function returns slot **counts**, not size weight.

| Aspect | Detail | Cite |
|---|---|---|
| Params | `[_unit, _existing_content]` (`_unit` = vehicle classname) | Client_GetVehicleCargoSize.sqf:11-12 |
| Limits read | `transportMaxBackpacks` → `_limit_bak`; `transportMaxMagazines` → `_limit_mag`; `transportMaxWeapons` → `_limit_wep` | Client_GetVehicleCargoSize.sqf:14-16 |
| PR8 guard | requires `!isNil _get && typeName _get == "ARRAY" && count _get > 4` before `_get select 4` | Client_GetVehicleCargoSize.sqf:27 |
| Bucketing | `switch (true)`: codes `[4,5,100,101]` → magazine `_m`; code `< 4` → weapon `_w`; codes `[200,201]` → backpack `_b` | Client_GetVehicleCargoSize.sqf:28-32 |
| Return | `[_limit_wep - _w, _limit_mag - _m, _limit_bak - _b, _w, _m, _b]` (remaining weapon/mag/bag slots, then used counts) | Client_GetVehicleCargoSize.sqf:38 |

The bucket order differs from `GetGearCargoSize`: here equipment/misc (4/5) and *both* magazine codes (100/101) fall into the magazine budget; weapons are everything with code `< 4`; backpacks (200/201) get their own budget. Call sites: `GUI_BuyGearMenu.sqf:278,364,390`, always with `typeOf (vehicle _target)`.

## WFBE_CL_FNC_GetMagazinesSize

Sums the descriptor size (`[5]`) of a flat magazine list. Used to keep the main/handgun magazine pools under their fixed caps.

| Aspect | Detail | Cite |
|---|---|---|
| Params | `_this` = a flat list of magazine classnames | Client_GetMagazinesSize.sqf:3-4 |
| Per item | `_get = missionNamespace getVariable Format["Mag_%1",_x]`; `_size += (_get select 5)` | Client_GetMagazinesSize.sqf:12,15 |
| Guard | `if !(isNil '_x')` — note this guards the **input element** `_x`, not the looked-up `_get`; a missing `Mag_` descriptor would still throw on `_get select 5` | Client_GetMagazinesSize.sqf:14-15 |
| Return | scalar `_size` | Client_GetMagazinesSize.sqf:19 |

Call sites: `Client_ReplaceMagazinesGear.sqf:52-53` (size-bounded magazine swap) and `GUI_BuyGearMenu.sqf:44-45,254-255,349-350`, where pool caps are checked against literal limits (`<= 8` for the handgun pool, `<= 12` for the main pool — `GUI_BuyGearMenu.sqf:254-255`).

## Raw cargo readers

These three pull live engine cargo state; the size getters above operate on their output.

### WFBE_CL_FNC_GetBackpackContent

| Aspect | Detail | Cite |
|---|---|---|
| Params | `_this` = unit | Client_GetBackpackContent.sqf:3 |
| Body | if `!isNull (unitBackpack _this)`: `set[0]=getWeaponCargo(unitBackpack)`, `set[1]=getMagazineCargo(unitBackpack)` | Client_GetBackpackContent.sqf:11-13 |
| Return | `[weaponCargo, magazineCargo]`, each `[items, counts]`; default `[[],[]]` | Client_GetBackpackContent.sqf:9,16 |

### WFBE_CL_FNC_GetVehicleContent

Reads all three vehicle cargo channels and **strips items with no `missionNamespace` descriptor** (so unknown/un-priced classes never reach the sizing math).

| Aspect | Detail | Cite |
|---|---|---|
| Params | `_this` = vehicle | Client_GetVehicleContent.sqf:3 |
| Channels | `forEach [[getWeaponCargo, ""], [getMagazineCargo, "Mag_"], [getBackpackCargo, ""]]` | Client_GetVehicleContent.sqf:30 |
| Nil-strip | for each item, `if (isNil {missionNamespace getVariable Format["%1%2",_prefix,_items select _i]})` → mark slot `false` | Client_GetVehicleContent.sqf:21 |
| Compaction | `_items = _items - [false]; _count = _count - [false]` | Client_GetVehicleContent.sqf:24-25 |
| Guard | whole body wrapped in `if (alive _this)` | Client_GetVehicleContent.sqf:11 |
| Return | `[[weps,counts],[mags,counts],[bags,counts]]`; default `[[],[],[]]` | Client_GetVehicleContent.sqf:9,33 |

The `Vehicle-Cargo-Equip-Loop-Bounds` page audits this function's `count(_items)-1` loop bound as a separate concern; here it is documented as a descriptor reader.

### WFBE_CL_FNC_GetUnitBackpack

One-liner script-friendly wrapper.

| Aspect | Detail | Cite |
|---|---|---|
| Params | `_this` = unit | Client_GetUnitBackpack.sqf:3 |
| Body / Return | `if !(isNull(unitBackpack _this)) then {typeOf(unitBackpack _this)} else {""}` | Client_GetUnitBackpack.sqf:7 |

Call sites: `GUI_BuyGearMenu.sqf:17,82`, and `WASP/actions/SkinSelector/SkinSelector_CopyGear.sqf:20`.

## Cross-function notes

- **Two distinct slot taxonomies.** `GetGearCargoSize` (backpack) charges equipment/misc (4/5) to the magazine budget and has no backpack bucket; `GetVehicleCargoSize` adds a third backpack budget and lumps 100/101 into magazines too. Do not assume one mapping covers both — they are coded independently (`Client_GetGearCargoSize.sqf:36` vs. `Client_GetVehicleCargoSize.sqf:28-32`).
- **PR8 well-formed-descriptor guards** (`count _get > 5` for gear, `count _get > 4` for vehicle) exist to stop a headless-client RPT cascade where a `_get select 4/5` ran against a missing or malformed descriptor. They are present only in the two *sizing* functions; `GetParsedGear` and `GetMagazinesSize` still rely on `isNil` checks alone (`Client_GetParsedGear.sqf:27,44`, `Client_GetMagazinesSize.sqf:14`).
- **Vanilla degradation.** Under `WF_A2_Vanilla`, `GetBackpackContent`/`GetVehicleContent`/`GetUnitBackpack` return empty stubs (`Init_Client.sqf:117,132-133`), so `GetParsedGear`'s backpack fold yields the empty `[[[],[]],[[],[]]]` and capacity math sees no backpack cargo.

## Continue Reading

- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — the buy-gear UI flow and EASA loadout arrays these descriptors feed
- [Gear-Store-Catalog-Per-Faction](Gear-Store-Catalog-Per-Faction) — the producer side that writes the `[4]`/`[5]` descriptor fields
- [Vehicle-Cargo-Equip-Loop-Bounds](Vehicle-Cargo-Equip-Loop-Bounds) — the loop-bounds audit of `GetVehicleContent`
- [Vehicle-Equip-And-Rearm-Function-Reference](Vehicle-Equip-And-Rearm-Function-Reference) — the rearm/equip side of vehicle cargo
- [Config-Lookup-Helper-Reference](Config-Lookup-Helper-Reference) — the `missionNamespace`/config helper conventions these readers use
