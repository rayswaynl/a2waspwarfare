# Vehicle Service and Logistics Player Guide (rearm, repair, refuel, travel)

> Source-verified 2026-06-21 against master f8a76de34. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This guide covers how a **player** keeps a vehicle (and themselves) topped up and moving: the Vehicle Service Point, buying vehicles, and getting around the map. New to the mission? Start with the [New player quickstart](New-Player-Quickstart-Guide).

## The Vehicle Service Point

Your commander builds a **Vehicle Service Point** at the base (and can build more forward). It is your refuel/rearm/repair/heal station. Drive a vehicle — or stand, for healing — within **`WFBE_C_UNITS_SUPPORT_RANGE = 70` m** (`Common/Init/Init_CommonConstants.sqf:767`) and use the scroll-menu service actions. A **forward repair truck** services within a tighter `WFBE_C_UNITS_REPAIR_TRUCK_RANGE = 40` m (`:763`).

### Services, costs and times

| Service | Base price | Time | Source |
|---------|-----------:|-----:|--------|
| Heal (infantry) | $125 | 10 s | `WFBE_C_UNITS_SUPPORT_HEAL_PRICE/_TIME` (`Init_CommonConstants.sqf:768-769`) |
| Rearm | $14 base | 20 s | `WFBE_C_UNITS_SUPPORT_REARM_PRICE/_TIME` (`:770-771`) |
| Refuel | $16 base | 10 s | `WFBE_C_UNITS_SUPPORT_REFUEL_PRICE/_TIME` (`:772-773`) |
| Repair | $2 base | 20 s | `WFBE_C_UNITS_SUPPORT_REPAIR_PRICE/_TIME` (`:774-775`) |

**Costs scale with what you actually need.** Rearm price scales with the ammo you are actually missing (`WFBE_C_SUPPORT_REARM_PROPORTIONAL = 1`, `Init_CommonConstants.sqf:805`) — a nearly-full vehicle costs little to top up — and repair/refuel similarly scale with damage/fuel missing. **Artillery rearm is exempt** from the proportional discount (it always pays full). The exact pricing formulas, the ammo-fraction maths, and the affordability guards are in the [Service Point pricing model](Service-Point-Pricing-Model).

Tip: top up *before* you push, not after you are shot up in the open. A cheap $2 repair at base beats abandoning a smoking tank at the front.

## Buying vehicles

Vehicles come from the **factories** your commander has built:

- **Light Factory** — wheeled/light armour, technicals, light transport.
- **Heavy Factory** — tanks, IFVs, heavy armour.
- **Aircraft Factory** — helicopters and jets (see the [airfield-exclusive roster](Airfield-Exclusive-Roster-And-Special-Unit-Hints) and the [UAV terminal & spotter system](UAV-Terminal-And-Spotter-System)).

Open the factory's buy menu to see the per-faction price and required research level for each vehicle — the complete lists are in the [Faction unit and vehicle roster catalog](Faction-Unit-And-Vehicle-Roster-Catalog), and the purchase/queue mechanics are in the [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas). The factories and other base structures are catalogued in [Faction base structures](Faction-Base-Structures-Catalog).

You pay vehicles out of your **personal funds**; remember the respawn penalty if you lose an expensive one (see [Earning funds & score](Earning-Funds-And-Score-Player-Guide)).

## Getting around

Walking is the slowest option. Your travel toolkit (keys, costs and exact behaviour are in [Player vehicle & travel actions](Player-Vehicle-And-Travel-Actions-Reference)):

- **Fast travel** between owned positions.
- **Transport / airlift** — ride with squadmates, get dropped near the front, or sling-load cargo (see [Zeta cargo sling-load](Zeta-Cargo-Sling-Load-Reference)).
- **Vehicle lock / eject / utility actions** — secure your vehicle so it is not stolen, eject passengers, etc.

For deploying *near* a fight rather than driving from base, also see how mobile spawns work in [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas).

## Quick reference

| Thing | Value |
|-------|-------|
| Service Point range | 70 m |
| Repair-truck range | 40 m |
| Heal | $125, 10 s |
| Rearm | $14 base (scales with ammo missing), 20 s |
| Refuel | $16 base (scales with fuel missing), 10 s |
| Repair | $2 base (scales with damage), 20 s |
| Artillery rearm | full price (no proportional discount) |

## Continue Reading

- [New player quickstart](New-Player-Quickstart-Guide) — the full first-match walkthrough
- [Service Point pricing model](Service-Point-Pricing-Model) — the exact rearm/repair/refuel/heal formulas
- [Player vehicle & travel actions](Player-Vehicle-And-Travel-Actions-Reference) — fast travel, transport and vehicle actions
- [Faction unit and vehicle roster catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — what each factory sells, with prices
- [Earning funds & score](Earning-Funds-And-Score-Player-Guide) — paying for all of the above
