# In-Game Briefing & Diary Field Manual (briefing.sqf + briefing.html)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the player-facing **documentation surface inside the game** — the text players actually read on the map screen and the mission-overview panel. It is distinct from the wiki's own player guides (those are written for readers off-server). Two artifacts make up this surface:

- **`briefing.sqf`** — populates the **Diary tab** on the map screen (Esc → Map → Notes/Diary) with ten records.
- **`briefing.html`** — the **mission-overview / load text** shown in the role-select and mission lobby panel, referenced by the Rsc header.

Because both files are hand-written prose, the economy numbers baked into them are **duplicated text that drifts** from the live mechanics. See [Hardcoded economy numbers — drift watch](#hardcoded-economy-numbers--drift-watch).

---

## 1. What this is and where it runs

The Diary is built client-side during client init. `Init_Client.sqf` compiles and runs `briefing.sqf` once, late in the init sequence (after the commander-update FSM is spawned):

```sqf
//--- Add the briefing (notes).
[] Call Compile preprocessFile "briefing.sqf";
```

`Client/Init/Init_Client.sqf:625-626`. Because it runs `player createDiaryRecord` against the local `player`, the Diary is per-client and rebuilt on every JIP/respawn pass through client init. See [Mission Entrypoints And Lifecycle](Mission-Entrypoints-And-Lifecycle) for where `Init_Client.sqf` itself is invoked.

The mission-overview text is supplied by `briefing.html`, wired through the Rsc header rather than `description.ext` directly:

```cpp
//--- Require briefing.html to show up.
onLoadMission = WF_MISSIONNAME;
onLoadMissionTime = false;
```

`Rsc/Header.hpp:8-10`, which `description.ext` pulls in via `#include "Rsc\Header.hpp"` (`description.ext:45`). `WF_MISSIONNAME` is `"[55] Warfare V48 Chernarus"` (`version.sqf.template:11`). The mission load image is `loadScreen = "loadScreen.jpg"` (`description.ext:63`). Respawn options live alongside the header: `respawn = 3; respawnDelay = WF_RESPAWNDELAY;` (`Rsc/Header.hpp:4-5`), with `WF_RESPAWNDELAY 2` (`version.sqf.template:14`).

See also [Player UI Workflow Map](Player-UI-Workflow-Map) and [New Player Quickstart Guide](New-Player-Quickstart-Guide) for the off-server reader equivalents.

---

## 2. Diary records table

Every `createDiaryRecord` in `briefing.sqf`, in source order. The form is `player createDiaryRecord["Diary", [<title>, <html-body>]]`. There are **ten** records.

| # | Title | Summary | Source line |
|---|-------|---------|-------------|
| 1 | Gameplay Summary | Warfare = team MP + RTS; each side led by a commander; two resources — Supply (build/upgrade factories) and Cash (buy units/gear). | `briefing.sqf:3` |
| 2 | Your Task | Three objectives: capture towns from resistance/enemy, destroy enemy base + HQ, defend your own. | `briefing.sqf:5` |
| 3 | Getting Started | WF menu = mouse scroll wheel; must be in a base perimeter or near a factory; factory letter codes (B/LF/HF/AF/SP); build CC for remote buy/artillery/upgrades, AAR to track aircraft and unlock the CBR. | `briefing.sqf:7` |
| 4 | Commander | Commander should be a player; lists commander powers (deploy/relocate HQ, build/sell from Construction Menu, research upgrades, buy WDDM compositions up to 3 per base, issue orders); save supply for CBR + Bank. | `briefing.sqf:9` |
| 5 | Capturing Towns | Take strongpoint bunkers first, then dominate the 50 m depot; strongpoints are respawn points in range; capture grace period (5 min before enemy AI respawn, 3 min for lingering defenders). | `briefing.sqf:11` |
| 6 | Building Bases (As Commander) | One Mobile HQ [MHQ] per side; deploy to build; can add B/LF/HF/AF/CC/AAR/SP; HQ packs/redeploys; multiple bases; defense budget capped per category (scales with barracks level); statics/mines blocked if 3+ enemy ground units in base range. | `briefing.sqf:13` |
| 7 | Experimental Changes | The big "Experital" feature dump — economy start values, Bank, CBR, airfields, capture-to-unlock premium units, patrols/convoys, factory queue, medic truck, classes. **Carries most of the hardcoded numbers** (see §4). | `briefing.sqf:15` |
| 8 | Experimental: AI & Factions | AI Commander takeover after 5 min with no human commander; GUER as a living third faction that escalates below 20 towns; clean captures (no captured statics from GUER); wildcard events; FPS performance telemetry (diagnostic only). | `briefing.sqf:17` |
| 9 | Mods | Suggests downloading/enabling the mods listed on Discord. | `briefing.sqf:18` |
| 10 | Our Discord | Discord invites (discord.me/warfare, backup discord.gg/knXvYMX), Patreon ask, FPS optimisation guide pointer. | `briefing.sqf:20` |

---

## 3. Formatting conventions

The Diary bodies are Arma structured-text HTML strings. The recurring conventions:

- **Highlight color** `<t color='#F5D363'>…</t>` — the gold/amber accent used to flag key terms (resource names, costs, feature names). Example: `There are two kinds of resources: <t color='#F5D363'>Supply</t> is used by the commander…` (`briefing.sqf:3`).
- **Sub-heading size bump** `<t size='1.2' color='#F5D363'>…</t>` — used as inline section headers inside the long records 7 and 8. Example: `<t size='1.2' color='#F5D363'>Economy</t>` (`briefing.sqf:15`).
- **Line breaks** `<br/>` and `<br/><br/>` — paragraph separation; every record body opens with a leading `<br/>` to pad below the title (`briefing.sqf:3-20`).

The same `#F5D363` gold is reused in `briefing.html` as a CSS span color (`<span style="color:#F5D363">Experital</span>`, `briefing.html:4`), keeping the two surfaces visually consistent.

---

## 4. Hardcoded economy numbers — drift watch

Records 7 (`briefing.sqf:15`) and 8 (`briefing.sqf:17`) hardcode live economy values as prose. These are **duplicated text, not reads of the real constants**, so they can — and already do — drift. Treat this whole section as a drift surface: verify against the authoritative pages before trusting any number here.

| Value (as written in briefing) | briefing.sqf cite | Where the real mechanic/constant lives |
|---|---|---|
| Start: **$11,600 cash, 7,400 supply** (both sides) | `briefing.sqf:15` | [Economy Authority First Cut](Economy-Authority-First-Cut), [Economy Towns And Supply](Economy-Towns-And-Supply) |
| Bank build cost **9,500 supply**, **>800 m** from HQ | `briefing.sqf:15` | [Bank Reserve And Artillery Radar Structures](Bank-Reserve-And-Artillery-Radar-Structures) |
| Bank payout **$6,000 total / 5 min** split among living members | `briefing.sqf:15` | [Bank Reserve And Artillery Radar Structures](Bank-Reserve-And-Artillery-Radar-Structures) |
| Bank destroy bounty **+$40,000 side supply, $25,000 to killer** | `briefing.sqf:15` | [Bank Reserve And Artillery Radar Structures](Bank-Reserve-And-Artillery-Radar-Structures) |
| CBR build cost **2,400 supply**, mark for **75 s**, requires AAR alive | `briefing.sqf:15` | [Counter Battery Radar System](Counter-Battery-Radar-System) |
| CBR Radar upgrade radii **750 → 1,500 → 2,000 m**; airfield grants permanent **2,000 m** CBR | `briefing.sqf:15` | [Counter Battery Radar System](Counter-Battery-Radar-System) |
| Airfields **max 40 SV; resets to 10 on capture** | `briefing.sqf:15` | [Economy Towns And Supply](Economy-Towns-And-Supply) |
| Krasnostav unlock: T-72, **Heavy Factory level 4, $7,000** | `briefing.sqf:15` | unit price tables / [Player UI Workflow Map](Player-UI-Workflow-Map) |
| NW Airfield unlock: RM-70, **Light Factory level 4, $6,800** | `briefing.sqf:15` | unit price tables / [Player UI Workflow Map](Player-UI-Workflow-Map) |
| Patrols upgrade supply cost **300 / 1,600 / 2,400 / 3,200** (4 levels), max **3** active, Convoy pays **$750** split per town stop | `briefing.sqf:15` | [Economy Towns And Supply](Economy-Towns-And-Supply) |
| Factory queue caps (floors): Barracks **10**, Light Factory **5**, Heavy/Aircraft **3**; cancel refund capped at **50%** with discount | `briefing.sqf:15` | [Factory Queue Counter Token Cleanup](Factory-Queue-Counter-Token-Cleanup) |
| Medic truck activates **≥500 m** from any non-friendly town | `briefing.sqf:15` | [Player UI Workflow Map](Player-UI-Workflow-Map) |
| AI Commander takeover after **5 min** with no human commander | `briefing.sqf:17` | [Commander HQ Lifecycle Atlas](Commander-HQ-Lifecycle-Atlas) |
| GUER escalates to BRDM-2 + 2nd patrol once **below 20 towns** | `briefing.sqf:17` | [GUER Insurgent Player Economy](GUER-Insurgent-Player-Economy) |
| Capture grace: **5 min** AI-respawn delay, **3 min** lingering-defender clear | `briefing.sqf:11` | [Respawn And Death Lifecycle Atlas](Respawn-And-Death-Lifecycle-Atlas) |

**Confirmed live drift between the two surfaces:** the Diary says the Bank pays **$6,000** per 5 minutes (`briefing.sqf:15`), while `briefing.html` says **$5,000** per 5 minutes (`briefing.html:19`). At least one of these two player-facing texts is stale. Do not treat either prose figure as authoritative — read the bank payout from [Bank Reserve And Artillery Radar Structures](Bank-Reserve-And-Artillery-Radar-Structures) and reconcile both texts to it.

This page intentionally does **not** re-verify every downstream constant; the cross-links above are the authoritative sources. The point is to mark that these numbers are mirrored prose and to give the maintainer the single-edit checklist when a mechanic value changes (update the constant **and** both briefing texts).

---

## 5. briefing.html — mission-overview text

`briefing.html` is the **mission-overview / lobby text**, surfaced through `onLoadMission = WF_MISSIONNAME` in the Rsc header (`Rsc/Header.hpp:9`). It is a small standalone HTML document (`<html><head><title>…</title></head><body>…`) titled "WASP Warfare Experital — Mission Briefing" (`briefing.html:2-4`).

Content is a condensed mirror of the Diary's experimental-changes block, organized under HTML headings:

- **Title + intro** — "WASP Warfare Experital — Chernarus", capture/build/destroy summary (`briefing.html:4-6`).
- **Resources** — Cash `$11,600`, Supply `7,400` start values (`briefing.html:8-10`).
- **Capturing Towns** — strongpoints, 50 m depot, grace period 5 min / 3 min (`briefing.html:12-14`).
- **Experital — Headline Changes** — Bank (`9,500` supply, `>800 m`, **`$5,000`/5 min**, `+$40,000`/`$25,000` destroy bounty, `briefing.html:18-19`), CBR (`2,400` supply, 75 s, radii 750/1,500/2,000 m, `briefing.html:21-22`), Airfields (`briefing.html:24-25`), Capture-to-Unlock units (T-72 `$7,000`, RM-70 `$6,800`, `briefing.html:27-30`), Patrols/Convoys (`300/1,600/2,400/3,200`, max 3, `$750`, `briefing.html:32-35`), Factory Queue (`briefing.html:37-38`), Medic truck (`briefing.html:40-41`), Classes (`briefing.html:43-44`).
- **Other Changes** — a bullet list not present in the Diary: EASA loadout `[AA]/[AG]/[MR]` tags, proportional rearm cost (10% floor, artillery exempt), WDDM cap of 3 per base, defense budget caps, engineer-crewed armour/APCs, earplugs fading radio/voice (`briefing.html:46-54`).
- **Discord** — invites + pinned guide pointer (`briefing.html:56-58`).

Because it duplicates the same economy figures, `briefing.html` is part of the same drift surface as §4 — and is the source of the Bank-payout disagreement noted above (`briefing.html:19`).

---

## See also

- [Mission Entrypoints And Lifecycle](Mission-Entrypoints-And-Lifecycle) — where `Init_Client.sqf` (and thus `briefing.sqf`) runs.
- [Player UI Workflow Map](Player-UI-Workflow-Map) — the live WF-menu / buy-menu flow the Diary describes.
- [New Player Quickstart Guide](New-Player-Quickstart-Guide) — off-server reader equivalent.
- [Economy Authority First Cut](Economy-Authority-First-Cut) / [Bank Reserve And Artillery Radar Structures](Bank-Reserve-And-Artillery-Radar-Structures) / [Counter Battery Radar System](Counter-Battery-Radar-System) — authoritative numbers behind §4.
