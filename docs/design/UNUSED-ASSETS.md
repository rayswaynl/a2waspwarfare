# UNUSED / DORMANT ASSETS INVENTORY — WASP Warfare (Build 84 / cmdcon36)

**Scope:** `Missions\[55-2hc]warfarev2_073v48co.chernarus` (CH) + the Takistan mirror pools (`Missions_Vanilla`, same source tree via LoadoutManager).
**Question (Ray):** "Any unused units / vehicles etc in the mission we could do something cool with?"
**Method:** harvested classnames from every buy list (`Core/Core_*.sqf`), AI/depot pools (`Core_Units/Units_*.sqf`), AI-team templates (`Core_Squads/Squad_*.sqf`), the wildcard deck (`AI_Commander_Wildcard.sqf`), the GUER air-defence spawner (`Server_GuerAirDef.sqf`), the naval-HVT orchestrator (`Init_NavalHVT.sqf`), EASA (`EASA_Equip.sqf`) and GUER-player VBIED (`Client_BuildUnit.sqf`), then diffed **purchasable** against **spawned/pool** against **referenced-but-never-reached**.
**Read-only pass — nothing was edited.**

> **ACR content is OFF-LIMITS (Ray shelved it).** Every `*_ACR`, `Dingo_*`, `Pandur2_ACR`, `RM70_ACR`, `T72M4CZ`, `BVP1_TK_ACR`, `Mi24_D_CZ_ACR`, `L159_ACR`, `T810_*_CZ_EP1` class is listed only for completeness in the appendix and is explicitly **not** proposed for any use.

---

## How to read the classification

- **PURCHASABLE** — appears in a live faction's `Core/Core_*.sqf` buy list a player can actually reach at a factory (live factions: CH → WEST `US`, EAST `RU`, GUER `GUE`; TK → WEST `US`, EAST `TKA`, GUER `TKGUE`).
- **SPAWNED** — the AI/depot/garrison/wildcard/naval systems place it at runtime (`WFBE_*UNITS` pools, squad templates, `Server_GuerAirDef`, `Init_NavalHVT`), even if no player can buy it.
- **DORMANT** — the classname is present in the tree but the code path that would surface it is gated OFF on both live maps (naval-only, USMC-faction-only, air-war-event-only, commented, or a `weight 0` wildcard). **This is the interesting set.**

The big structural facts that create most of the dormant pools:

1. **USMC is not the live WEST faction.** `WFBE_C_UNITS_FACTION_WEST` selects `US` on both maps (`Core_US` / `Core_US_Camo`), **never** `USMC`. Everything unique to `Core_USMC.sqf` — **AAV, MV22, Zodiac, RHIB, RHIB2Turret** and the USMC boxes — is compiled but unreachable.
2. **Both live maps are non-naval.** `IS_naval_map` is false on CH and TK, so every `if (IS_naval_map)` block that appends **PBX / Zodiac** to depot pools is skipped, and `Init_NavalHVT` exits immediately (`IS_naval_map=false` guard). All watercraft are effectively dead.
3. **CIV faction is not a buy target.** `Core_CIV.sqf` holds **Smallboat_1, Smallboat_2, Fishing_Boat** and the whole civilian car/bus/tractor fleet; players never open a CIV shop, so these only ever appear as ambient/AI-driven props.
4. **The wildcard deck has 9 inert cards** (weight forced to 0): W3 Bonus Patrol, W7 Veteran Company, W9 Uprising, W10 Lucky Salvage, W14 Iron Dome, W17 Supply Convoy, W18 Bounty HVT, **W21 GUER VBIED**. Their apply blocks (and the assets they would spawn) are dead but fully written.

---

# TOP-12 PROPOSALS (ranked for Ray to pick from)

| # | Proposal | Asset(s) | Where it's dormant | One cool use | Effort |
|---|----------|----------|--------------------|--------------|--------|
| 1 | **Ka-137 recon drone wildcard** ("Eye in the Sky") | `Ka137_PMC`, `Ka137_MG_PMC` | `Ka137_MG_PMC` is GUER-buyable + used by `Server_GuerAirDef`; the unarmed `Ka137_PMC` is PMC-faction only (dormant). Ray named this one. | New **AICOM wildcard card**: commander launches a Ka-137 that orbits the enemy spearhead town ~180s and reveals enemy units on the map (mirror W22 Top Gun's loiter+self-despawn path). Cheap, visible, thematically perfect for a drone. | **M** |
| 2 | **Revive the GUER VBIED as a live wildcard** | `hilux1_civil_2_covered`, `M113_UN_EP1` | Deck card **W21** is weight-0 (Ray pulled it 2026-06-27) but the full driver-detonate apply block + player-side action still ship. | Re-arm W21 at a low weight **only for the AI GUER/losing side**, or bind it to the GUER-player harass loop as a periodic "a VBIED is loose near town X" event with a global bounty. All plumbing already exists and is battle-tested. | **S** |
| 3 | **AN-2 "Smuggler Run" a-life encounter** | `An2_TK_EP1`, `An2_1_TK_CIV_EP1`, `An2_2_TK_CIV_EP1` | An2 is TKA-buyable + in RU/GUE pools + airfield list; the two **civilian An2 variants** are GUE-pool only and never spawn on CH/TK. | Rare neutral **low-flying cargo biplane** that crosses the map; shoot it down and it drops a supply/funds crate (reuse `Server_GuerAirDef` drop logic). Pure flavour, no balance impact. | **M** |
| 4 | **Civilian boat traffic on the coast** | `Smallboat_1`, `Smallboat_2`, `Fishing_Boat`, `PBX`, `Zodiac` | All watercraft dormant (non-naval maps, CIV/USMC factions). | Ambient **fishing boats + a patrol PBX** near coastal towns as living-world dressing (enableSimulation-gated to player proximity, per the no-sim-gating-of-COMBAT-AI rule these are neutral props, not fighting AI). Chernarus coast is currently dead water. | **M** |
| 5 | **Tractor / civilian-fleet "Requisition" GUER toy** | `Tractor`, `TT650_Civ`, `Old_bike_TK_CIV_EP1`, `UralCivil`, `V3S_*`, `car_sedan`, `SkodaRed`, `Volha_*` | Civilian fleet lives in RU/US **depot** pools + CIV faction; on CH/TK most are pool-only, never player-reachable. | Give the **GUER player a cheap civilian-vehicle depot** (bikes/tractor/hatchback) so insurgents look like insurgents — dirt-cheap disposable transport that blends into towns. Fits the harass-only GUER design. | **S** |
| 6 | **T-34 "Museum Piece" event tank** | `T34_TK_EP1` | Buyable on TK (`Core_TKA`) but **not** buyable on CH (RU pool-only). | A one-off **capturable T-34** parked at a neutral objective (old depot/museum). First side to crew it gets a free—if creaky—tank. Iconic, funny, low-stakes. | **M** |
| 7 | **BM-21 GRAD / D-30 "Artillery Cache" objective** | `GRAD_RU`/`GRAD_TK_EP1`, `D30_RU`, `2b14_82mm` | GRAD is RU/TKA buyable + heavy pool; but AI arty is disabled (`WFBE_C_AI_COMMANDER_ARTILLERY=0`) so AI never fields it. | Neutral **abandoned artillery park** (GRAD + D-30 + mortar) as a capture-me side objective; whoever holds it can man it. Uses assets the AI will otherwise never touch. | **M** |
| 8 | **Avenger HMMWV "SAM ambush"** | `HMMWV_Avenger_DES_EP1` | **Implemented cmdcon43, default OFF** behind `WFBE_C_AVENGER_SAM_AMBUSH`: active WEST-held towns can field a capped, self-cleaning crewed Avenger when EAST/GUER aircraft enter the town airspace. | Tune/enable the optional event after soak testing; it uses the existing `Server_GuerAirDef.sqf` maintain loop and its own cap/lifetime/quiet-despawn constants. | **M** |
| 9 | **MV-22 Osprey heavy-lift event** | `MV22` | `Core_USMC` only → dormant (USMC not live WEST). | **Match-start / relief** flavour: an Osprey flies in the first reinforcement wave to a friendly town (visual only, reuse the W6 Air Cavalry air-insertion). Distinctive silhouette players will notice. | **M** |
| 10 | **Static ZU-23 / SearchLight town dressing** | `ZU23_Gue`, `Ural_ZU23_INS`, `SearchLight_US_EP1`, `SearchLight_RUS` | ZU-23 truck is GUE/RU pool; static ZU-23 & searchlights are buyable defences but almost never bought. | Seed **contested/GUER towns with a static ZU-23 + sweeping searchlights** at night as garrison flavour — instantly reads as "occupied town" and gives attacking players a target. | **S** |
| 11 | **Pchela-1T recon drone (EAST mirror of #1)** | `Pchela1T` | RU-buyable but obscure; AI never founds a drone team. | EAST counterpart to the Ka-137 recon wildcard — keeps the drone card faction-symmetric so both AI commanders can "call a UAV." Bundle with #1. | **M** |
| 12 | **AAV amphibious "Beach Assault" (naval-map re-enable hook)** | `AAV` | `Core_USMC` only → dormant. | Park it behind a `WFBE_C_NAVAL_*`-style flag: on a future **naval map** the AAV becomes the WEST amphibious assault vehicle launching from a Khe Sanh carrier. Low effort as a *hook* now, big payoff if naval maps return. | **S** (hook) / **L** (full) |

**Fast wins:** #2 (VBIED revive — code already exists), #5 (GUER civ depot), #10 (static garrison dressing) are all **S** and need only config/pool edits.
**Highest "cool" per effort:** #1 (Ka-137 drone — Ray asked for it by name) and #3 (AN-2 smuggler run).

---

## Invalid / suspicious classnames flagged during the harvest

None of the pool rows in the **live** faction files (`Core_US`, `Core_RU`, `Core_GUE`, `Core_TKA`, `Core_TKGUE`) look like typos — every classname resolves to a known A2CO/BAF class. Two things to note rather than "typos":

- **`UH1H_EP1` (WEST salvage heli)** is documented in-tree as **removed for being an invalid class on the live box** (comment in `Units_CO_US.sqf:275` and `Init_Common.sqf:434`). It is already gone from the pools; do **not** re-add without a validated airframe. This is the only confirmed bad-class case and it is already handled.
- **Registration-race classes `Mi24_P` and `Ka137_MG_PMC`** are intentionally shared across `Core_GUE`/`Core_RU`/`Core_PMC`; the load-order comments (`Core_GUE.sqf:126-129`) show the air-level was already corrected in B60/B66. Not a bug — just fragile; any new card that reads their air-tier should key off the corrected global, not re-register them.
- `Init_NavalHVT.sqf` deliberately guards every carrier part with a `createVehicle` null-check that logs `NAVALHVT-SPAWNFAIL` — so any genuinely-missing `Land_LHD_*` part is already diagnosable from RPT. No silent-typo risk there.

---

# APPENDIX — FULL DORMANT INVENTORY (by system)

### A. Dormant because USMC is not the live WEST faction (`Core_USMC.sqf` only)
| Class | Category | Why dormant |
|-------|----------|-------------|
| `AAV` | Amphibious APC | USMC buy list only; also appears in `Units_CO_US` heavy pool but only under CH branch → AI can field it, players can't buy it. |
| `MV22` | Tiltrotor transport | USMC buy list + US aircraft pool; never bought (US faction has no MV22 buy row). |
| `Zodiac` | Small boat | USMC buy list + naval-gated depot rows. |
| `RHIB`, `RHIB2Turret` | Patrol boats | USMC buy list + `Units_USMC` pool; naval-dead. |
| USMC ammo boxes / trucks | Logistics | Parallel to US logistics; unreachable. |

### B. Dormant watercraft (non-naval maps)
| Class | Source | Note |
|-------|--------|------|
| `PBX` | `Core_RU` (buyable!) + RU depot `if (IS_naval_map)` | **Buyable on paper** but every depot append is naval-gated; on CH/TK it sits in the RU factory list with no water to use it. |
| `Zodiac` | US/USMC pools `if (IS_naval_map)` | dead |
| `Smallboat_1`, `Smallboat_2`, `Fishing_Boat` | `Core_CIV.sqf` | CIV faction, never a player shop |
| Khe Sanh LHD parts (`Land_LHD_*`, `MAZ_543_SCUD_TK_EP1`, `Mi24_P`+`An2_1_TK_CIV_EP1` CAP) | `Init_NavalHVT.sqf` | Whole feature exits on `IS_naval_map=false`; alive only on a naval map. |

### C. Dormant / inert wildcard-deck assets (weight 0)
| Card | Asset it would spawn | Status |
|------|----------------------|--------|
| W21 GUER VBIED | `hilux1_civil_2_covered`, `M113_UN_EP1` | inert (weight 0) — revive candidate (#2) |
| W9 Uprising | `WFBE_GUERRESTEAMTEMPLATES`, `WFBE_GUERRESSOLDIER` | inert — "too invasive" |
| W14 Iron Dome | `WFBE_<side>DEFENSES_AAPOD` (AA pods) | inert |
| W17 Supply Convoy | `WarfareSupplyTruck_USMC`/`_RU` | inert |
| W18 Bounty HVT | enemy officer / `WFBE_<side>PARACHUTELEVEL3[0]` | inert |
| W3 / W7 / W10 | patrols / veteran flag / salvage | inert |

### D. AI/pool-only vehicles (spawned by AI or in depot, NOT player-buyable) — non-ACR
`An2_TK_EP1`, `An2_1_TK_CIV_EP1`, `An2_2_TK_CIV_EP1` (AN-2 biplanes) · `Ka60_PMC`, `Ka60_GL_PMC`, `Ka137_PMC` (PMC helis/drone) · `Mi17_Ins`, `Mi17_Civilian`, `Mi171Sh_CZ_EP1`, `Mi171Sh_rockets_CZ_EP1` · `BMP2_INS`, `BRDM2_INS`, `BRDM2_ATGM_INS`, `ZSU_INS`, `Su25_Ins`, `UAZ_MG_INS`, `UAZ_SPG9_INS`, `Ural_ZU23_INS` (INS-flavour EAST pool) · `ArmoredSUV_PMC`, `SUV_PMC` · `AW159_Lynx_BAF`, `BAF_Apache_AH1_D`, `BAF_Merlin_HC3_D`, `CH_47F_BAF`, `BAF_FV510_D/W`, `BAF_Jackal2_*`, `BAF_Offroad_*`, `BAF_ATV_*` (BAF pool) · `LandRover_Special_CZ_EP1`.

### E. Civilian fleet (depot/CIV pools, mostly pool-only on live maps)
Cars/bikes: `Tractor`, `TT650_Civ`, `TT650_Ins`, `Old_bike_TK_CIV_EP1`, `Old_moto_TK_Civ_EP1`, `car_sedan`, `car_hatchback`, `SkodaBlue`, `SkodaRed`, `VWGolf`, `Lada1/2`, `LadaLM`, `Volha_1/2`, `VolhaLimo`, `S1203_TK_CIV_EP1`, `datsun1_civil_1/2/3`, `hilux1_civil_1/2`, `LandRover_TK_CIV_EP1`, `SUV_TK_EP1` · Trucks/bus: `UralCivil`, `V3S_TK_EP1`, `V3S_Open_TK_EP1`, `V3S_Refuel_TK_GUE_EP1`, `Kamaz`, `Ikarus`, `Ikarus_TK_CIV_EP1`.

### F. Underused **buyable** heavy/exotic assets (reachable but AI never fields / players rarely buy)
| Class | Faction | Why interesting |
|-------|---------|-----------------|
| `T34_TK_EP1` | TKA buyable (CH pool-only) | iconic vintage tank (#6) |
| `GRAD_RU` / `GRAD_TK_EP1`, `D30_RU`, `2b14_82mm`, `M119_US_EP1`, `M252_US_EP1`, `MLRS_DES_EP1` | RU/TKA/US | AI arty disabled → these only ever come from players; artillery-cache objective (#7) |
| `HMMWV_Avenger_DES_EP1` | US buyable | cmdcon43 adds optional default-OFF WEST SAM ambush (#8) |
| `Pchela1T` | RU buyable | EAST recon drone (#11) |
| `MQ9PredatorB_US_EP1`, `Ka137_MG_PMC` | US / GUER | drone content already partially live (drone wildcard hook, #1) |
| Static defences: `SearchLight_US_EP1`, `SearchLight_RUS`, `ZU23_Gue`, `Ural_ZU23_Gue`, `Stinger_Pod_US_EP1`, `Igla_AA_pod_East` | mixed | town-dressing / night flavour (#10) |

### G. Explicitly OFF-LIMITS (ACR — listed only, do NOT propose)
`Dingo_WDL_ACR`, `Dingo_GL_Wdl_ACR`, `Dingo_DST_ACR`, `Dingo_GL_DST_ACR`, `Pandur2_ACR`, `RM70_ACR`, `T72M4CZ`, `BVP1_TK_ACR`, `Mi24_D_CZ_ACR`, `Mi171Sh_CZ_EP1`, `Mi171Sh_rockets_CZ_EP1`, `L159_ACR`, `T810_CZ_EP1`, `T810_Repair_CZ_EP1`, `T810_Refuel_CZ_EP1`, `T810_Ammo_CZ_EP1`, `LandRover_Special_CZ_EP1`.

---

## Source files consulted (all under the CH mission root)
- Buy lists: `Common/Config/Core/Core_{US,RU,GUE,TKA,TKGUE,USMC,CDF,PMC,INS,CIV}.sqf`
- AI/depot pools: `Common/Config/Core_Units/Units_{CO_US,CO_RU,CO_GUE,OA_TKA,OA_TKGUE,OA_US,USMC,RU}.sqf`
- AI-team templates: `Common/Config/Core_Squads/Squad_*.sqf` + `Squads_GetFactionGroups.sqf`
- Wildcard deck: `Server/Functions/AI_Commander_Wildcard.sqf` (+ `_GUER`)
- GUER air-defence spawner: `Server/Server_GuerAirDef.sqf`
- Naval HVT: `Server/Init/Init_NavalHVT.sqf`
- EASA / GUER-VBIED: `Client/Module/EASA/EASA_Equip.sqf`, `Client/Functions/Client_BuildUnit.sqf`, `Client/Action/Action_GuerVbiedDetonate.sqf`
- Faction/map wiring: `Common/Init/Init_Common.sqf`, `Common/Init/Init_CommonConstants.sqf`
