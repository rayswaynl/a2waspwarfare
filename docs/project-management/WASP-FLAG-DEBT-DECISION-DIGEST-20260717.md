# WASP Flag-Debt Decision Digest — 2026-07-17

**Scope:** `Common/Init/Init_CommonConstants.sqf` in Chernarus source (mirrored to Takistan/Zargabad).  
**Source review:** `W:\Mijn vualt\Fleet\Docs\WASP-FRESH-EYES-KIMI-20260717.md` §2.1.  
**This PR does not change any values** — it only makes comments match the live armed state and converts two hard-set flags to `isNil`-overridable defaults.

---

## Mechanical fixes already applied

| Flag | Line | Change |
|------|------|--------|
| `WFBE_C_AI_COMMANDER_LOG` | ~603 | Was hard-set `= 1`; now `if (isNil ...) then { ... = 1 }`. Still defaults to `1`. |
| `WFBE_C_AICOM_SERVICE_ENABLED` | ~1307 | Was hard-set `= 1`; now `if (isNil ...) then { ... = 1 }`. Still defaults to `1`. |

Both remain armed by default but can now be dimmed from a lobby parameter / mission override like every other tunable flag.

---

## Armed-but-documented-as-dark flags (owner decision table)

Live SQF value is `1` for every flag below unless the **Effective live default** column says otherwise.

| Flag | What it does | Recommen-dation | Notes / risk |
|------|--------------|-----------------|--------------|
| `WFBE_C_GUER_PLAYERSIDE` | GUER "Insurgents" playable third faction master gate. | **Keep armed** | B66 trial-round arm; lobby param also defaults `1`. Core to current GUER-player feature set. |
| `WFBE_C_TOWN_SCAN_DICE` | Dormant towns roll a probability to skip the 600 m activation `nearEntities` scan (perf win). | **Keep armed** | Active towns still scan; dormant skip is safe and saves server work. |
| `WFBE_C_FIRSTBLOOD_ENABLED` | First PVP kill fires a one-time sting/announcement/cash bonus. | **Keep armed** | Cosmetic/celebration only; no balance risk. |
| `WFBE_C_DEFENSE_CLIENT_GATE_ALIGN` | Client base-defense placement preview turns red only when enemy count >= `WFBE_C_DEFENSE_THREAT_MIN`, matching the server gate. | **Keep armed** | Fixes the mismatch where preview blocked placement earlier than the server did. |
| `AICOMV2_LANE_GUER_DIRECTOR` | GUER Director V2 virtual ledger + lightweight brain. | **Keep armed** | Owner-authorized live feature; widely wired. |
| `AICOMV2_GDIR_PANEL` | Player Commissar Panel (paid reinforcements/QRF/counter-attack). | **Keep armed** | Requires Director lane; already live and consumed by GUER players. |
| `WFBE_C_NOTABLE_KILL_FEED` | Side-wide SideMessage for commander/HQ/heavy-vehicle kills. | **Keep armed** | Purely additive intel; throttled. |
| `WFBE_C_WALLS_V4` | Factory wall slabs v4 layout (concrete rows, aligned gaps). | **Dim to 0** | Comment originally said V3 is the live default look. Arm only after owner sign-off on the new base silhouette. |
| `WFBE_C_DEF_FORTIF_PACK` | Five passive fortification compositions (wall row, corner, LoS screen, HESCO, gate complex). | **Dim to 0** | No wiki page; large new buildable footprint. Worth a dedicated soak/doc pass before arming. |
| `WFBE_C_SML_CAMP_SPLIT` | Squad Micro Layer 1: per-unit camp-split capture behavior. | **Keep armed** | Small behavioral polish; inert when flag off. |
| `WFBE_C_SML_DISMOUNTS` | SML-2: cargo infantry dismount on foot, crew stays mounted. | **Keep armed** | AI team behavior polish. |
| `WFBE_C_SML_RETREAT` | SML-3: damaged individuals pull back while healthy units fight. | **Keep armed** | Improves AI survivability without changing meta. |
| `WFBE_C_SML_AT_OVERWATCH` | SML-4: launcher pre-positions on armor approach vector. | **Keep armed** | AI tactical improvement; gated per team. |
| `WFBE_C_SML_SURGICAL_UNSTUCK` | SML-5: nudge only individually-wedged units before escalating. | **Keep armed** | Reduces full-team teleport recovery. |
| `WFBE_C_GUER_CP_V2` | Road-snapped, physically blocking GUER checkpoint v2 (G2 wildcard). | **Keep armed** | Owner cmdcon45 pick; already tuned with v2-specific constants. |
| `WFBE_C_CAMPS_LEGACY_SKIP_ON_PERCAMP_FLIP` | When town capture flips camps, suppress legacy `Server_SetCampsToSide` double-flip. | **Keep armed** | Prevents redundant camp resets; depends on `WFBE_C_TOWN_CAPTURE_FLIPS_CAMPS`. |
| `WFBE_C_SKIP_EMPTY_CAMP_THREAD` | Skip launching `server_town_camp.sqf` for towns with zero synced camps. | **Keep armed** | Avoids idle workers on naval/carrier towns. |
| `WFBE_C_AICOM_STUCK_REPAIR_RESETS_TIER` | After a successful stuck-repair, reset the team tier counter so AssignTowns does not keep escalating. | **Keep armed** | Addresses the stuck-repair counter runaway noted in RPT. |
| `WFBE_C_HC_CIV_RESLOT` | Empty-server signal for HC controllers to reslot HCs to CIVILIAN slots. | **Dim to 0** | Mission-side hook only; box-side CIV slots + reslot logic are still rig-test-gated. Safe to enable once the full chain is proven. |
| `WFBE_C_AIR_SPAWN_SAFETY` | Aircraft purchase tries to find a clear spawn slot before placing hull. | **Keep armed** | Falls back to nominal position; never blocks purchase. |
| `WFBE_C_GARRISON_DRESSING` | Server-side ZU-23/searchlight dressing on active GUER-held contested towns. | **Keep armed** | Capped at 6 towns; forced lifetime prevents accumulation. |
| `WFBE_C_AIRFIELD_OWNERSHIP_GATE` | Players can only buy/spawn aircraft at airfields their side owns. | **Keep armed** | AI commander unaffected; unbound airfields still allowed. |
| `WFBE_C_FPV_DRONE` | Player-piloted kamikaze mini-UAV from Tactical Center. | **Keep armed** | Re-enabled after fixwave-20260717 purchase-authority race fix. |
| `WFBE_C_AWACS` | AWACS air picture + ground MTI sweep while a crewed platform is up. | **Keep armed** | Lobby param also defaults `1`. |
| `WFBE_C_EAST_C130` | East/OPFOR captured C-130J token for AWACS-role transport. | **Keep armed** | Lobby param also defaults `1`. |
| `WFBE_C_PLAYER_DEFENSE_AUTOMAN` | Player-built gunner-capable statics inside base areas get AI-manned defense path. | **Keep armed** | Client `manningDefense` toggle still gates each build; respects player choice. |
| `AICOMV2_CTL_INVEST_ENABLE` | CTL AI-commander town-investment sub-flag. | **Dim to 0** | The CTL master lane `AICOMV2_LANE_CMD_TOWN_LEDGER` is owner-disarmed (`0`), so this sub-flag is inert anyway. Flip back to `1` only when CTL is armed after defect fixes. |
| `WFBE_C_UNITS_CREW_COST_TIERSCALE` | Crew-replacement cost scales with the crewed vehicle's buy price (capped). | **Keep armed** | Owner economy pick GR-2026-07-08a. |
| `WFBE_C_STRUCTURES_RADIOTOWER` | Radio Tower buildable; gates WASP Vehicle Radio. | **Keep SQF armed** | SQF default is `1`, but `Rsc/Parameters.hpp` defaults this to `0`, so the **effective live default is already off**. No code change needed unless owner wants the lobby default flipped to `1`. |

---

## Parameters.hpp overrides to be aware of

Only one flag in the table is dimmed at the lobby level despite being armed in SQF:

- `WFBE_C_STRUCTURES_RADIOTOWER` — `Rsc/Parameters.hpp:99` `default = 0`.  
  The comment in `Init_CommonConstants.sqf` now notes this explicitly.

---

## Additional comment mismatches observed (outside the §2.1 table)

These were **not** changed in this PR to stay scoped to the review table, but they have the same pattern (`1` in SQF, comment claims `0` default):

- `WFBE_C_LOOP_PHASE_JITTER` (~1345) — heavy server loop phase jitter.
- `WFBE_C_TOWN_CAMP_ACTIVE_GATE` (~1430) — dormant town camp-scan idle gate.
- `WFBE_C_SMALLARMS_AIR_ENVELOPE` (~2729) — small-arms vs air envelope manager.
- `WFBE_C_AICOM_STRATEGY_TOWNCACHE` (~2740) — per-candidate town cache in strategy.

If the owner wants a follow-up "dim sweep", these four should be added to the decision list.

---

## Proposed next step

1. Owner rules on the **five "Dim to 0"** recommendations above (`WALLS_V4`, `DEF_FORTIF_PACK`, `HC_CIV_RESLOT`, `CTL_INVEST_ENABLE`, and any additional four).
2. Implement the dim in a follow-up PR (pure value changes; no comment churn).
3. Run the same LoadoutManager mirror + lint gate for the follow-up.
