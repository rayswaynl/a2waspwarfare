# Defense Category And Budget Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Player- and commander-placed base defenses are not free-for-all: each placement is sorted into one of four budget categories, and the server enforces a per-category live-object cap; fortification and mine caps scale with barracks level while the statics cap is a flat constant. This page documents the two halves of that mechanism — the categorizer `WFBE_CO_FNC_GetDefenseCategory` (`Common/Functions/Common_GetDefenseCategory.sqf`) and its sole consumer, the `RequestDefense` server handler (`Server/PVFunctions/RequestDefense.sqf`) — plus the tuning constants in `Common/Init/Init_CommonConstants.sqf` that set the caps and gate thresholds. This is the *contract and gate logic*, distinct from `Defense-Structures-Catalog`, which lists the actual defense classnames and their prices.

The whole gate layer is opt-in behind one constant: `WFBE_C_DEFENSE_BUDGET` (`Common/Init/Init_CommonConstants.sqf:583`, default `1`). When it is `0`, `RequestDefense` builds exactly as it did before the budget feature existed (`Server/PVFunctions/RequestDefense.sqf:298-305`).

## WFBE_CO_FNC_GetDefenseCategory — the categorizer

Registered as `WFBE_CO_FNC_GetDefenseCategory = Compile preprocessFileLineNumbers "Common\Functions\Common_GetDefenseCategory.sqf"` (`Common/Init/Init_Common.sqf:172`).

| Aspect | Detail | Citation |
|---|---|---|
| Parameters | `_this select 0` = classname (String), `_this select 1` = side (Side) | `Common/Functions/Common_GetDefenseCategory.sqf:24-25` |
| Returns | One of `"STATICS"`, `"FORTIFICATIONS"`, `"MINES"`, `"OTHER"` (String) | `Common/Functions/Common_GetDefenseCategory.sqf:17` |
| Default | `_cat = "OTHER"` — anything unmatched is OTHER and **uncapped in v1** | `Common/Functions/Common_GetDefenseCategory.sqf:62`, `:106-108` |
| Side use | Side is stringified (`str _side`) only to build the faction static-array variable names | `Common/Functions/Common_GetDefenseCategory.sqf:72` |

### Classification order

The function returns on the first match, evaluated top to bottom:

| Order | Category | Test | Citation |
|---|---|---|---|
| 1 | MINES | `_cls == "Sign_Danger"` (the mine-field placer; faction-neutral) | `Common/Functions/Common_GetDefenseCategory.sqf:67` |
| 2 | STATICS | `_cls in _staticsList` (faction arrays) **or** substring match on the crewable-weapon needle list | `Common/Functions/Common_GetDefenseCategory.sqf:86`, `:91-98` |
| 3 | FORTIFICATIONS | substring match on the barrier/wire/wall needle list | `Common/Functions/Common_GetDefenseCategory.sqf:103` |
| 4 | OTHER | fall-through (ammo crates, MASH, lights, spawn markers) | `Common/Functions/Common_GetDefenseCategory.sqf:108` |

### STATICS resolution

The faction-specific static-weapon arrays are read by name from `missionNamespace` and concatenated into one list (`Common/Functions/Common_GetDefenseCategory.sqf:73-80`):

```
WFBE_<side>DEFENSES_MG / _GL / _AAPOD / _ATPOD / _CANNON / _MORTAR
```

These are populated per-faction in the Core_Structures config files — e.g. `WFBE_<side>DEFENSES_MG = ['M2StaticMG_US_EP1']` (`Common/Config/Core_Structures/Structures_CO_US.sqf:229`), `['KORD_high_TK_EP1']` for RU (`Common/Config/Core_Structures/Structures_CO_RU.sqf:227`), `['DSHKM_CDF']` for CDF (`Common/Config/Core_Structures/Structures_CDF.sqf:158`). Any classname found in the merged list sets `_isStatic = true` (`Common/Functions/Common_GetDefenseCategory.sqf:86`).

Classnames **not** in the faction arrays (e.g. sandbag MG nests, or any other faction's gun reused) get a second pass: a substring scan over a fixed needle list of crewable-weapon tokens (`Common/Functions/Common_GetDefenseCategory.sqf:93`):

```
mgnestt, mgbag, mgnest, m2staticmg, kord, dshkm, zu23, ags, mk19, tow,
stinger, igla, metis, spg9, m252, 2b14, m119, d30, mlrs,
baf_gpmg, baf_gmg, baf_l2a1, m2hd, m1129
```

A match here also sets `_isStatic = true`; if static, the function exits `"STATICS"` (`Common/Functions/Common_GetDefenseCategory.sqf:94`, `:98`). The searchlight is deliberately left as OTHER because it is non-crewable for combat (`Common/Functions/Common_GetDefenseCategory.sqf:90`).

### FORTIFICATIONS resolution

A single substring pass over the barrier/obstacle needle list returns `"FORTIFICATIONS"` (`Common/Functions/Common_GetDefenseCategory.sqf:103`):

```
hbarrier, barrier5x, barrier10x, bagfence, razorwire, hedgehog, hhedgehog,
camonet, camo_net, fort_rampart, fort_artillery, fortified_nest,
concrete_wall, cncblock
```

### Two defensive guards (both from live incidents)

| Guard | What it does | Why | Citation |
|---|---|---|---|
| `_matchAny` substring matcher | Hand-rolled `toArray`-based substring search; `_this = [haystackLower, [needle, ...]]`, returns a Boolean | `find` on a *String* is an Arma 3 command; on A2 OA it throws "Type String, expected Array" and killed the calling script (RequestDefense mid-purchase, live-burned 2026-06-11) | `Common/Functions/Common_GetDefenseCategory.sqf:31-55`, comment `:27-30` |
| nil/non-string entry guard | `if (isNil "_cls" || {typeName _cls != "STRING"}) exitWith {"OTHER"}` | A caller passed a nil/non-string classname → "Undefined variable _cls" at the `toLower`; an unhandled abort here can swallow a placement mid-gate (live RPT 2026-06-10) | `Common/Functions/Common_GetDefenseCategory.sqf:60`, comment `:57-59` |

The `_matchAny` block uses only A2-safe constructs (`toArray`, `count`, `forEach`, `for`, `exitWith`), and all callers lowercase the haystack before passing it (`Common/Functions/Common_GetDefenseCategory.sqf:93`, `:103`).

## RequestDefense — the consumer

`RequestDefense.sqf` is the server PVF handler that fires when a client requests a base defense. Its signature (`Server/PVFunctions/RequestDefense.sqf:1-8`): `[_side, _defenseType, _pos, _dir, _manned, _builtByRepairTruck?, _reqPlayer?]`. The trailing two args are optional (default `false` / `objNull`) to stay compatible with the EASA repair-truck merge.

The handler only proceeds if `_defenseType` resolves in the side's `WFBE_<side>DEFENSENAMES` list (`Server/PVFunctions/RequestDefense.sqf:11-12`). It then enters the budget/threat gate only when `WFBE_C_DEFENSE_BUDGET > 0` (`Server/PVFunctions/RequestDefense.sqf:24`).

### Gate pipeline (inside-base only)

| Step | Logic | Citation |
|---|---|---|
| A. Base-center detection | Mirrors the RequestStructure bank pattern: collect `getPos` of `wfbe_startpos` + each `wfbe_basearea` from the side logic; nearest center within `WFBE_C_BASE_AREA_RANGE` (default 250) → `_isInsideBase` | `Server/PVFunctions/RequestDefense.sqf:43-60` |
| (gate skip) | If **not** inside a base area, budget does not apply — build immediately | `Server/PVFunctions/RequestDefense.sqf:289-296` |
| B1. Barracks level | `_barrackLvl = _upgrades select WFBE_UP_BARRACKS` (index `0`) | `Server/PVFunctions/RequestDefense.sqf:70-72` |
| B2. Anchor vs single | If `_defenseType` is in `WFBE_POSITION_ANCHOR_NAMES`, expand to ALL template children (resolved via `WFBE_POSITION_TEMPLATE_MAP` + optional `_WEST`/`_EAST` suffix); else `_clsToCheck = [_defenseType]` | `Server/PVFunctions/RequestDefense.sqf:79-108` |
| B3. Threat gate | See below | `Server/PVFunctions/RequestDefense.sqf:116-141` |
| B3b. Composition cap | Anchors only — see below | `Server/PVFunctions/RequestDefense.sqf:152-168` |
| B4. Budget cap | Single defenses only — see below | `Server/PVFunctions/RequestDefense.sqf:179-240` |
| B5. Reject + refund / build | See refund section | `Server/PVFunctions/RequestDefense.sqf:245-287` |

### B3 — Threat gate

The handler classifies every entry in `_clsToCheck` with `WFBE_CO_FNC_GetDefenseCategory`; if any is `STATICS` or `MINES`, the placement is threat-gated (`Server/PVFunctions/RequestDefense.sqf:119-122`). Fortifications and OTHER are never threat-gated (`Server/PVFunctions/RequestDefense.sqf:112-114`).

When gated, it counts enemy ground units near the base center and rejects if the count meets `WFBE_C_DEFENSE_THREAT_MIN` (default 3):

- Enemy side = `[west, east] - [_side]` (no ambient GUER) (`Server/PVFunctions/RequestDefense.sqf:131`).
- Counted classes = `["Man","Car","Motorcycle","Tank"]` (no Air) within `_baseRange` (`Server/PVFunctions/RequestDefense.sqf:134`).
- Threshold check at `Server/PVFunctions/RequestDefense.sqf:137`; the 2026-06-10 play-test rationale (the original any-1-enemy/any-class gate near-permanently blocked placement; ambient resistance AI and overflights counted as a "raid") is in the comment at `:126-130`.

### B3b — WDDM composition cap

Anchors only. Counts distinct `WFBE_WDDMPositionAnchor` placement-IDs on nearby defense objects; rejects with `_rejCat = "WddmCompositionCapReached"` once the distinct count reaches `WFBE_C_WDDM_COMP_CAP` (default 3, size-independent) (`Server/PVFunctions/RequestDefense.sqf:152-167`).

### B4 — Per-category budget caps

Single (non-anchor) defenses only; WDDM composition children are exempt here (their cap is B3b). The pending placement is classified, then existing live, non-child objects of the same category are counted near the base center via `nearestObjects`, and the request is rejected if `existing + pending > cap` (`Server/PVFunctions/RequestDefense.sqf:179-235`).

| Category | Cap formula | Default | Reject label | Citation |
|---|---|---|---|---|
| STATICS | `WFBE_C_BASE_DEFENSE_STATICS_CAP` (flat) | 25 | `Statics` | `Server/PVFunctions/RequestDefense.sqf:193`, `:227-228` |
| FORTIFICATIONS | `20 + 10 * _barrackLvl` | 20 (lvl 0) | `Fortifications` | `Server/PVFunctions/RequestDefense.sqf:194`, `:230-231` |
| MINES | `10 + 5 * _barrackLvl` | 10 (lvl 0) | `Mines` | `Server/PVFunctions/RequestDefense.sqf:195`, `:233-234` |

The existing-count loops skip any object flagged `WFBE_WDDMPositionChild` so composition pieces never consume single-defense budget slots (`Server/PVFunctions/RequestDefense.sqf:213`, `:218`, `:223`).

### B5 — Reject + refund

If either gate fired and `_reqPlayer` is alive, the player is refunded (defenses are charged optimistically on the client at placement). The server first tries to price the defense server-side via `missionNamespace getVariable _defenseType` then `select QUERYUNITPRICE` (index `2`, `Common/Init/Init_CommonConstants.sqf:8`) (`Server/PVFunctions/RequestDefense.sqf:249-252`).

| Case | Message sent | Refund arg | Citation |
|---|---|---|---|
| Price resolved, threat reject | `["DefenseThreatGate", _defPrice]` | number | `Server/PVFunctions/RequestDefense.sqf:255-256` |
| Price resolved, comp-cap reject | `["WddmCompositionCapReached", _rejUsed, _rejCap, _defenseType]` | — | `Server/PVFunctions/RequestDefense.sqf:258-259` |
| Price resolved, budget reject | `["DefenseBudgetFull", _rejCat, _rejUsed, _rejCap, _defPrice]` | number | `Server/PVFunctions/RequestDefense.sqf:260-261` |
| Price NOT resolvable (WDDM anchors) | same keys but pass `_defenseType` **classname** so the client refunds via its own lookup | classname string | `Server/PVFunctions/RequestDefense.sqf:264-277` |

The classname-fallback exists because anchors lost their 2,500–5,000 cash on threat reject when the server could only notify with `0` (`Server/PVFunctions/RequestDefense.sqf:265-267`). The client-side `LocalizeMessage` handler accepts either a number (refund directly) or a classname string (look up `select QUERYUNITPRICE` and refund the exact amount it charged) for both `DefenseBudgetFull` (`Client/PVFunctions/LocalizeMessage.sqf:132-144`) and `DefenseThreatGate` (`Client/PVFunctions/LocalizeMessage.sqf:165-178`); the `WddmCompositionCapReached` branch always refunds via the anchor classname lookup (`Client/PVFunctions/LocalizeMessage.sqf:147-156`).

When all gates pass, the build dispatches: anchors → `Server_ConstructPosition` (Spawn), single defenses → `ConstructDefense` (Call) with the manning range and repair-truck flag (`Server/PVFunctions/RequestDefense.sqf:280-287`).

## Tuning constants

| Constant | Default | Meaning | Citation |
|---|---|---|---|
| `WFBE_C_DEFENSE_BUDGET` | 1 | Master switch for the whole gate layer | `Common/Init/Init_CommonConstants.sqf:583` |
| `WFBE_C_BASE_DEFENSE_STATICS_CAP` | 25 | Flat STATICS cap per base area (raised from 10) | `Common/Init/Init_CommonConstants.sqf:584` |
| `WFBE_C_DEFENSE_THREAT_MIN` | 3 | Min enemy ground units to fire the statics/mines threat gate | `Common/Init/Init_CommonConstants.sqf:585` |
| `WFBE_C_WDDM_COMP_CAP` | 3 | Max distinct WDDM compositions per base area | `Common/Init/Init_CommonConstants.sqf:586` |
| `WFBE_C_BASE_AREA_RANGE` | 250 | Base-area radius (meters) for detection, threat, and counting | `Common/Init/Init_CommonConstants.sqf:251` |
| `WFBE_C_BASE_DEFENSE_MANNING_RANGE` | 250 | Manning range passed to `ConstructDefense` | `Common/Init/Init_CommonConstants.sqf:241` |

## Continue Reading

- [Defense-Structures-Catalog](Defense-Structures-Catalog) — the defense classnames, prices, and content this gate categorizes
- [Construction-And-CoIn-Systems-Atlas](Construction-And-CoIn-Systems-Atlas) — where RequestDefense sits in the build-request flow
- [Server-Composition-Spawner-Function-Reference](Server-Composition-Spawner-Function-Reference) — Server_ConstructPosition and WDDM composition spawning
- [PVF-Dispatch-Implementation-Playbook](PVF-Dispatch-Implementation-Playbook) — how PVF handlers like RequestDefense are wired and dispatched
- [Bank-Reserve-And-Artillery-Radar-Structures](Bank-Reserve-And-Artillery-Radar-Structures) — the base-center detection pattern RequestDefense mirrors
