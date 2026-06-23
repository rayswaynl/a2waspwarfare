# New Player Quickstart Guide (your first match)

> Source-verified 2026-06-21 against master f8a76de34. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This is a player-facing walkthrough for your first WASP Warfare match as a **regular soldier** (not the commander). Warfare is a three-sided CTI: each side starts from a base, captures towns for income, and spends that income on gear, vehicles, structures and upgrades until one side wins. Your job as a soldier is to **capture towns, kill enemies, and stay useful** — all of which pay you personal funds you then spend on better kit. (For the commander's job — deploying the HQ, building factories and researching upgrades — see the [Commander's Handbook](Commanders-Handbook).)

This page is a guide; it cross-links the detailed reference pages for every system. The hard numbers below are cited to source.

---

## The 60-second version

1. **Spawn at base → open the gear menu → kit up** (your default loadout is free; better weapons cost funds and may need an upgrade level).
2. **Recruit AI or join a squad** so you are not alone.
3. **Get to the nearest contested town** (drive, fly, or fast-travel).
4. **Clear the defenders and stand in the town** to capture it.
5. **Get paid** for the capture, for kills, and for supply deliveries.
6. **Spend** at the factories (gear/vehicles) and top up at a **Vehicle Service Point** (rearm/repair/refuel/heal).
7. **When you die**, respawn at the base, a camp, or a mobile spawn near the front.

---

## Step 1 — Spawn and gear up

You start at your side's base. Open the **WF Menu** and pick **Gear / Buy Gear** to change your loadout. Your faction's default loadout is free; everything else is bought with **personal funds** and is gated by your side's research level (`WFBE_UP_GEAR`) — higher-tier weapons stay greyed out until the commander unlocks them. The full per-faction price/level lists are in the [Gear store catalog](Gear-Store-Catalog-Per-Faction) and the [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas).

Tip: don't overspend early. You will likely die and pay a **respawn penalty** (see Step 7), so buy what you can afford to lose.

## Step 2 — Don't fight alone

You can recruit **AI teammates** into your group — up to `WFBE_C_PLAYERS_AI_MAX = 16` per player group (`Common/Init/Init_CommonConstants.sqf:637`) — or join another player's squad. Joining/leaving and command handover are covered in the [Player squad/group join protocol](Player-Squad-Group-Join-Protocol). A few AI riflemen make town-capturing far safer and let you hold ground while you push.

## Step 3 — Get to the front

Walking is slow. Your options:

- **Buy a vehicle** from a factory (Light/Heavy/Aircraft) — see the [unit & vehicle roster](Faction-Unit-And-Vehicle-Roster-Catalog).
- **Fast travel** and other player travel/transport actions — see [Player vehicle & travel actions](Player-Vehicle-And-Travel-Actions-Reference).
- **Aircraft** (helis/jets) launch from the airfield — pilots should read the [airfield-exclusive roster](Airfield-Exclusive-Roster-And-Special-Unit-Hints) and the [UAV terminal & spotter system](UAV-Terminal-And-Spotter-System).

Note you **cannot build** inside an enemy/neutral town until it is yours: construction is blocked within `WFBE_C_TOWNS_BUILD_PROTECTION_RANGE = 450` m of a town (`Init_CommonConstants.sqf:705`).

## Step 4 — Capture a town

Towns are the economy. The default capture rule is **Classic mode** (`WFBE_C_TOWNS_CAPTURE_MODE = 0`, `Init_CommonConstants.sqf:706`): a town flips to your side once you **clear its defenders and have a soldier present within 40 m** of the town centre. The town's camps are a **capture-speed bonus**, not a hard requirement, in this mode. Full capture/garrison mechanics are in the [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas); the garrison that defends a town is catalogued in [Town AI group composition](Town-AI-Group-Composition-Catalog).

Captured towns generate income for your side every tick — that is what funds the whole war (see [Economy, towns and supply](Economy-Towns-And-Supply) and the [income-tick engine](Resource-Income-Tick-Distribution-Engine)).

## Step 5 — Get paid

Your **personal funds** come from several sources:

| Action | Reward | Source |
|--------|-------:|--------|
| Capture a town | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE` (`Init_CommonConstants.sqf:638`) |
| Assist a capture | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE_ASSIST` (`:639`) |
| Capture-mission objective | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION` (`:640`) |
| Capture-mission assist | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION_ASSIST` (`:641`) |
| Supply delivery | town supply value × 4 | `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4` (`:662`) |
| Kills | score + bounty | see [Kill and score pipeline](Kill-And-Score-Pipeline) |

Running **supply missions** is one of the most reliable early-game incomes — see the [Supply missions player guide](Supply-Mission-Player-Guide). Capturing towns pays you *and* grows the side economy, so it is almost always the right move.

## Step 6 — Spend it

- **Gear & vehicles**: buy from the factory menus (the commander must have built the matching factory first). Prices are in the gear and roster catalogs linked above.
- **Vehicle Service Point**: drive a vehicle (or stand) within `WFBE_C_UNITS_SUPPORT_RANGE = 70` m (`Init_CommonConstants.sqf:767`) and use the scroll actions to top up:

| Service | Base price | Source |
|---------|-----------:|--------|
| Heal (infantry) | $125 | `WFBE_C_UNITS_SUPPORT_HEAL_PRICE` (`:768`) |
| Rearm | $14 base, scales with ammo missing | `WFBE_C_UNITS_SUPPORT_REARM_PRICE` (`:770`) |
| Refuel | $16 base, scales with fuel missing | `WFBE_C_UNITS_SUPPORT_REFUEL_PRICE` (`:772`) |
| Repair | $2 base, scales with damage | `WFBE_C_UNITS_SUPPORT_REPAIR_PRICE` (`:774`) |

Rearm/repair/refuel cost scales with how much you actually need (artillery rearm is exempt from the proportional discount); the exact formula and affordability rules are in the [Service Point pricing model](Service-Point-Pricing-Model).

## Step 7 — Death and respawn

When you die you respawn from the **respawn menu**. Spawn options:

- **Base** — always available, safest, furthest from the fight.
- **Camps** — forward respawn points; protected within `WFBE_C_RESPAWN_CAMPS_SAFE_RADIUS = 50` m (`Init_CommonConstants.sqf:676`).
- **Mobile** — spawn on the mobile HQ / a [medic redeployment truck](Medic-Redeployment-Truck-Forward-Spawn) near the front. Mobile respawn is enabled but gives **default gear only** (`WFBE_C_RESPAWN_MOBILE = 2`, `:674`).

There is a **respawn penalty**: by default you pay **one-quarter of your gear's price** on respawn (`WFBE_C_RESPAWN_PENALTY = 4`, `:675`). That is the main reason not to over-buy expensive kit you will lose. The mobile-spawn proximity tiers are `WFBE_C_RESPAWN_RANGES = [250, 350, 500]` m (`:678`). The full death/respawn flow is in the [Respawn and death lifecycle atlas](Respawn-And-Death-Lifecycle-Atlas).

---

## Quick reference

| Thing | Value |
|-------|-------|
| Max AI in your group | 16 |
| Town capture (Classic) | clear defenders + be within 40 m of town centre |
| Town capture bounty | $2,000 (+$2,000 assist) |
| Supply delivery pay | town supply value × 4 |
| Service range | 70 m |
| Heal / Rearm / Refuel / Repair base | $125 / $14 / $16 / $2 |
| Respawn penalty | pay ¼ of gear price |
| Build blocked near towns within | 450 m |

---

## Continue Reading

- [Commander's Handbook](Commanders-Handbook) — when you take the commander seat: HQ deploy, factories, structures, upgrades
- [Tactical support menu](Tactical-Support-Menu-Player-Guide) — calling artillery, UAV, paradrops and other specials
- [Supply missions player guide](Supply-Mission-Player-Guide) — the most reliable early income
- [Player squad/group join protocol](Player-Squad-Group-Join-Protocol) — recruiting AI and joining squads
- [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) — the gear and aircraft-armament systems
- [Respawn and death lifecycle atlas](Respawn-And-Death-Lifecycle-Atlas) — the full spawn/respawn detail
