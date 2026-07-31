# WASP Warfare - full changelog since 28 Jul 16:00 CET

**107 PRs merged**, 13 live builds cut, one server crash root-caused at register level.
The community server runs build **m0730n** (Chernarus + Takistan rotation).

---

## The headline: crash 014EFCF4 - found, proven, fixed

The server crashed five times at the same fault address across 30-31 Jul. An 18-agent
investigation with properly re-extracted RPT evidence produced a register-level proof: at the
final crash, fault register ESI held the exact pointer of a crew corpse that was mid-eject and
dispatched for deletion two log lines before the fault. Mechanism: deleting a body still seated
in a live vehicle races the engine's own seat-position math.

Fix (live in m0730n): seated corpses are deferred back to the garbage collector until the hull
is a cold wreck - including a repair to the deferral itself, which as originally written would
have leaked every deferred body forever; the AI air-response despawn now yields between crew
deletes; and an always-on WASPCRASH014E log captures seat state at every delete so any future
crash window identifies its cause on the spot. Honest confidence: ~65-70%; ~23 sibling delete
sites remain for a systematic sweep, with ranked fallbacks documented.

## Headless clients: 2 slots, CIV only, seating proven

- Exactly **2 HC slots on every terrain** (was 4). Takistan's four "Headless Client" slots
  carried the forceHeadlessClient flag on **none of them** - ordinary joinable slots with a
  label, which is why HCs kept appearing in BLUFOR/OPFOR. All three terrains now match.
- **HC lobby lock armed**: joiners held (invulnerable, on-screen counter) until both HCs seat,
  fail-open with loud logging. A 13-agent review caught the timeout clock starting before the
  HC launch sequence and re-derived the value from measured seating times. Proven live:
  OPEN reason=seated seated=2 on multiple boots.
- Both HCs preseated **CIV** once connect-after-mission-live held; the launch-gate timing work
  continues in its own lane.

## Spectator: from broken to a casting director

- **v2 repaired**: the m0730f camera death was disableSerialization - on A2 OA a script
  calling it dies at its first suspension (opposite of Arma 3). Handlers attach without holding
  a Display; mouse rewritten to full-rate with edge-recentre; sensitivity tunable live.
- **v3 director (armed, UID-gated)**: TAB cycles target classes (players / AI teams / towns /
  HQs), G pools all classes and auto-cuts to the highest-interest target on a dwell timer, O
  orbits, [ ] tune dwell. One review caught the thread-start blocker before it shipped; a second
  caught 4 more defects in v3.2 (dead variety-pressure, aim overshoot, idle-framing and
  orbit-sweep regressions) - all fixed before deploy.
- **v3.2 camera intelligence**: engagement-aware framing, base check-in establish shots every
  7 minutes, per-shot FOV, 1.5s cut floor, switch hysteresis - backed by a researched shot
  rulebook (broadcast observer practice + Arma machinima + auto-cinematography literature).
- **Vehicle cam fixed** after live TikTok feedback: velocity feed-forward (glides with the
  vehicle instead of chasing), no re-cut snapping while tracking, 2.5x standoff + wider FOV
  floor on vehicles (4x for air).
- **Visible controls card**: hints do not render under a scripted camera - the card moved to a
  cutText title layer and redraws only on change (the "flashing white text" fix).
- HC bodies excluded from every target list.
- **Built, dark, next build**: styled broadcast HUD (stream-readable, H cycles FULL/MINIMAL/OFF)
  + M-key map dialog with click-to-teleport [WFBE_C_SPECTATOR_BROADCAST_HUD]; dedicated CIV
  caster slot in final review [WFBE_C_SPECTATOR_CASTER_SLOT].

## The 77-PR bughunt fold

The overnight fleet produced 100 draft PRs; a 65-agent sweep assessed all of them against
the live lineage, adversarially verified the risky ones, and folded 77 (69 clean merges + 8
mechanically-resolved conflicts). 3 await gameplay-judgment recuts; 20 were skipped with
reasons on record. The post-fold lint diff caught one A2 trap (a GROUP-receiver getVariable)
fixed at fold time. Master and all branches are synced - the repo matches the live server.

### AI Commander (26)
- **#1583** fix(aicom): stop the heli cannon-nudge starving the bomb launcher
- **#1586** fix(aicom): tunable AICOM air boarding-wait cap (30s -> 12s default)
- **#1601** fix(aicom): null-guard supply squad getPos/velocity TOCTOU
- **#1627** fix(aicom): guard deleted rally members - live crash 014EFCF4
- **#1635** fix(aicom): unstick base economy - MHQ relocation gate, CC stranded-sell, GetEmptyPosition fallback
- **#1646** fix(aicom): DEFEND/PRESS posture hysteresis (live thrash / capture stalemate)
- **#1649** fix(aicom): retire stale offensive dispatch latch when diverting a team to relief
- **#1650** fix(aicom): recycle stranded base-artillery after MHQ relocate
- **#1651** fix(aicom): expand spearhead candidate pool after repeated stalls
- **#1654** fix(aicom): activate re-laid waypoint chain in AIWPAdd (order-to-waypoint translation)
- **#1663** fix(aicom): group ownership - service detour not double-booked with offense (r27)
- **#1670** fix(aicom): stranded merge/cull fire aicom-team-ended before deleteGroup
- **#1674** fix(aicom): fire-mission min-range gate + fire-time friendly recheck
- **#1678** fix(aicom): artillery fire-mission lifecycle - no double-book, full teardown
- **#1694** fix(aicom): skip Produce topup charge while topup_req pending [r34]
- **#1711** fix(aicom): assault staging/wave sync — HC FOOT_STAGE order + wave clock (r36)
- **#1716** fix(aicom): post-capture hold — HC defense order + armour hold claim parity (r37)
- **#1719** fix(aicom): water-leg objective gate + dry-prefer road route snaps (r37)
- **#1724** fix(aicom): live-only founded/HC team census for wealth/REQDRAW (r39)
- **#1728** fix(aicom): age side-abandon intel with blacklist cooldown (r40)
- **#1736** fix(aicom): transport unload integrity — sticky get-in + force moveOut (r60)
- **#1741** fix(aicom): counterbattery side routing + CBR circle + player arty echelon (r62)
- **#1742** fix(aicom): structure registry desync after loss — live filter + live-count bounds (r63)
- **#1744** fix(aicom): convoy integrity — dead-driver swap + empty hull ignore (r64)
- **#1747** fix(aicom): stamp wfbe_airfield_side on boot-adopted airfield hangar (r65)
- **#1752** fix(aicom): HC order rebind to towns after base-refit complete (r68)

### A-Life / towns / garrisons (11)
- **#1643** fix(alife): spawn template integrity (empty rosters, cargo seats, patrol keys, PMC gaps)
- **#1671** fix(alife): coastal water guard for town-edge perimeter garrison seed
- **#1697** fix(alife): movement-stall detection + unstick recovery (r34)
- **#1706** fix(alife): town alert-state escalation hold/decay (r35)
- **#1725** fix(alife): ambient skirmish suppress near player HQ/structures/FOB (r39)
- **#1732** fix(alife): patrol waypoint cycle — maxWaypoints default + water retry (r41)
- **#1737** fix(alife): knowsAbout residual surfaces r60 (heli/CAS/TEL/crew/smoke)
- **#1739** fix(alife): town static multi-group manning + operator locality (r62)
- **#1749** fix(alife): guard BASE-GC re-adopt/reap against town-garrison groups (r65)
- **#1755** fix(alife): camp capture SV heal integrity — same-side repair + flag/bounty fail-clean (r69)
- **#1761** fix(alife): town-deactivation deleteGroup targets captured group, not clobbered _x (r70)

### Mission core (11)
- **#1666** fix(mission-core): server-side caller authority bind for commander-vote + upgrade-queue PVFs (r27)
- **#1672** fix(mission-core): StructureTK satchel warn is side-scoped (no enemy fan-out)
- **#1677** fix(mission-core): stringtable/localisation text resolution (r30)
- **#1688** fix(mission-core): never trash a corpse out of a live hull's seat (crash 014EFCF4 #4)
- **#1690** fix(mission-core): player factory build-queue stuck-head purge defeated by count-based timer reset (r33)
- **#1722** fix(mission-core): own-side gate on ammo-truck gear access (r38)
- **#1734** fix(mission-core): authorise update-teamleader against forged RequestSpecial team-leader hijack (r41)
- **#1745** fix(mission-core): vehicle lock/seat authority — A2 lock + SpecOps kind + fail-clean (r64)
- **#1751** fix(mission-core): respawn list drops dead HQ / non-alive entries (r67)
- **#1756** fix(mission-core): clear WFBE_JIP_LATCH on disconnect so fast re-join reconciles funds (r69)
- **#1760** fix(mission-core): disconnect vacated-wallet zero + ghost uid + no-clobber (r69b)

### Script correctness / fail-clean (34)
- **#1613** fix(sqf): null/deleted entity guards after sleep (air land, player supply, para ammo, arty)
- **#1639** fix(sqf): bound scheduler-leaking waitUntil loops (CM spoof, MHQ grace, UI)
- **#1640** fix(sqf): exitWith then/else fall-through — oil pull, airlift, supply harden, townAI, UAV
- **#1644** fix(sqf): locality/network PV — SendToServer self-fire, supply apply, commander/radzone/salvage
- **#1645** fix(sqf): numeric math — boundary AABB, ARTY divisor 0, shell percent, CM flares
- **#1647** fix(client): guard empty EASA loadout random index on carrier buy
- **#1681** fix(sqf): town defense spawn processInit + kind-pool fail-clean (r33)
- **#1683** fix(sqf): cargo airdrop create/crew/chute + airfield hangar fail-clean (r35)
- **#1685** fix(sqf): HQ deploy/mobilize + defense create + SCUD chukar fail-clean (r36)
- **#1689** fix(sqf): AICOM air seat + beacon create + hangar recapture fail-clean (r39)
- **#1691** fix(sqf): code-as-string and condition-string evaluation hygiene (r33)
- **#1693** fix(sqf): town depot/camp/flag + airport hangar init + SADARM deploy fail-clean (r41)
- **#1696** fix(sqf): CM flares + heli terrain probe + GUER checkpoint fort fail-clean (r43)
- **#1698** fix(sqf): profileNamespace save on SetProfileVariable + buy-driver persist [r34]
- **#1701** fix(sqf): victory FX + classic ICBM target + rocket tracer + AICOM smoke fail-clean (r45)
- **#1707** fix(sqf): pass _wpcount into UAV loiter re-planner spawn (nil in spawned thread) [r35]
- **#1708** fix(sqf): AICOM para group + IRS smoke + supply town + AI respawn fail-clean (r48)
- **#1709** fix(sqf): airfield/carrier SP+CBR create + base-marker + skin group fail-clean (r49)
- **#1710** fix(sqf): turret crew + Zeta airlift + AI man buy + town-ai group fail-clean (r50)
- **#1712** fix(sqf): Wildcard W4/W13/W22 + GuerHeliDrop fail-clean (r51)
- **#1713** fix(sqf): mines cleaner + ChangeUnitGroup + GetClosest 2/3/4 fail-clean (r52)
- **#1717** fix(sqf): salvage locality + missile/bomb restrict + basearea + HQ recovery fail-clean (r53)
- **#1720** fix(sqf): deadspawn ring + supply truck + award score + crater + HALO fail-clean (r54)
- **#1721** fix(sqf): support call-in failure signalling + ICBM null-base refund (r38)
- **#1727** fix(sqf): staticDefence deleteGroup + salvage/onFired/missile/respawnCamps fail-clean (r57)
- **#1731** fix(sqf): associative-lookup miss guards — cargo + gear kind + construction rlType (r40)
- **#1733** fix(sqf): SEAD + IRS missile + support heal/repair + vehicle-lock fail-clean (r59)
- **#1735** fix(sqf): bound waitUntil — HQ in-use lock + ICBM cruise death (r60)
- **#1740** fix(sqf): select index bounds on team/buy/camera GUI paths (r62)
- **#1743** fix(sqf): config missing-entry defaults — renegade side, muzzles, air IMD (r63)
- **#1746** fix(sqf): nearEntities type-filter correctness — dress/svc/MHQ/SML/oil (r64)
- **#1748** fix(sqf): script handle lifecycle — oilfield store + UAV terminate guard (r65)
- **#1753** fix(client): nil/scalar-safe GetIncome commander_percent + case4 team count (r68)
- **#1762** fix(sqf): empty-group lifecycle — corpse purge before deleteGroup (r70)

### Spectator & UI (6)
- **#1581** fix(ui): Command deck drew over the map and stacked on legacy controls
- **#1585** fix(ui,fpv): deck header hidden while commanding; FPV spawn discarded tested height
- **#1590** feat(fpv): FPV kill-causation evidence ledger (log-only, flag WFBE_C_FPV_CAUSE_LOG default 1)
- **#1657** feat(spectator): UID-allowlisted free-camera spectator (master re-cut of #1594, blockers fixed)
- **#1658** reconcile: master's crash/leak/spectator wave merged into the LIVE release lineage + both live-bug fixes
- **#1714** fix(spectator): tear down spectator view + input handlers on endgame (r36)

### Waves, reconciliations & other (19)
- **#1582** fix: destroyed factories orphaned their walls; player planes teleported off-map
- **#1587** fix(coin): default-fallback placement method + diagnostic logging for silent CoIn failures
- **#1591** fix(ui): stop command-console P4 nudge row caption clipping
- **#1592** feat(test-harness): Stage-A bomb-release + turret-vs-hull verification probe [flag WFBE_C_BOMB_PROBE default 0]
- **#1593** fix(defense): bound base-defense re-man latency + server-side structure cap guard
- **#1595** fix(coin): restricted-area bubble 600->550m + diagnostic for the real cause
- **#1634** fix(hc): locality/group-owner after HC drop + re-land registry heal v2
- **#1637** fix(ui): MenuAction two-click races - TEL aim keys + disband sel identity
- **#1638** fix(towns): sideID consistency after capture flip (marker, garrison read, camps, income)
- **#1642** fix(nuke): classic-ICBM bounded wait - deadlocked weapon never detonated
- **#1648** fix(gear): deep-copy backpack cargo content so shared stores are not mutated in place
- **#1652** fix(gdir): roll QRF gunship airframe from configurable pool
- **#1653** fix(gdir): spread moveCell allocation across depleted towns
- **#1703** fix(recon): UAV/AWACS/TEL intel acquisition hygiene (r35)
- **#1705** fix(hc): disconnect registry demote + exclude HCs from player gates (r35)
- **#1730** fix(guer): fire the GUER barrel-bomb tech-unlock toast (r40)
- **#1754** fix(claude-r68): JIP re-push HQ/MHQ wreck-marker public state to late joiners
- **#1763** Deploy-lineage fold-back: builds m0730b..m0730o (2026-07-30/31 live wave)
- **#1774** Deploy-lineage fold-back #2: 77-PR bughunt fold + crash-fix follow-ups

---

## Also in this window

- **Join-ACK gate clock fix**: the joiner hold now measures time on the mission clock like
  the invulnerability watchdog it must outrun - closes a confirmed race that could leave a
  joining player killable in the deadspawn holding area under cold-start load.
- Deploy pipeline hardening after two self-inflicted incidents: a prose-after-statement scan
  (a malformed comment nil'd every constant after it - the "Root_any.sqf" error) and
  launcher-collision kills in every cutover (a stale launcher once swallowed a restart).
- Empty-server auto-cutover watcher: builds deploy themselves when the box is human-empty -
  no more kicking players for a build.
