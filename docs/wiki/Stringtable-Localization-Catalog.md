# Stringtable Localization Key-Family Catalog (prefixes, languages, structure)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page maps the **taxonomy** of `stringtable.xml` (9608 lines) — its XML envelope, the language column set, the key-family prefixes, the section-banner / `shared U`/`shared W` comment convention, and how keys are referenced from code. It is a structural reference, **not** a key dump: it does not enumerate the 1344 keys. For drift/missing-key integrity findings (e.g. `STR_Supplies_2`, hardcoded-English, missing param keys), see the localization sections of [Mission parameters localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) and [Assets config localization and parameters atlas](Assets-Config-Localization-And-Parameters-Atlas) — this page does not duplicate them.

## XML Envelope

The whole file is one container. The four envelope tags are opened at the top and closed at the bottom (`stringtable.xml:2-4`, `stringtable.xml:9606-9608`).

| Level | Element | Line |
| --- | --- | --- |
| 1 | `<Project name="Arma2">` | `stringtable.xml:2` |
| 2 | `<Package name="CWarfare">` | `stringtable.xml:3` |
| 3 | `<Container name="WF">` | `stringtable.xml:4` |
| 3 close | `</Container>` | `stringtable.xml:9606` |
| 2 close | `</Package>` | `stringtable.xml:9607` |
| 1 close | `</Project>` | `stringtable.xml:9608` |

Every entry is a `<Key ID="...">` element holding one child per language, closed by `</Key>`. There are exactly **1344** opening `<Key ID=` and **1344** `</Key>` tags (balanced). The canonical key shape — five language children — is the `STR_WF_DEBUG` entry at `stringtable.xml:9-15`:

```xml
<Key ID="STR_WF_DEBUG"><!--shared W-->
   <English>DEBUG</English>
    <French>DEBUG</French>
    <German>DEBUG</German>
    <Russian>DEBUG</Russian>
    <Italian>DEBUG</Italian>
  </Key>
```

## Language Column Set

The active column set is **five languages**: English, French, German, Russian, Italian. English is the only column present on all 1344 keys; the others trail slightly where translations were never filled in.

| Language tag | Keys carrying it | Source |
| --- | --- | --- |
| `<English>` | 1344 (every key) | `stringtable.xml:10` |
| `<Russian>` | 1319 | `stringtable.xml:13` |
| `<French>` | 1303 | `stringtable.xml:11` |
| `<German>` | 1303 | `stringtable.xml:12` |
| `<Italian>` | 1303 | `stringtable.xml:14` |
| `<Spanish>` | 10 (partial late additions) | `stringtable.xml:94,102,413,9327,9336,9345,9354,9363,9388` |

Spanish is **not** a full column: it was added to only ~10 keys (the team-balance chat strings and the late "guided-bomb / missile-launch" block near the end of the file), e.g. `STR_WF_CHAT_Teamstack` carries a `<Spanish>` line at `stringtable.xml:94`.

Four further language tags (`<Original>`, `<Czech>`, `<Polish>`, `<Portuguese>`) each appear **exactly once** — all inside a single `str_bipod` key that is **commented out** and therefore dead. The block is wrapped in `<!-- ... -->` from its opening to its `</Key>` (`stringtable.xml:62-73`); treat those four tags as non-functional and do not model the table on them.

## Key-Family Taxonomy (by prefix)

Prefixes are derived by bucketing all 1344 `<Key ID=` values. The dominant namespace is `STR_WF_*` (Warfare). A small legacy block uses bare `STR_*` / `str_*` prefixes inherited from upstream BECTI2. Counts are approximate family rollups (a key can match only one bucket below; sub-prefixes like `STR_WF_INFO_*` are pulled out of the generic `STR_WF_*` bucket first).

| Family prefix | Approx. count | What it labels | Representative key (with English) | Source |
| --- | --- | --- | --- | --- |
| `STR_WF_*` (other / uncategorized) | ~228 | Catch-all Warfare strings not in a named sub-family | `STR_WF_DEBUG` → "DEBUG" | `stringtable.xml:9-15` |
| `STR_WF_PARAMETER_*` | ~201 | Mission-parameter labels/values (lobby params) | `STR_WF_PARAMETER_FPS` → "WAYPOINTS BY CLIENT(CLASSIC ONLY)" | `stringtable.xml:1385` |
| `STR_WF_RU_*` | ~175 | EAST (RU) faction unit / vehicle / crew-slot names | `STR_WF_RU_B1` → "Driver" | `stringtable.xml:5748` |
| `STR_WF_US_*` | ~153 | WEST (US) faction unit / vehicle / crew-slot names | `STR_WF_US_B1` → "Driver" | `stringtable.xml:5022` |
| `STR_WF_UK_*` | ~139 | BAF (UK) faction unit / vehicle / crew-slot names | `STR_WF_UK_B1` → "Driver" | `stringtable.xml:5424` |
| `STR_WF_ALL_*` | ~101 | Side-agnostic unit/defense content shared by all factions | `STR_WF_ALL_L1` → "Medic Container [SPAWN]" | `stringtable.xml:6171` |
| `STR_WF_INFO_*` | ~55 | Information / status hint messages | `STR_WF_INFO_BaseArea_Reached` → "Information:\n\n You've reached the bases area limit..." | `stringtable.xml:835` |
| `STR_WF_UPGRADE_*` | ~45 | COIN upgrade names and descriptions | `STR_WF_UPGRADE_Defense_Desc` → "This upgrade improves static defenses..." | `stringtable.xml:50` |
| `STR_WF_TOOLTIP_*` | ~44 | Dialog button / control tooltips | `STR_WF_TOOLTIP_ArtilleryToggle` → "This icon allows you to toggle between the different artillery display mode on the map" | `stringtable.xml:3423` |
| `STR_WF_CHAT_*` | ~41 | System chat / sidechat messages | `STR_WF_CHAT_Teamstack` → "You are not allowed to join this team to guarantee balanced teams..." | `stringtable.xml:88` |
| `STR_WF_COMMAND_*` | ~26 | Command-menu labels | `STR_WF_COMMAND_All` → "All" | `stringtable.xml:474` |
| `STR_WF_TACTICAL_*` | ~24 | Tactical-menu / artillery-display labels | `STR_WF_TACTICAL_ArtilleryStatus` → "Status:" | `stringtable.xml:3157` |
| `STR_UAV_*` | ~22 | UAV interface labels (mission-local subset) | `STR_UAV_Title` → "UAV" | `stringtable.xml:2391` |
| `STR_HINT_*` | ~15 | Field-repair / action hint text | `STR_HINT_FieldAllready` → "Vehicle is allready being repaired.." | `stringtable.xml:2195` |
| `STR_ACT_*` | ~9 | Addaction labels | `STR_ACT_FieldRepair` → "Field repairs" | `stringtable.xml:2300` |
| `str_coin_*` | ~9 | COIN-menu UI strings (lowercase legacy) | `str_coin_back` → "BACK=" | `stringtable.xml:4350` |
| `STR_WASP_actions_*` | ~3 | WASP-mod action labels (wheel-change / repair) | `STR_WASP_actions_fastrep` → "Light repair" | `stringtable.xml:167` |
| Mixed remainder (bare keys, no `STR_WF_` prefix) | ~50 | A mixed bucket: ~22 bare `STR_*` legacy strings (`STR_Summary`, `STR_Voting`, `STR_Commander`, `STR_Team`, `STR_Supplies`, `STR_Upgrades`, paired `*_2` variants), plus ~26 modern Warfare/WDDM gameplay messages with no `STR_` prefix at all — `RB_*` rebuild-building names (x12, `RB_Barracks`), `Bank*` (x4, `BankAlreadyBuilt`), `SiteClearance*` (x6, `SiteClearanceDone`), and singletons (`WddmCompositionCapReached`, `CBRadarNeedsAAR`, `DefenseBudgetFull`, `DefenseThreatGate`) | `STR_Summary` → "Summary" | `stringtable.xml:74` |

Smaller `STR_WF_*` sub-families also exist (e.g. `STR_WF_UNITS_*`, `STR_WF_TEAM_*`, `STR_WF_MAIN_*`, `STR_WF_GEAR_*`, `STR_WF_END_*`, `STR_WF_RESPAWN_*`, `STR_WF_SERVICE_*`, `STR_WF_VOTING_*`, `STR_WF_EASA_*`, `STR_WF_SCUD_*`, `STR_WF_Repair_*`, `STR_WF_SkinSelector_*`); each is fewer than ~15 keys and rolls into the generic `STR_WF_*` bucket above.

### Engine-resolved prefixes are NOT defined here

The mission also references `$STR_DN_*` and `localize "STR_EP1_*"` keys, but these resolve from the **base game** (A2 / Operation Arrowhead) stringtables, not this file. This file defines **zero** `STR_EP1_*` keys and only **one** `STR_DN_*` key (`STR_DN_BMP_HQ` → "BMP (Terminal)", `stringtable.xml:2384-2390`); the others such as `STR_DN_WARFARE_HQ_BASE_UNFOLDED` (referenced at `Client/kb/hq.bikb:34`) and `STR_EP1_UAV_action_exit` (referenced at `Client/Module/UAV/uav_interface_oa.sqf:25`) are inherited from the engine. Do not add them here.

## Comment Convention

### Section banners

The file is organized into blocks each opened by a banner comment. Most early blocks are marked `... - ALL DONE` (translation-complete); the late unit/vehicle/defense blocks carry `... BECTI2 stuff` (lineage markers from the upstream BECTI2 codebase). Banners appear in document order, for example:

| Banner | Line | Banner | Line |
| --- | --- | --- | --- |
| `<!--COIN Upgrade Strings - ALL DONE-->` | `stringtable.xml:7` | `<!--PARAMETER Strings - ALL DONE-->` | `stringtable.xml:1362` |
| `<!--ACTION Strings - ALL DONE-->` | `stringtable.xml:61` | `<!--TOOLTIP Strings - ALL DONE-->` | `stringtable.xml:3422` |
| `<!--CHAT Strings - ALL DONE-->` | `stringtable.xml:252` | `<!--Upgrade Menu - ALL DONE-->` | `stringtable.xml:3843` |
| `<!--Command Menu - ALL DONE-->` | `stringtable.xml:473` | `<!--MAP Description - ALL DONE-->` | `stringtable.xml:4628` |
| `<!--INFO Strings - ALL DONE-->` | `stringtable.xml:834` | `<!--new BECTI2 stuff -->` | `stringtable.xml:4992` |
| `<!--Main Menu - ALL DONE-->` | `stringtable.xml:1203` | `<!--US BARRACKS UNITS BECTI2 stuff -->` | `stringtable.xml:5020` |

The `BECTI2 stuff` banners further sub-divide by faction and role (`US/UK/RU/ALL/BLU` × `BARRACKS/LIGHT/HEAVY/AIR/TOWNCARS/TOWNFIGHTER` × `UNITS`, plus `COIN DEFENSES/FORTIFICATION/STRATEGIC/AMMO`), e.g. `<!--RU AIR UNITS BECTI2 stuff -->` (`stringtable.xml:7897`), `<!--ALL COIN STRATEGIC BECTI2 stuff -->` (`stringtable.xml:8702`).

### Inline status / ownership comments

Individual keys carry trailing inline comments that mark cross-faction reuse and translation status:

| Inline comment | Count | Meaning | Example source |
| --- | --- | --- | --- |
| `<!--shared U-->` | 71 | String reused across the **U** (US/UK-side) faction set | `STR_WF_US_B1` region (`stringtable.xml:5020+`) |
| `<!--shared W-->` | 42 | String reused across the **W** (Warfare-wide) set | `STR_WF_DEBUG` (`stringtable.xml:9`) |
| `<!--check-->` | 10 | Translation flagged for review | n/a (scattered) |
| `<!--need rework -0.71-->` | 4 | Marked for rework at the 0.71 revision | n/a (scattered) |
| `<!--shared-->` | 2 | Generic shared marker | n/a (scattered) |

## How Keys Are Referenced From Code

Two reference forms exist; both are valid Arma 2 OA syntax.

| Form | Where used | Mission count | Example |
| --- | --- | --- | --- |
| `localize "STR_..."` | SQF scripts | 218 callsites | `if (count _camps == 0) exitWith {hint (localize "STR_WF_Repair_Camp_None")};` (`Client/Action/Action_RepairCamp.sqf:22`) |
| `$STR_...` | Config / UI files (`.hpp`, `.bikb`) | 376 references | `tooltip = $STR_WF_TOOLTIP_BackButton;` (`Rsc/Dialogs.hpp:54`); `text = $STR_DN_WARFARE_HQ_BASE_UNFOLDED;` (`Client/kb/hq.bikb:34`) |

`localize` takes a string-literal key and returns the resolved text in the active language; the `$STR_...` macro form is substituted at config-bind time inside `.hpp` control definitions (`text`, `tooltip`, etc.) and `.bikb` conversation entries. A key that exists in neither this stringtable nor a base-game stringtable resolves to the literal key id at runtime (the integrity pages track such drift).

## Continue Reading

- [Mission parameters localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs)
- [Assets config localization and parameters atlas](Assets-Config-Localization-And-Parameters-Atlas)
- [Variable and naming conventions](Variable-And-Naming-Conventions)
- [Mission audio catalog](Mission-Audio-Catalog)
